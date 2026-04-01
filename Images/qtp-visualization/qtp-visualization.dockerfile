# VERSION: 2026.04.01

# variables, specifically for this plugin
# qiita plugin name
ARG PLUGIN=qtp-visualization

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
ARG QIIME2RELEASE=2023.5

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

# Download qiime2 yaml (make sure to use a qiime2 version that is able to visualize qiime artifacts of the correct version)
RUN wget --quiet https://data.qiime2.org/distro/core/qiime2-${QIIME2RELEASE}-py38-linux-conda.yml

RUN sed -n '/channels/,/dependencies/p' qiime2-${QIIME2RELEASE}-py38-linux-conda.yml > tinyq2.yml && \
	echo "  - q2-metadata=${QIIME2RELEASE}" >> tinyq2.yml && \
	echo "  - q2-mystery-stew=${QIIME2RELEASE}" >> tinyq2.yml && \
	echo "  - q2-types=${QIIME2RELEASE}" >> tinyq2.yml && \
	echo "  - q2cli=${QIIME2RELEASE}" >> tinyq2.yml && \
	echo "  - q2templates=${QIIME2RELEASE}" >> tinyq2.yml && \
	echo "  - typeguard=2.13.3" >> tinyq2.yml && \
	echo "  - qiime2" >> tinyq2.yml

# Create conda env
RUN conda config --set channel_priority strict && \
	conda env create --name ${PLUGIN} -y --file tinyq2.yml
# Make RUN commands use the new environment:
# append --format docker to the build command, see https://github.com/containers/podman/issues/8477
SHELL ["conda", "run", "-p", "${CONDA_DIR}/envs/${PLUGIN}", "/bin/bash", "-c"]

ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

# Install qiita_client
# RUN pip install https://github.com/qiita-spots/qiita_client/archive/master.zip
# RUN git clone -b master https://github.com/qiita-spots/qiita_client.git
RUN pip install -U pip && \
	git clone -b master https://github.com/qiita-spots/qiita_client.git && \
	cd qiita_client && \
	pip install --no-cache-dir .

# Install qiita-files
# RUN pip install https://github.com/qiita-spots/qiita-files/archive/master.zip
RUN git clone -b master https://github.com/qiita-spots/qiita-files.git && \
	cd /qiita-files && \
	pip install -e . -v

# Install qiita plugin
RUN git clone -b uncouple_clientpush  https://github.com/jlab/${PLUGIN}.git /${PLUGIN}
WORKDIR /${PLUGIN}
RUN sed -i "s|'qiita_client', 'click >= 3.3', 'qiime2'|'click >= 3.3'|" setup.py && \
	pip install -e . && \
	pip install --upgrade certifi && \
	pip install pip-system-certs

WORKDIR /

RUN repo=q2-metadata; mkdir -p /$repo && wget -O- https://github.com/qiime2/$repo/archive/refs/tags/${QIIME2RELEASE}.0.tar.gz | tar -xz --strip-components=1 -C /$repo && \
	repo=q2-mystery-stew; mkdir -p /$repo && wget -O- https://github.com/qiime2/$repo/archive/refs/tags/${QIIME2RELEASE}.0.tar.gz | tar -xz --strip-components=1 -C /$repo && \
	repo=q2-types; mkdir -p /$repo && wget -O- https://github.com/qiime2/$repo/archive/refs/tags/${QIIME2RELEASE}.0.tar.gz | tar -xz --strip-components=1 -C /$repo && \
	repo=q2cli; mkdir -p /$repo && wget -O- https://github.com/qiime2/$repo/archive/refs/tags/${QIIME2RELEASE}.1.tar.gz | tar -xz --strip-components=1 -C /$repo && \
	repo=q2templates; mkdir -p /$repo && wget -O- https://github.com/qiime2/$repo/archive/refs/tags/${QIIME2RELEASE}.0.tar.gz | tar -xz --strip-components=1 -C /$repo && \
	repo=qiime2; mkdir -p /$repo && wget -O- https://github.com/qiime2/$repo/archive/refs/tags/${QIIME2RELEASE}.1.tar.gz | tar -xz --strip-components=1 -C /$repo

COPY requirements.txt ./requirements.txt
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt


# ==========================
# Stage 2: Runtime
# ==========================
FROM python:3.8-slim
ARG PLUGIN
ARG QIITA_PLUGINS_DIR
ARG QIITA_CERT_DIR
ARG CONDA_DIR

# let the container know it's plugin name
ENV PLUGIN=${PLUGIN}

# python package compile in build stage
COPY --from=builder /wheels /wheels

RUN pip install --no-cache-dir /wheels/* \
	&& rm -rf rm -rf `find /usr/local/lib/python3.8/site-packages -type d -name "tests" | grep -v numpy`

# Handling of certificates, such that plugin can verify qiita main
RUN mkdir -p ${QIITA_CERT_DIR}/
COPY Certificates/tinqiita/*_server* ${QIITA_CERT_DIR}/
ENV REQUESTS_CA_BUNDLE=${QIITA_CERT_DIR}/tinqiita_server_certificates.pem
ENV SSL_CERT_FILE=${QIITA_CERT_DIR}/tinqiita_server_certificates.pem

ENV QIITA_PLUGINS_DIR=${QIITA_PLUGINS_DIR}
# qiime2 expects to have a CONDA_PREFIX set, see https://github.com/qiime2/qiime2/blob/812fd09cf80b4ed76c1f39827ae2dba729448436/qiime2/sdk/parallel_config.py#L30
ENV CONDA_PREFIX=/usr/local
RUN mkdir -p ${QIITA_PLUGINS_DIR}/ && \
	chmod u+x /usr/local/bin/configure_visualization_types /usr/local/bin/start_visualization_types && \
	ln -s /usr/local/bin/configure_visualization_types /usr/local/bin/configure_${PLUGIN} && \
	ln -s /usr/local/bin/start_visualization_types /usr/local/bin/start_${PLUGIN} && \
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
