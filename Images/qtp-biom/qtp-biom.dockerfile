# VERSION: 2026.02.08

# variables, specifically for this plugin
# qiita plugin name
ARG PLUGIN=qtp-biom

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
ARG QIIME2RELEASE=2022.8

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

# biom artifact validation throws an error since provenance tracking of Qiime2 cannot get proper time zone information, if not configured here
# https://stackoverflow.com/questions/21717411/timezone-information-missing-in-pytz
RUN dpkg-reconfigure -f noninteractive tzdata

# install miniforge3 for "conda"
# see https://github.com/conda-forge/miniforge-images/blob/master/ubuntu/Dockerfile
RUN wget --no-verbose https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/Miniforge3-${MINIFORGE_VERSION}-Linux-x86_64.sh -O /tmp/miniforge3.sh && \
	/bin/bash /tmp/miniforge3.sh -b -p ${CONDA_DIR} && \
	echo ". ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate base" >> /etc/skel/.bashrc && \
	echo ". ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate base" >> ~/.bashrc && \
	conda init && \
	rm -f /tmp/miniforge3.sh

# Download qtp-biom yaml
# RUN wget https://raw.githubusercontent.com/qiime2/distributions/refs/heads/dev/${QIIME2RELEASE}/tiny/released/qiime2-tiny-ubuntu-latest-conda.yml
RUN wget https://data.qiime2.org/distro/core/qiime2-${QIIME2RELEASE}-py38-linux-conda.yml

RUN sed -n '/channels/,/dependencies/p' qiime2-${QIIME2RELEASE}-py38-linux-conda.yml > tinyq2.yml && \
	echo "  - q2-metadata=${QIIME2RELEASE}" >> tinyq2.yml && \
	echo "  - q2-mystery-stew=${QIIME2RELEASE}" >> tinyq2.yml && \
	echo "  - q2-types=${QIIME2RELEASE}" >> tinyq2.yml && \
	echo "  - q2cli=${QIIME2RELEASE}" >> tinyq2.yml && \
	echo "  - q2templates=${QIIME2RELEASE}" >> tinyq2.yml && \
	echo "  - qiime2=${QIIME2RELEASE}" >> tinyq2.yml && \
	echo "  - q2-feature-table=${QIIME2RELEASE}" >> tinyq2.yml

# Create conda env
RUN conda config --set channel_priority strict && \
	conda env create --quiet -n ${PLUGIN} --file tinyq2.yml
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
RUN git clone -b uncouple_clientpush  https://github.com/jlab/${PLUGIN}.git /${PLUGIN}
WORKDIR /${PLUGIN}
RUN sed -i "s|'qiita-files @ https://github.com/qiita-spots/'||" setup.py && \
	sed -i "s|'qiita-files/archive/master.zip',||" setup.py && \
	sed -i "s|'qiita_client @ https://github.com/qiita-spots/'||" setup.py && \
	sed -i "s|'qiita_client/archive/master.zip'||" setup.py && \
	pip install -e . && \
	pip install --upgrade certifi && \
	pip install pip-system-certs

# TODO: should the plugin get the server configuration?!
RUN export QIITA_CONFIG_FP=/qiita/config_qiita_oidc.cfg

WORKDIR /

# prepare for runtime stage
RUN pip uninstall pip-system-certs -y && \
	repo=q2-feature-table; mkdir -p /$repo && wget -O- https://github.com/qiime2/$repo/archive/refs/tags/${QIIME2RELEASE}.1.tar.gz | tar -xz --strip-components=1 -C /$repo && \
	repo=q2-metadata; mkdir -p /$repo && wget -O- https://github.com/qiime2/$repo/archive/refs/tags/${QIIME2RELEASE}.0.tar.gz | tar -xz --strip-components=1 -C /$repo && \
	repo=q2-mystery-stew; mkdir -p /$repo && wget -O- https://github.com/qiime2/$repo/archive/refs/tags/${QIIME2RELEASE}.0.tar.gz | tar -xz --strip-components=1 -C /$repo && \
	repo=q2-types; mkdir -p /$repo && wget -O- https://github.com/qiime2/$repo/archive/refs/tags/${QIIME2RELEASE}.0.tar.gz | tar -xz --strip-components=1 -C /$repo && \
	repo=q2cli; mkdir -p /$repo && wget -O- https://github.com/qiime2/$repo/archive/refs/tags/${QIIME2RELEASE}.0.tar.gz | tar -xz --strip-components=1 -C /$repo && \
	repo=q2templates; mkdir -p /$repo && wget -O- https://github.com/qiime2/$repo/archive/refs/tags/${QIIME2RELEASE}.0.tar.gz | tar -xz --strip-components=1 -C /$repo && \
	repo=qiime2; mkdir -p /$repo && wget -O- https://github.com/qiime2/$repo/archive/refs/tags/${QIIME2RELEASE}.3.tar.gz | tar -xz --strip-components=1 -C /$repo

COPY requirements.txt ./requirements.txt
RUN conda install cython && \
	pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt && \
	pip install iow


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

COPY --from=builder ${CONDA_DIR}/envs/qtp-biom/lib/python3.8/site-packages/bp /usr/local/lib/python3.8/site-packages/bp
RUN ln -s /usr/local/lib/python3.8/site-packages/scikit_learn.libs/libgomp-a34b3233.so.1.0.0 /lib/x86_64-linux-gnu/libgomp.so.1

WORKDIR /

# Handling of certificates, such that plugin can verify qiita main
RUN mkdir -p ${QIITA_CERT_DIR}/
COPY qiita_server_certificates/*_server* ${QIITA_CERT_DIR}/
ENV REQUESTS_CA_BUNDLE=${QIITA_CERT_DIR}/qiita_server_certificates.pem
ENV SSL_CERT_FILE=${QIITA_CERT_DIR}/qiita_server_certificates.pem

# setup qiita plugin
ENV QIITA_PLUGINS_DIR=${QIITA_PLUGINS_DIR}
RUN mkdir -p ${QIITA_PLUGINS_DIR}/ && \
	ln -s /usr/local/bin/configure_biom /usr/local/bin/configure_${PLUGIN} && \
    ln -s /usr/local/bin/start_biom /usr/local/bin/start_${PLUGIN} && \
	configure_${PLUGIN} --env-script "true" --server-cert `find ${QIITA_CERT_DIR}/ -name "*_server.crt" -type f` https && \
	sed -i -E "s/^START_SCRIPT = .+/START_SCRIPT = python \/start_plugin.py ${PLUGIN}/" ${QIITA_PLUGINS_DIR}/*.conf

# fix an pandas deprecation issue, i.e. patch q2templates code
RUN sed -i "s/'display.max_colwidth', -1/'display.max_colwidth', None/" /usr/local/lib/python3.8/site-packages/q2templates/util.py

# copy http listener
COPY trigger.py /trigger.py

# for job execution
COPY start_plugin.sh .

# for testing
COPY test_plugin.sh /test_plugin.sh

# for reference, if user wants to inspect image
COPY *.dockerfile /

CMD ["./start_plugin.sh"]
