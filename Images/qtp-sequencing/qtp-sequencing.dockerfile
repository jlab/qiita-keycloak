# VERSION: 2026.02.08

# variables, specifically for this plugin
# qiita plugin name
ARG PLUGIN=qtp-sequencing

# variables, identical for whole qiita setup
ARG QIITA_PLUGINS_DIR=/unshared_plugins
ARG QIITA_CERT_DIR=/qiita_server_certificates

# for clear dockerfile
ARG CONDA_DIR=/opt/conda

# ==========================
# Stage 1: Build wheels (~5.8 GB)
# ==========================
FROM ubuntu:24.04 AS builder
ARG PLUGIN
ARG QIITA_PLUGINS_DIR
ARG QIITA_CERT_DIR
ARG CONDA_DIR

ARG MINIFORGE_VERSION=24.1.2-0
ENV PATH=${CONDA_DIR}/bin:${PATH}

RUN apt-get -y update && \
	apt-get -y --fix-missing install \
		git \
		wget \
		libpq-dev \
		python3-dev \
		gcc \
		build-essential \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*

# install miniforge3 for "conda"
# see https://github.com/conda-forge/miniforge-images/blob/master/ubuntu/Dockerfile
RUN wget --no-verbose https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/Miniforge3-${MINIFORGE_VERSION}-Linux-x86_64.sh -O /tmp/miniforge3.sh && \
	/bin/bash /tmp/miniforge3.sh -b -p ${CONDA_DIR} && \
	echo ". ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate base" >> /etc/skel/.bashrc && \
	echo ". ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate base" >> ~/.bashrc && \
	conda init && \
	rm -f /tmp/miniforge3.sh

# Create conda env
RUN conda create --name ${PLUGIN} -y -c conda-forge -c bioconda pip pigz quast fqtools python=3.9
# Make RUN commands use the new environment:
# append --format docker to the build command, see https://github.com/containers/podman/issues/8477
SHELL ["conda", "run", "-p", "${CONDA_DIR}/envs/${PLUGIN}", "/bin/bash", "-c"]

# Install qiita_client
# RUN pip install https://github.com/qiita-spots/qiita_client/archive/master.zip
# RUN git clone -b master https://github.com/qiita-spots/qiita_client.git
RUN pip install -U pip && \
	git clone -b refactor_exposeBaseDataDir https://github.com/jlab/qiita_client.git && \
	cd qiita_client && \
	pip install --no-cache-dir .

# Install qiita-files
# RUN pip install https://github.com/qiita-spots/qiita-files/archive/master.zip
RUN git clone -b master https://github.com/qiita-spots/qiita-files.git && \
	cd /qiita-files && \
	pip install -e . -v

# Install qiita plugin
#RUN git clone https://github.com/qiita-spots/qtp-sequencing.git
RUN git clone -b uncouple_clientpush  https://github.com/jlab/${PLUGIN}.git /${PLUGIN}
WORKDIR /${PLUGIN}
RUN sed -i "s|'qiita-files @ https://github.com/'||" setup.py && \
	sed -i "s|'qiita-spots/qiita-files/archive/master.zip',||" setup.py && \
	sed -i "s|'qiita_client @ https://github.com/'||" setup.py && \
	sed -i "s|'qiita-spots/qiita_client/archive/master.zip'||" setup.py && \
	pip install -e . && \
	pip install --upgrade certifi && \
	pip install pip-system-certs

COPY requirements.txt ./requirements.txt
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt


# ==========================
# Stage 2: Runtime
# ==========================
FROM python:3.9-slim
ARG PLUGIN
ARG QIITA_PLUGINS_DIR
ARG QIITA_CERT_DIR
ARG CONDA_DIR

# let the container know it's plugin name
ENV PLUGIN=${PLUGIN}

# python package compile in build stage
COPY --from=builder /wheels /wheels

RUN pip install --no-cache-dir /wheels/* \
	&& rm -rf rm -rf `find /usr/local/lib/python3.9/site-packages -type d -name "tests" | grep -v numpy`

# "install" https://github.com/alastair-droop/fqtools
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/bin/fqtools /usr/local/bin/fqtools
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libhts.so.1.22.1 /lib/x86_64-linux-gnu/libhts.so.3
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libdeflate.so.0 /lib/x86_64-linux-gnu/

# "install" pigz
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/bin/pigz /usr/local/bin/

# link to quast program
RUN ln -s /usr/local/bin/quast.py /usr/local/bin/quast

# Handling of certificates, such that plugin can verify qiita main
RUN mkdir -p ${QIITA_CERT_DIR}/
COPY qiita_server_certificates/tinqiita_server* ${QIITA_CERT_DIR}/
ENV REQUESTS_CA_BUNDLE=${QIITA_CERT_DIR}/tinqiita_server_certificates.pem
ENV SSL_CERT_FILE=${QIITA_CERT_DIR}/tinqiita_server_certificates.pem

# setup qiita plugin
ENV QIITA_PLUGINS_DIR=${QIITA_PLUGINS_DIR}
RUN mkdir -p ${QIITA_PLUGINS_DIR}/ && \
	ln -s /usr/local/bin/configure_qtp_sequencing /usr/local/bin/configure_${PLUGIN} && \
    ln -s /usr/local/bin/start_qtp_sequencing /usr/local/bin/start_${PLUGIN} && \
	configure_${PLUGIN} --env-script "true" --ca-cert `find ${QIITA_CERT_DIR}/ -name "*_server.crt" -type f` https
RUN sed -i -E "s/^START_SCRIPT = .+/START_SCRIPT = python \/start_plugin.py ${PLUGIN}/" ${QIITA_PLUGINS_DIR}/*.conf

# for docker compose health check
RUN mkdir -p /usr/share/man/man1 && \
    echo "deb [trusted=yes] http://archive.debian.org/debian buster main" > /etc/apt/sources.list && \
    echo "deb [trusted=yes] http://archive.debian.org/debian-security buster/updates main" >> /etc/apt/sources.list && \
    echo "deb [trusted=yes] http://archive.debian.org/debian buster-updates main" >> /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends wget && \
    rm -rf /var/lib/apt/lists/*

# copy http listener
COPY trigger.py /trigger.py

# for job execution
COPY start_plugin.sh .

# for testing
COPY test_plugin.sh /test_plugin.sh

# for reference, if user wants to inspect image
COPY *.dockerfile /

CMD ["./start_plugin.sh"]