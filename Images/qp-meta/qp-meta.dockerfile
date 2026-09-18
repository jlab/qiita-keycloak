# VERSION: 2026.09.18

# variables, specifically for this plugin
# qiita plugin name
ARG PLUGIN=qp-meta
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
FROM ubuntu:26.04 AS builder
ARG PLUGIN
ARG QIITA_PLUGINS_DIR
ARG QIITA_CERT_DIR
ARG CONDA_DIR
ARG GIT_PLUGIN_BRANCH
ARG GIT_PLUGIN_FORK
ARG GIT_QIITACLIENT_BRANCH
ARG GIT_QIITACLIENT_FORK

# config for conda within plugin image
ARG MINIFORGE_VERSION=24.1.2-0
ENV PATH=${CONDA_DIR}/bin:${PATH}

ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

RUN apt-get -y update && \
	apt-get -y --fix-missing install \
		git \
		wget \
		python3-dev \
        sortmerna=4.3.7-3build1 \
#        pip \
#		build-essential \
#		parallel \
#		cmake \
#		zlib1g-dev \
#       libtbb-dev \
#		zip unzip \
#		xz-utils \
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

 #wget https://github.com/sortmerna/sortmerna/archive/refs/tags/v4.3.7-beta.1.tar.gz
 #tar xzvf v4.3.7-beta.1.tar.gz
 #cd sortmerna-4.3.7-beta.1

# Create conda env
RUN conda create --quiet -n ${PLUGIN} -c conda-forge -c bioconda python=3.9 biom-format samtools pigz
# Make RUN commands use the new environment:
# append --format docker to the build command, see https://github.com/containers/podman/issues/8477
SHELL ["conda", "run", "-p", "${CONDA_DIR}/envs/${PLUGIN}", "/bin/bash", "-c"]

# Install qiita_client
# RUN git clone -b master https://github.com/qiita-spots/qiita_client.git
ARG CACHEBURST_QIITACLIENT=1
ENV GIT_QIITACLIENT_BRANCH=${GIT_QIITACLIENT_BRANCH}
ENV GIT_QIITACLIENT_FORK=${GIT_QIITACLIENT_FORK}
RUN git clone -b ${GIT_QIITACLIENT_BRANCH} https://github.com/${GIT_QIITACLIENT_FORK}/qiita_client.git && \
	cd qiita_client && \
	pip install --no-cache-dir .

# Install qiita plugin
ARG CACHEBURST_PLUGIN=1
ENV GIT_PLUGIN_BRANCH=${GIT_PLUGIN_BRANCH}
ENV GIT_PLUGIN_FORK=${GIT_PLUGIN_FORK}
RUN git clone -b ${GIT_PLUGIN_BRANCH} https://github.com/${GIT_PLUGIN_FORK}/${PLUGIN}.git /${PLUGIN} && \
	git -C /${PLUGIN} rev-parse HEAD
WORKDIR /${PLUGIN}
RUN sed -i "s|'qiita-files @ https://github.com/'||" setup.py && \
	sed -i "s|'qiita-spots/qiita-files/archive/master.zip',||" setup.py && \
	sed -i "s|'qiita_client @ https://github.com/'||" setup.py && \
	sed -i "s|'qiita-spots/qiita_client/archive/master.zip'||" setup.py && \
	pip install .

COPY requirements.txt ./requirements.txt
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt

# test for correct version numbers
RUN sortmerna_version=`sortmerna --version | grep "SortMeRNA version"` && \
	if [[ $sortmerna_version != *"4.3.7"* ]]; then echo "wrong sortmerna version", $sortmerna_version; exit 1; fi


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
RUN --mount=type=bind,from=builder,source=/wheels,target=/wheels \
	# install python packages (this is huge)
	pip install --no-cache-dir --no-index --find-links=/wheels /wheels/*.whl \
	# clean up biom test files
	&& rm -rf /usr/local/lib/python3.9/site-packages/biom/tests \
	# strip *.so libraries
	&& apt-get update && apt-get install binutils wget -y --no-install-recommends \
	&& find /usr/local/lib/python3.9/site-packages -name "*.so" -exec strip --strip-unneeded {} + || true \
	&& apt-get purge -y binutils && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

# copy sortmerna
COPY --from=builder /usr/bin/sortmerna /usr/bin/sortmerna
COPY --from=builder /usr/lib/x86_64-linux-gnu/librocksdb.so.9.11 /usr/lib/x86_64-linux-gnu/librocksdb.so.9.11
COPY --from=builder /usr/lib/x86_64-linux-gnu/libgflags.so.2.2 /usr/lib/x86_64-linux-gnu/libgflags.so.2.2
COPY --from=builder /usr/lib/x86_64-linux-gnu/libsnappy.so.1 /usr/lib/x86_64-linux-gnu/libsnappy.so.1

# install tornado based trigger layer in base environment
RUN pip install -U --no-cache-dir tornado pip-system-certs ruamel.yaml kubernetes

# use git branch instead of pypi version (stored via wheel)
COPY --from=builder /qiita_client /qiita_client
RUN cd /qiita_client && pip install .

WORKDIR /

# Handling of certificates, such that plugin can verify qiita main
RUN mkdir -p ${QIITA_CERT_DIR}/
COPY Certificates/tinqiita/*_server* ${QIITA_CERT_DIR}/
ENV REQUESTS_CA_BUNDLE=${QIITA_CERT_DIR}/tinqiita_server_certificates.pem
ENV SSL_CERT_FILE=${QIITA_CERT_DIR}/tinqiita_server_certificates.pem

ENV QC_SORTMERNA_DB_DP=/databases/rRNA_databases/

# setup qiita plugin
ENV QIITA_PLUGINS_DIR=${QIITA_PLUGINS_DIR}
ENV ENVIRONMENT='true'
RUN mkdir -p ${QIITA_PLUGINS_DIR}/ && \
	sed -i "s|^#\!.*|#\!/usr/local/bin/python|" /usr/local/bin/configure_meta && \
 	sed -i "s|^#\!.*|#\!/usr/local/bin/python|" /usr/local/bin/start_meta && \
 	ln -s /usr/local/bin/configure_meta /usr/local/bin/configure_${PLUGIN} && \
    ln -s /usr/local/bin/start_meta /usr/local/bin/start_${PLUGIN} && \
 	configure_${PLUGIN} --env-script "true; export ENVIRONMENT=${ENVIRONMENT}" --server-cert `find ${QIITA_CERT_DIR}/ -name "*_server.crt" -type f` && \
 	sed -i -E "s/^START_SCRIPT = .+/START_SCRIPT = python \/start_plugin.py ${PLUGIN}/" ${QIITA_PLUGINS_DIR}/*.conf

# copy http listener
COPY trigger.py /trigger.py
# config manager + default values for k8s parameters
COPY k8sconfig_manager.py /k8sconfig_manager.py
COPY k8s_config.cfg /k8s_config.cfg

# for job execution
COPY start_plugin.sh .

# for testing
COPY test_plugin.sh /test_plugin.sh

# for reference, if user wants to inspect image
COPY *.dockerfile /
COPY qp-meta.make /

# add our little python script that simulates a SLURM cluster
COPY sbatch /bin/sbatch

# integrated tests for presence of binaries
# if this chain of commands fails, it is most likely that one of the binaries
# is missing in the container!
RUN sortmerna --version | grep "SortMeRNA version"
	
CMD ["./start_plugin.sh"]
