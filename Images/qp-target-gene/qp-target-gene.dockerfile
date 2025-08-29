# VERSION: 2025.08.28

# ==========================
# Stage 1: Build wheels
# ==========================
FROM ubuntu:24.04 AS builder

ARG MINIFORGE_VERSION=24.1.2-0

ENV CONDA_DIR=/opt/conda
ENV PATH=${CONDA_DIR}/bin:${PATH}

RUN apt-get -y update
RUN apt-get -y --fix-missing install \
	git \
	wget \
	libpq-dev \
	python3-dev \
	gcc \
	build-essential

# install miniforge3 for "conda"
# see https://github.com/conda-forge/miniforge-images/blob/master/ubuntu/Dockerfile
RUN wget https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/Miniforge3-${MINIFORGE_VERSION}-Linux-x86_64.sh -O /tmp/miniforge3.sh && \
	/bin/bash /tmp/miniforge3.sh -b -p ${CONDA_DIR} && \
	echo ". ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate base" >> /etc/skel/.bashrc && \
	echo ". ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate base" >> ~/.bashrc && \
	conda init && \
	rm -f /tmp/miniforge3.sh

# install tornado based trigger layer in base environment
RUN pip install -U pip

# Create conda env
RUN conda create --name qp-target-gene -y -c conda-forge -c bioconda -c biocore python=2.7 SortMeRNA==2.0 numpy==1.13.1 pigz biom-format
# Make RUN commands use the new environment:
# append --format docker to the build command, see https://github.com/containers/podman/issues/8477
SHELL ["conda", "run", "-p", "/opt/conda/envs/qp-target-gene", "/bin/bash", "-c"]

# see https://stackoverflow.com/questions/49940813/pip-no-module-named-internal
RUN wget https://bootstrap.pypa.io/pip/2.7/get-pip.py -O /get-pip2.7.py
RUN wget https://bootstrap.pypa.io/pip/3.7/get-pip.py -O /get-pip3.7.py
RUN python2.7 get-pip2.7.py --force-reinstall

RUN pip install -U pip
#RUN pip install https://github.com/qiita-spots/qiita_client/archive/master.zip
RUN git clone -b uncouplePlugins https://github.com/jlab/qiita_client.git
RUN cd qiita_client && pip install --no-cache-dir .

RUN pip install https://github.com/qiita-spots/qiita-files/archive/master.zip
RUN git clone https://github.com/qiita-spots/qp-target-gene.git
WORKDIR /qp-target-gene
RUN pip install biom-format
RUN pip install -e .
RUN pip install --upgrade certifi
RUN pip install pip-system-certs

WORKDIR /

COPY requirements.txt ./requirements.txt
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt


# ==========================
# Stage 2: Runtime
# ==========================
# I am testing ubuntu as base image, since python:xxx-slim was too hard/large to install python2 and python3 side by side
FROM ubuntu:22.04

# py2 and py3
RUN mkdir -p /usr/share/man/man1 && \
    apt-get update && \
    apt-get install -y --no-install-recommends python2 python3 curl python-tk && \
    rm -rf /var/lib/apt/lists/*

# # RUN apk add --no-cache python2 python3  curl

# pip2 installieren
COPY --from=builder /get-pip2.7.py /get-pip3.7.py /
RUN python2 get-pip2.7.py \
 	&& rm get-pip2.7.py

# pip3 installieren
RUN python3 get-pip3.7.py \
 	&& rm get-pip3.7.py

# python package compile in build stage
COPY --from=builder /wheels /wheels

# dependent binaries + necessary libraries: sortmerna
COPY --from=builder /opt/conda/envs/qp-target-gene/bin/indexdb_rna /opt/conda/envs/qp-target-gene/bin/sortmerna /usr/local/bin/

RUN pip2 install --no-cache-dir /wheels/* \
	&& rm -rf rm -rf `find /usr/local/lib/python2.7/site-packages -type d -name "tests" | grep -v numpy`
COPY --from=builder /opt/conda/envs/qp-target-gene/lib/libpython2.7.so.1.0 /usr/lib/x86_64-linux-gnu/libpython2.7.so.1.0

# "install" pigz
COPY --from=builder /opt/conda/envs/qp-target-gene/bin/pigz /usr/local/bin/

COPY start_qp-target-gene.sh .
RUN chmod 755 start_qp-target-gene.sh

RUN mkdir -p /unshared_plugins
ENV QIITA_PLUGINS_DIR=/unshared_plugins/

RUN pip3 install tornado
COPY trigger_noconda.py /trigger.py

##  Export cert and config filepaths
COPY qiita_server_certificates/qiita_server_certificates.pem /qiita_server_certificates/qiita_server_certificates.pem
ENV REQUESTS_CA_BUNDLE=/qiita_server_certificates/qiita_server_certificates.pem
ENV SSL_CERT_FILE=/qiita_server_certificates/qiita_server_certificates.pem

RUN export QIITA_ROOTCA_CERT=/unshared_certificates/ci_rootca.crt
COPY qiita_server_certificates/*_server.* /qiita_server_certificates/
RUN sed -i "s|^#\!.*|#\!/usr/bin/python2|" /usr/local/bin/configure_target_gene
RUN sed -i "s|^#\!.*|#\!/usr/bin/python2|" /usr/local/bin/start_target_gene
RUN configure_target_gene --env-script "true" --server-cert `find /qiita_server_certificates/ -name "*_server.crt" -type f`
RUN sed -i -E "s/^START_SCRIPT = .+/START_SCRIPT = python \/start_plugin.py qp-target-gene/" /unshared_plugins/*.conf

CMD ["./start_qp-target-gene.sh"]
