# VERSION: 2026.05.08

# variables, specifically for this plugin
# qiita plugin name
ARG PLUGIN=qtp-genome
ARG GIT_PLUGIN_BRANCH=main
ARG GIT_PLUGIN_FORK=jlab
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

# Create conda env
RUN conda config --set channel_priority strict && \
	conda create --quiet -n ${PLUGIN} -c conda-forge -c bioconda python=3.11 seqkit genometools-genometools gffread
# Make RUN commands use the new environment:
# append --format docker to the build command, see https://github.com/containers/podman/issues/8477
SHELL ["conda", "run", "-p", "${CONDA_DIR}/envs/${PLUGIN}", "/bin/bash", "-c"]

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
RUN git clone -b ${GIT_PLUGIN_BRANCH} https://github.com/${GIT_PLUGIN_FORK}/${PLUGIN}.git /${PLUGIN} && \
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


# ==========================
# Stage 2: Runtime
# ==========================
FROM python:3.11-slim
ARG PLUGIN
ARG QIITA_PLUGINS_DIR
ARG QIITA_CERT_DIR
ARG CONDA_DIR

# let the container know it's plugin name
ENV PLUGIN=${PLUGIN}

RUN --mount=type=bind,from=builder,source=/wheels,target=/wheels \
	pip install --no-cache-dir /wheels/* tornado pip-system-certs \
	&& rm -rf rm -rf `find /usr/local/lib/python3.11/site-packages -type d -name "tests" | grep -v numpy` \
	# for smaller docker container: strip *.so libraries
	&& apt-get update && apt-get install binutils -y --no-install-recommends \
	&& find /usr/local/lib/python3.11/site-packages -name "*.so" -exec strip --strip-unneeded {} + || true \
	&& apt-get purge -y binutils && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/bin/seqkit ${CONDA_DIR}/envs/${PLUGIN}/bin/gt ${CONDA_DIR}/envs/${PLUGIN}/bin/gffread /usr/local/bin/
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/share/genometools/gtdata   /usr/local/share/genometools/gtdata
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libpango-1.0.so.0      /lib/x86_64-linux-gnu/libpango-1.0.so.0
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libgobject-2.0.so.0    /lib/x86_64-linux-gnu/libgobject-2.0.so.0
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libcairo.so.2          /lib/x86_64-linux-gnu/libcairo.so.2
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libpangocairo-1.0.so.0 /lib/x86_64-linux-gnu/libpangocairo-1.0.so.0
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libglib-2.0.so.0       /lib/x86_64-linux-gnu/libglib-2.0.so.0
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libgio-2.0.so.0        /lib/x86_64-linux-gnu/libgio-2.0.so.0
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libfribidi.so.0        /lib/x86_64-linux-gnu/libfribidi.so.0
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libharfbuzz.so.0       /lib/x86_64-linux-gnu/libharfbuzz.so.0
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libpng16.so.16         /lib/x86_64-linux-gnu/libpng16.so.16
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libfontconfig.so.1     /lib/x86_64-linux-gnu/libfontconfig.so.1
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libfreetype.so.6       /lib/x86_64-linux-gnu/libfreetype.so.6
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libX11.so.6            /lib/x86_64-linux-gnu/libX11.so.6
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libxcb.so.1            /lib/x86_64-linux-gnu/libxcb.so.1
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libxcb-render.so.0     /lib/x86_64-linux-gnu/libxcb-render.so.0
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libxcb-shm.so.0        /lib/x86_64-linux-gnu/libxcb-shm.so.0
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libpixman-1.so.0       /lib/x86_64-linux-gnu/libpixman-1.so.0
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libpangoft2-1.0.so.0   /lib/x86_64-linux-gnu/libpangoft2-1.0.so.0
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libiconv.so.2          /lib/x86_64-linux-gnu/libiconv.so.2
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libX11-xcb.so.1        /lib/x86_64-linux-gnu/libX11-xcb.so.1
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libgmodule-2.0.so.0    /lib/x86_64-linux-gnu/libgmodule-2.0.so.0
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libgraphite2.so.3      /lib/x86_64-linux-gnu/libgraphite2.so.3
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libexpat.so.1          /lib/x86_64-linux-gnu/libexpat.so.1
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libXau.so.6            /lib/x86_64-linux-gnu/libXau.so.6
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libXdmcp.so.6          /lib/x86_64-linux-gnu/libXdmcp.so.6
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libpcre2-8.so.0        /lib/x86_64-linux-gnu/libpcre2-8.so.0

WORKDIR /

# Handling of certificates, such that plugin can verify qiita main
RUN mkdir -p ${QIITA_CERT_DIR}/
COPY Certificates/tinqiita/*_server* ${QIITA_CERT_DIR}/
ENV REQUESTS_CA_BUNDLE=${QIITA_CERT_DIR}/tinqiita_server_certificates.pem
ENV SSL_CERT_FILE=${QIITA_CERT_DIR}/tinqiita_server_certificates.pem

# setup qiita plugin
ENV QIITA_PLUGINS_DIR=${QIITA_PLUGINS_DIR}
RUN mkdir -p ${QIITA_PLUGINS_DIR}/ && \
	ln -s /usr/local/bin/configure_genome /usr/local/bin/configure_${PLUGIN} && \
    ln -s /usr/local/bin/start_genome /usr/local/bin/start_${PLUGIN} && \
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
