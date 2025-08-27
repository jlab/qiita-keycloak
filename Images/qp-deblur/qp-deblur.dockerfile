# VERSION: 2025.08.22

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

# Create conda env
RUN conda create --quiet -n deblur python=3.5 pip libgfortran=3
# Make RUN commands use the new environment:
# append --format docker to the build command, see https://github.com/containers/podman/issues/8477
SHELL ["conda", "run", "-p", "/opt/conda/envs/deblur", "/bin/bash", "-c"]

ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

RUN git clone -b uncouplePlugins https://github.com/jlab/qiita_client.git
RUN sed -i "s/f'Entered BaseQiitaPlugin._register_command({command.name})'/'Entered BaseQiitaPlugin._register_command(%s)' % command.name/"  qiita_client/qiita_client/plugin.py
RUN cd qiita_client && pip install --no-cache-dir .

RUN conda install --quiet --yes -c bioconda -c biocore "VSEARCH=2.7.0" MAFFT=7.310 SortMeRNA=2.0 fragment-insertion gcc
RUN pip install -U pip
RUN pip install numpy cython pandas
RUN pip install scikit-bio==0.5.5

RUN pip install -U pip pip-system-certs

RUN git clone -b uncouplePlugins https://github.com/jlab/qp-deblur.git
RUN cd qp-deblur && pip install .

RUN echo "scikit-bio==0.5.5" > req.txt && \
    echo "-e /qp-deblur" >> req.txt
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r req.txt


# ==========================
# Stage 2: Runtime
# ==========================
FROM python:3.5-slim
# ^^ 110 MB

# deblur dependent binaries + necessary libraries: mafft, vsearch, sortmerna
COPY --from=builder /opt/conda/envs/deblur/bin/mafft /opt/conda/envs/deblur/bin/vsearch /opt/conda/envs/deblur/bin/indexdb_rna /opt/conda/envs/deblur/bin/sortmerna /usr/local/bin/
# ^^ 113 MB
COPY --from=builder /opt/conda/envs/deblur/libexec/mafft /opt/conda/envs/deblur/libexec/mafft/
# ^^ 122 MB
COPY --from=builder /opt/conda/envs/deblur/lib/libgomp.so.1.0.0 /lib/x86_64-linux-gnu/libgomp.so.1
# ^^ 123 MB

# python package compile in build stage
COPY --from=builder /wheels /wheels
# ^^ 235 MB
RUN pip install --no-cache-dir /wheels/* \
	&& rm -rf /usr/local/lib/python3.5/site-packages/biom/tests
# ^^ 612 MB

COPY --from=builder /opt/conda/envs/deblur/bin/run-sepp.sh /opt/conda/envs/deblur/bin/seppJsonMerger.jar /opt/conda/envs/deblur/bin/hmm* /opt/conda/envs/deblur/bin/pplacer /opt/conda/envs/deblur/bin/guppy /usr/local/bin/
# ^^ 633 MB

# minimal Java Runtime Environment for SEPP's seppJsonMerger.jar
RUN mkdir -p /usr/share/man/man1 && \
    echo "deb [trusted=yes] http://archive.debian.org/debian buster main" > /etc/apt/sources.list && \
    echo "deb [trusted=yes] http://archive.debian.org/debian-security buster/updates main" >> /etc/apt/sources.list && \
    echo "deb [trusted=yes] http://archive.debian.org/debian buster-updates main" >> /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends openjdk-11-jre-headless && \
    rm -rf /var/lib/apt/lists/*
# ^^ 841 MB

# copy SEPP
COPY --from=builder /opt/conda/envs/deblur/share/fragment-insertion/sepp/run_sepp.py /opt/conda/envs/deblur/share/fragment-insertion/sepp/run_sepp.py
COPY --from=builder /opt/conda/envs/deblur/share/fragment-insertion/sepp/sepp        /opt/conda/envs/deblur/share/fragment-insertion/sepp/sepp
COPY --from=builder /opt/conda/envs/deblur/share/fragment-insertion/sepp/dendropy    /opt/conda/envs/deblur/share/fragment-insertion/sepp/dendropy
COPY --from=builder /opt/conda/envs/deblur/share/fragment-insertion/sepp/home.path   /opt/conda/envs/deblur/share/fragment-insertion/sepp/home.path
COPY --from=builder /opt/conda/envs/deblur/share/fragment-insertion/sepp/.sepp/main.config /opt/conda/envs/deblur/share/fragment-insertion/sepp/.sepp/main.config
RUN sed -i "s|/opt/conda/envs/deblur/share/fragment-insertion/sepp/.sepp/bundled-v4.3.5/|/usr/local/bin/|g" /opt/conda/envs/deblur/share/fragment-insertion/sepp/.sepp/main.config
# ^^ 845 MB
# following step increases image size from by 1.3 GB!! Better mount as volume and "make" these files during Makefile execution
# COPY --from=builder /opt/conda/envs/deblur/share/fragment-insertion/ref/ /opt/conda/envs/deblur/share/fragment-insertion/ref/

# install tornado based trigger layer in base environment
RUN pip install -U --no-cache-dir tornado pip-system-certs
COPY trigger_noconda.py /trigger.py
# ^^ 848 MB

WORKDIR /

COPY start_qp-deblur.sh .
RUN chmod 755 start_qp-deblur.sh

RUN mkdir -p /unshared_plugins
ENV QIITA_PLUGINS_DIR=/unshared_plugins/

##  Export cert and config filepaths
COPY qiita_server_certificates/qiita_server_certificates.pem /qiita_server_certificates/qiita_server_certificates.pem
ENV REQUESTS_CA_BUNDLE=/qiita_server_certificates/qiita_server_certificates.pem
ENV SSL_CERT_FILE=/qiita_server_certificates/qiita_server_certificates.pem

RUN sed -i "s|^#\!.*|#\!/usr/local/bin/python|" /usr/local/bin/configure_deblur
RUN sed -i "s|^#\!.*|#\!/usr/local/bin/python|" /usr/local/bin/start_deblur

# use git branch instead of pypi version (stored via wheel)
COPY --from=builder /qiita_client /qiita_client
RUN cd qiita_client && pip install .

RUN mkdir -p /qiita_server_certificates/
COPY qiita_server_certificates/*_server.* /qiita_server_certificates/
RUN /usr/local/bin/configure_deblur --env-script "true" --server-cert `find /qiita_server_certificates/ -name "*_server.crt" -type f` filesystem
RUN sed -i -E "s/^START_SCRIPT = .+/START_SCRIPT = python \/start_plugin.py qp-deblur/" /unshared_plugins/*.conf

# remove conda command from tigger.py
RUN sed -i "s|source /opt/conda/etc/profile.d/conda.sh; conda activate /opt/conda/envs/%s;||" /trigger.py && sed -i "s|conda_env_name, ||" /trigger.py

CMD ["./start_qp-deblur.sh"]
# ^^ 848 MB