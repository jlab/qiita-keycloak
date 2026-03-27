# VERSION: 2026.02.17

# variables, specifically for this plugin
# qiita plugin name
ARG PLUGIN=qp-target-gene

# variables, identical for whole qiita setup
ARG QIITA_PLUGINS_DIR=/unshared_plugins
ARG QIITA_CERT_DIR=/qiita_server_certificates

# for clear dockerfile
ARG CONDA_DIR=/opt/conda

# ==========================
# Stage 1: Build wheels
# ==========================
FROM ubuntu:24.04 AS builder
ARG PLUGIN
ARG QIITA_PLUGINS_DIR
ARG QIITA_CERT_DIR
ARG CONDA_DIR

ARG MINIFORGE_VERSION=24.1.2-0
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
RUN wget --no-verbose https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/Miniforge3-${MINIFORGE_VERSION}-Linux-x86_64.sh -O /tmp/miniforge3.sh && \
	/bin/bash /tmp/miniforge3.sh -b -p ${CONDA_DIR} && \
	echo ". ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate base" >> /etc/skel/.bashrc && \
	echo ". ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate base" >> ~/.bashrc && \
	conda init && \
	rm -f /tmp/miniforge3.sh

# install tornado based trigger layer in base environment
RUN pip install -U pip

# Create conda env
RUN conda create --name ${PLUGIN} -y -c conda-forge -c bioconda -c biocore python=2.7 SortMeRNA==2.0 numpy==1.13.1 pigz biom-format
# Make RUN commands use the new environment:
# append --format docker to the build command, see https://github.com/containers/podman/issues/8477
SHELL ["conda", "run", "-p", "${CONDA_DIR}/envs/${PLUGIN}", "/bin/bash", "-c"]

# see https://stackoverflow.com/questions/49940813/pip-no-module-named-internal
RUN wget https://bootstrap.pypa.io/pip/2.7/get-pip.py -O /get-pip2.7.py && \
	wget https://bootstrap.pypa.io/pip/3.7/get-pip.py -O /get-pip3.7.py	&& \
	python2.7 get-pip2.7.py --force-reinstall

RUN pip install -U pip

# Install qiita_client
#RUN pip install https://github.com/qiita-spots/qiita_client/archive/master.zip
#RUN git clone -b master https://github.com/qiita-spots/qiita_client.git
RUN git clone -b refactor_chunked_filepush_v2 https://github.com/jlab/qiita_client.git && \
	cd qiita_client && \
	pip install --no-cache-dir .

# Install qiita-files
RUN pip install https://github.com/qiita-spots/qiita-files/archive/master.zip

# Install qiita plugin
RUN git clone -b uncouple_clientpush  https://github.com/jlab/${PLUGIN}.git /${PLUGIN}
WORKDIR /${PLUGIN}
RUN pip install biom-format && \
	pip install -e . && \
	pip install --upgrade certifi && \
	pip install pip-system-certs

WORKDIR /

# qiime 1.9.1 comes with https://pypi.org/project/qiime-default-reference/ as dependency, which is ~184MB
# we "hide" it here, as necessary files will be downloaded from ftp.microbio.me/greengenes_release while setting up qiita anyway
RUN pip download --dest /qiime_default_reference qiime_default_reference \
    && cd /qiime_default_reference \
	&& tar xzvf *.tar.gz \
	&& cd qiime-default-reference-0.1.3 \
	&& for fzip in `find . -type f -name "97*"`; do fplain=`echo $fzip | sed "s|.gz$||g"`; echo "content erased to generate small wheel file, as reference shall be mounted to target container later on." > $fplain; gzip -f $fplain; done

COPY requirements.txt ./requirements.txt
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt

# download sortmerna / index_db sources for version 2.0 and re-compile statically as different glibc and libstdc++ couse issues
RUN wget https://github.com/sortmerna/sortmerna/archive/refs/tags/2.0.tar.gz && tar xzvf 2.0.tar.gz && cd /sortmerna-2.0 && ./configure LDFLAGS=" -static " && make -j

# ==========================
# Stage 2: Runtime
# ==========================
# I am testing ubuntu as base image, since python:xxx-slim was too hard/large to install python2 and python3 side by side
FROM ubuntu:22.04
ARG PLUGIN
ARG QIITA_PLUGINS_DIR
ARG QIITA_CERT_DIR
ARG CONDA_DIR

# let the container know it's plugin name
ENV PLUGIN=${PLUGIN}

# py2 and py3
RUN mkdir -p /usr/share/man/man1 && \
    apt-get update && \
    apt-get install -y --no-install-recommends python2 python3 curl python-tk && \
    rm -rf /var/lib/apt/lists/*

# install pip2
COPY --from=builder /get-pip2.7.py /get-pip3.7.py /
RUN python2 get-pip2.7.py \
 	&& rm get-pip2.7.py

# install pip3
RUN python3 get-pip3.7.py \
 	&& rm get-pip3.7.py

# python package compile in build stage
COPY --from=builder /wheels /wheels
RUN pip2 install --no-cache-dir /wheels/* \
	&& rm -rf rm -rf `find /usr/local/lib/python2.7/site-packages -type d -name "tests" | grep -v numpy`
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libpython2.7.so.1.0 /usr/lib/x86_64-linux-gnu/libpython2.7.so.1.0
# copy sortmerna binaries
COPY --from=builder /sortmerna-2.0/sortmerna /usr/local/bin/sortmerna
COPY --from=builder /sortmerna-2.0/indexdb_rna /usr/local/bin/indexdb_rna

# "install" pigz
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/bin/pigz /usr/local/bin/

RUN pip3 install tornado

# Handling of certificates, such that plugin can verify qiita main
RUN mkdir -p ${QIITA_CERT_DIR}/
COPY Certificates/tinqiita/*_server* ${QIITA_CERT_DIR}/
ENV REQUESTS_CA_BUNDLE=${QIITA_CERT_DIR}/tinqiita_server_certificates.pem
ENV SSL_CERT_FILE=${QIITA_CERT_DIR}/tinqiita_server_certificates.pem

# setup qiita plugin
ENV QIITA_PLUGINS_DIR=${QIITA_PLUGINS_DIR}
RUN mkdir -p ${QIITA_PLUGINS_DIR}/ && \
	sed -i "s|^#\!.*|#\!/usr/bin/python2|" /usr/local/bin/configure_target_gene && \
	sed -i "s|^#\!.*|#\!/usr/bin/python2|" /usr/local/bin/start_target_gene && \
	ln -s /usr/local/bin/configure_target_gene /usr/local/bin/configure_${PLUGIN} && \
	ln -s /usr/local/bin/start_target_gene /usr/local/bin/start_${PLUGIN} && \
	configure_${PLUGIN} --env-script "true" --server-cert `find ${QIITA_CERT_DIR}/ -name "*_server.crt" -type f` https && \
	sed -i -E "s/^START_SCRIPT = .+/START_SCRIPT = python \/start_plugin.py ${PLUGIN}/" ${QIITA_PLUGINS_DIR}/*.conf

# copy http listener
COPY trigger.py /trigger.py

# for job execution
COPY start_plugin.sh .

# for testing
COPY test_plugin.sh /test_plugin.sh

# for reference, if user wants to inspect image
COPY *.dockerfile /

CMD ["./start_plugin.sh"]
