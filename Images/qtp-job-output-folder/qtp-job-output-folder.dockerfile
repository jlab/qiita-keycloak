# VERSION: 2026.05.08

# variables, specifically for this plugin
# qiita plugin name
ARG PLUGIN=qtp-job-output-folder
ARG GIT_PLUGIN_BRANCH=main
ARG GIT_PLUGIN_FORK=qiita-spots
ARG GIT_QIITACLIENT_BRANCH=master
ARG GIT_QIITACLIENT_FORK=qiita-spots

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
ARG GIT_PLUGIN_BRANCH
ARG GIT_PLUGIN_FORK
ARG GIT_QIITACLIENT_BRANCH
ARG GIT_QIITACLIENT_FORK

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

# install tornado based trigger layer in base environment
RUN pip install -U pip

# Create conda env
RUN conda create --name ${PLUGIN} -y python=3.6 pip==9.0.3
# Make RUN commands use the new environment:
# append --format docker to the build command, see https://github.com/containers/podman/issues/8477
SHELL ["conda", "run", "-p", "${CONDA_DIR}/envs/${PLUGIN}", "/bin/bash", "-c"]

RUN pip install -U pip

#RUN pip install https://github.com/qiita-spots/qiita_client/archive/master.zip
#RUN git clone -b master https://github.com/qiita-spots/qiita_client.git
ARG CACHEBURST_QIITACLIENT=1
ENV GIT_QIITACLIENT_BRANCH=${GIT_QIITACLIENT_BRANCH}
ENV GIT_QIITACLIENT_FORK=${GIT_QIITACLIENT_FORK}
RUN git clone -b ${GIT_QIITACLIENT_BRANCH} https://github.com/${GIT_QIITACLIENT_FORK}/qiita_client.git && \
	cd qiita_client && \
	pip install --no-cache-dir .

# Install qiita_client
# RUN pip install https://github.com/qiita-spots/qiita-files/archive/master.zip
RUN git clone -b master https://github.com/qiita-spots/qiita-files.git && \
	cd /qiita-files && \
	pip install -e . -v

# Install qiita plugin
ARG CACHEBURST_PLUGIN=1
ENV GIT_PLUGIN_BRANCH=${GIT_PLUGIN_BRANCH}
ENV GIT_PLUGIN_FORK=${GIT_PLUGIN_FORK}
RUN git clone -b ${GIT_PLUGIN_BRANCH} https://github.com/${GIT_PLUGIN_FORK}/${PLUGIN}.git /${PLUGIN} && \
	git -C /${PLUGIN} rev-parse HEAD
WORKDIR /qtp-job-output-folder
RUN sed -i 's|"qiita-files @ https://github.com/qiita-spots/qiita-files/archive/master.zip",||' setup.py && \
	sed -i 's|"qiita_client @ https://github.com/qiita-spots/qiita_client/archive/master.zip",||' setup.py && \
	pip install -e .

WORKDIR /
COPY requirements.txt /requirements.txt
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r /requirements.txt


# ==========================
# Stage 2: Runtime
# ==========================
FROM python:3.6-slim
ARG PLUGIN
ARG QIITA_PLUGINS_DIR
ARG QIITA_CERT_DIR
ARG CONDA_DIR

# let the container know it's plugin name
ENV PLUGIN=${PLUGIN}

RUN --mount=type=bind,from=builder,source=/wheels,target=/wheels \
	pip install --no-cache-dir /wheels/* \
	&& rm -rf rm -rf `find /usr/local/lib/python3.6/site-packages -type d -name "tests" | grep -v numpy` \
	# for smaller docker container: strip *.so libraries
	&& apt-get update && apt-get install binutils -y --no-install-recommends \
	&& find /usr/local/lib/python3.6/site-packages -name "*.so" -exec strip --strip-unneeded {} + || true \
	&& apt-get purge -y binutils && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*


# Handling of certificates, such that plugin can verify qiita main
RUN mkdir -p ${QIITA_CERT_DIR}/
COPY Certificates/tinqiita/*_server* ${QIITA_CERT_DIR}/
ENV REQUESTS_CA_BUNDLE=${QIITA_CERT_DIR}/tinqiita_server_certificates.pem
ENV SSL_CERT_FILE=${QIITA_CERT_DIR}/tinqiita_server_certificates.pem

# setup qiita plugin
ENV QIITA_PLUGINS_DIR=${QIITA_PLUGINS_DIR}
RUN mkdir -p ${QIITA_PLUGINS_DIR}/ && \
	chmod u+x /usr/local/bin/configure_qtp_job_output_folder /usr/local/bin/start_qtp_job_output_folder && \
	ln -s /usr/local/bin/configure_qtp_job_output_folder /usr/local/bin/configure_${PLUGIN} && \
    ln -s /usr/local/bin/start_qtp_job_output_folder /usr/local/bin/start_${PLUGIN} && \
	configure_${PLUGIN} --env-script "true" --ca-cert `find ${QIITA_CERT_DIR}/ -name "*_server.crt" -type f` https && \
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
