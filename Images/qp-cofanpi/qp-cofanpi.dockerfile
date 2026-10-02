# VERSION: 2026.10.02

# variables, specifically for this plugin
# qiita plugin name
ARG PLUGIN=qp-cofanpi
ARG GIT_PLUGIN_BRANCH=main
ARG GIT_PLUGIN_FORK=jlab
ARG GIT_QIITACLIENT_BRANCH=master
ARG GIT_QIITACLIENT_FORK=qiita-spots

# variables, identical for whole qiita setup
ARG QIITA_PLUGINS_DIR=/unshared_plugins
ARG QIITA_CERT_DIR=/qiita_server_certificates

# ==========================
# Stage 1: Build wheels
# ==========================
FROM harbor.computational.bio.uni-giessen.de/tinqiita/cofanpi:latest
ARG PLUGIN
ARG QIITA_PLUGINS_DIR
ARG QIITA_CERT_DIR
ARG CONDA_DIR
ARG GIT_PLUGIN_BRANCH
ARG GIT_PLUGIN_FORK
ARG GIT_QIITACLIENT_BRANCH
ARG GIT_QIITACLIENT_FORK

RUN apt-get -y update && \
	apt-get -y --fix-missing install \
		git \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*

# Make RUN commands use the new environment:
# append --format docker to the build command, see https://github.com/containers/podman/issues/8477
#SHELL ["conda", "run", "-p", "${CONDA_DIR}/envs/${PLUGIN}", "/bin/bash", "-c"]

# Install qiita_client
# RUN pip install https://github.com/qiita-spots/qiita_client/archive/master.zip
# RUN git clone -b master https://github.com/qiita-spots/qiita_client.git
ARG CACHEBURST_QIITACLIENT=1
ENV GIT_QIITACLIENT_BRANCH=${GIT_QIITACLIENT_BRANCH}
ENV GIT_QIITACLIENT_FORK=${GIT_QIITACLIENT_FORK}
RUN pip install -U pip && \
	git clone -b ${GIT_QIITACLIENT_BRANCH} https://github.com/${GIT_QIITACLIENT_FORK}/qiita_client.git && \
	cd qiita_client && \
	pip install --no-cache-dir .

# Install qiita-files
# RUN pip install https://github.com/qiita-spots/qiita-files/archive/master.zip
RUN git clone -b master https://github.com/qiita-spots/qiita-files.git && \
	cd /qiita-files && \
	pip install -e . -v

# Install qiita plugin
ARG CACHEBURST_PLUGIN=1
ENV GIT_PLUGIN_BRANCH=${GIT_PLUGIN_BRANCH}
ENV GIT_PLUGIN_FORK=${GIT_PLUGIN_FORK}
RUN git clone -b ${GIT_PLUGIN_BRANCH}            https://github.com/${GIT_PLUGIN_FORK}/${PLUGIN}.git /${PLUGIN} && \
	git -C /${PLUGIN} rev-parse HEAD
WORKDIR /${PLUGIN}
RUN sed -i 's|"qiita-client @ https://github.com/qiita-spots/qiita_client/archive/master.zip",||' pyproject.toml && \
	pip install -e . && \
	pip install --upgrade certifi && \
	pip install pip-system-certs

# TODO: should the plugin get the server configuration?!
RUN export QIITA_CONFIG_FP=/qiita/config_qiita_oidc.cfg

WORKDIR /

# prepare for runtime stage
RUN pip uninstall pip-system-certs -y

COPY requirements.txt ./requirements.txt
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt


# # ==========================
# # Stage 2: Runtime
# # ==========================
# FROM python:3.11-slim
# ARG PLUGIN
# ARG QIITA_PLUGINS_DIR
# ARG QIITA_CERT_DIR
# ARG CONDA_DIR

# let the container know it's plugin name
ENV PLUGIN=${PLUGIN}

RUN pip install --no-cache-dir /wheels/* tornado pip-system-certs \
	&& rm -rf rm -rf `find /usr/local/lib/python3.11/site-packages -type d -name "tests" | grep -v numpy` \
	# for smaller docker container: strip *.so libraries
	&& apt-get purge -y binutils && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

WORKDIR /

# Handling of certificates, such that plugin can verify qiita main
RUN mkdir -p ${QIITA_CERT_DIR}/
COPY Certificates/tinqiita/*_server* ${QIITA_CERT_DIR}/
ENV REQUESTS_CA_BUNDLE=${QIITA_CERT_DIR}/tinqiita_server_certificates.pem
ENV SSL_CERT_FILE=${QIITA_CERT_DIR}/tinqiita_server_certificates.pem

# setup qiita plugin
ENV QIITA_PLUGINS_DIR=${QIITA_PLUGINS_DIR}
RUN mkdir -p ${QIITA_PLUGINS_DIR}/ && \
	ln -s /qp-cofanpi/scripts/configure_cofanpi /usr/local/bin/configure_${PLUGIN} && \
    ln -s /qp-cofanpi/scripts/start_cofanpi /usr/local/bin/start_${PLUGIN} && \
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

# prepare for external reference database mount
ENV QP_COFANPI_DBVERSION_ANTISMASH=7.1.0
ENV QP_COFANPI_DBVERSION_CARD=unknown
ENV QP_COFANPI_DBVERSION_EGGNOG=5.0
ENV QP_COFANPI_DBVERSION_IPRSCAN=5.68-100.0
RUN rmdir /eggnog_db && \
	rmdir /iprscan/interproscan-5.68-100.0/data && \
	ln -s /databases/antismash_db/${QP_COFANPI_DBVERSION_ANTISMASH} /antismash_db && \
	ln -s /databases/card_db/${QP_COFANPI_DBVERSION_CARD} /card_db && \
	ln -s /databases/eggnog_db/${QP_COFANPI_DBVERSION_EGGNOG} /eggnog_db && \
	ln -s /databases/iprscan/${QP_COFANPI_DBVERSION_IPRSCAN}/interproscan-5.68-100.0/data /iprscan/interproscan-5.68-100.0/data

CMD ["./start_plugin.sh"]
ENTRYPOINT [ ]
