# VERSION: 2026.02.05

# variables, specifically for this plugin
# qiita plugin name
ARG PLUGIN=qp-deblur

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

# config for conda within plugin image
ARG MINIFORGE_VERSION=24.1.2-0
ENV PATH=${CONDA_DIR}/bin:${PATH}

ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

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
RUN conda create --quiet -n ${PLUGIN} python=3.5 pip libgfortran=3
# Make RUN commands use the new environment:
# append --format docker to the build command, see https://github.com/containers/podman/issues/8477
SHELL ["conda", "run", "-p", "${CONDA_DIR}/envs/${PLUGIN}", "/bin/bash", "-c"]

# Install qiita_client
# RUN git clone -b master https://github.com/qiita-spots/qiita_client.git
RUN git clone -b refactor_exposeBaseDataDir https://github.com/jlab/qiita_client.git && \
	sed -i "s/f'Entered BaseQiitaPlugin._register_command({command.name})'/'Entered BaseQiitaPlugin._register_command(%s)' % command.name/"  qiita_client/qiita_client/plugin.py && \
	cd qiita_client && \
	pip install --no-cache-dir .

RUN conda install --quiet --yes -c bioconda -c biocore "VSEARCH=2.7.0" MAFFT=7.310 SortMeRNA=2.0 fragment-insertion gcc && \
	pip install -U pip && \
	pip install numpy cython pandas && \
	pip install scikit-bio==0.5.5 && \
	pip install -U pip pip-system-certs

# Install qiita plugin
RUN git clone -b uncouple_clientpush  https://github.com/jlab/${PLUGIN}.git /${PLUGIN}
WORKDIR /${PLUGIN}
RUN pip install .

COPY requirements.txt ./requirements.txt
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt


# ==========================
# Stage 2: Runtime
# ==========================
FROM python:3.5-slim
ARG PLUGIN
ARG QIITA_PLUGINS_DIR
ARG QIITA_CERT_DIR
ARG CONDA_DIR

# let the container know it's plugin name
ENV PLUGIN=${PLUGIN}

# deblur dependent binaries + necessary libraries: mafft, vsearch, sortmerna
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/bin/mafft ${CONDA_DIR}/envs/${PLUGIN}/bin/vsearch ${CONDA_DIR}/envs/${PLUGIN}/bin/indexdb_rna ${CONDA_DIR}/envs/${PLUGIN}/bin/sortmerna /usr/local/bin/
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/libexec/mafft ${CONDA_DIR}/envs/${PLUGIN}/libexec/mafft/
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libgomp.so.1.0.0 /lib/x86_64-linux-gnu/libgomp.so.1

# python package compile in build stage
COPY --from=builder /wheels /wheels
RUN pip install --no-cache-dir /wheels/* \
	&& rm -rf /usr/local/lib/python3.5/site-packages/biom/tests
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/bin/run-sepp.sh ${CONDA_DIR}/envs/${PLUGIN}/bin/seppJsonMerger.jar ${CONDA_DIR}/envs/${PLUGIN}/bin/hmm* ${CONDA_DIR}/envs/${PLUGIN}/bin/pplacer ${CONDA_DIR}/envs/${PLUGIN}/bin/guppy /usr/local/bin/

# minimal Java Runtime Environment for SEPP's seppJsonMerger.jar
RUN mkdir -p /usr/share/man/man1 && \
    echo "deb [trusted=yes] http://archive.debian.org/debian buster main" > /etc/apt/sources.list && \
    echo "deb [trusted=yes] http://archive.debian.org/debian-security buster/updates main" >> /etc/apt/sources.list && \
    echo "deb [trusted=yes] http://archive.debian.org/debian buster-updates main" >> /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends openjdk-11-jre-headless && \
    rm -rf /var/lib/apt/lists/*

# copy SEPP
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/share/fragment-insertion/sepp/run_sepp.py ${CONDA_DIR}/envs/${PLUGIN}/share/fragment-insertion/sepp/run_sepp.py
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/share/fragment-insertion/sepp/sepp        ${CONDA_DIR}/envs/${PLUGIN}/share/fragment-insertion/sepp/sepp
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/share/fragment-insertion/sepp/dendropy    ${CONDA_DIR}/envs/${PLUGIN}/share/fragment-insertion/sepp/dendropy
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/share/fragment-insertion/sepp/home.path   ${CONDA_DIR}/envs/${PLUGIN}/share/fragment-insertion/sepp/home.path
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/share/fragment-insertion/sepp/.sepp/main.config ${CONDA_DIR}/envs/${PLUGIN}/share/fragment-insertion/sepp/.sepp/main.config
RUN sed -i "s|${CONDA_DIR}/envs/${PLUGIN}/share/fragment-insertion/sepp/.sepp/bundled-v4.3.5/|/usr/local/bin/|g" ${CONDA_DIR}/envs/${PLUGIN}/share/fragment-insertion/sepp/.sepp/main.config

# following step increases image size from by 1.3 GB!! Better mount as volume and "make" these files during Makefile execution
# COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/share/fragment-insertion/ref/ ${CONDA_DIR}/envs/${PLUGIN}/share/fragment-insertion/ref/

# install tornado based trigger layer in base environment
RUN pip install -U --no-cache-dir tornado pip-system-certs

# use git branch instead of pypi version (stored via wheel)
COPY --from=builder /qiita_client /qiita_client
RUN cd /qiita_client && pip install .

WORKDIR /

# Handling of certificates, such that plugin can verify qiita main
RUN mkdir -p ${QIITA_CERT_DIR}/
COPY qiita_server_certificates/*_server* ${QIITA_CERT_DIR}/
ENV REQUESTS_CA_BUNDLE=${QIITA_CERT_DIR}/qiita_server_certificates.pem
ENV SSL_CERT_FILE=${QIITA_CERT_DIR}/qiita_server_certificates.pem

# setup qiita plugin
ENV QIITA_PLUGINS_DIR=${QIITA_PLUGINS_DIR}
RUN mkdir -p ${QIITA_PLUGINS_DIR}/ && \
	sed -i "s|^#\!.*|#\!/usr/local/bin/python|" /usr/local/bin/configure_deblur && \
	sed -i "s|^#\!.*|#\!/usr/local/bin/python|" /usr/local/bin/start_deblur && \
	ln -s /usr/local/bin/configure_deblur /usr/local/bin/configure_${PLUGIN} && \
    ln -s /usr/local/bin/start_deblur /usr/local/bin/start_${PLUGIN} && \
	configure_${PLUGIN} --env-script "true" --server-cert `find ${QIITA_CERT_DIR}/ -name "*_server.crt" -type f` https && \
	sed -i -E "s/^START_SCRIPT = .+/START_SCRIPT = python \/start_plugin.py ${PLUGIN}/" ${QIITA_PLUGINS_DIR}/*.conf

# copy http listener
COPY trigger.py /trigger.py

# for job execution
COPY start_plugin.sh .

# for testing
COPY test_plugin.sh /test_plugin.sh

CMD ["./start_plugin.sh"]
