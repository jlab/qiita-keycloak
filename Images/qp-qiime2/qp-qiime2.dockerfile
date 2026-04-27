# VERSION: 2026.04.01

# variables, specifically for this plugin
# qiita plugin name
ARG PLUGIN=qp-qiime2

# variables, identical for whole qiita setup
ARG QIITA_PLUGINS_DIR=/unshared_plugins
ARG QIITA_CERT_DIR=/qiita_server_certificates

# for clear dockerfile
ARG CONDA_DIR=/opt/conda

# ==========================
# Stage 1: Build wheels  <-- there is currently no stage 2
# ==========================
FROM ubuntu:24.04
ARG PLUGIN
ARG QIITA_PLUGINS_DIR
ARG QIITA_CERT_DIR
ARG CONDA_DIR

# let the container know it's plugin name
ENV PLUGIN=${PLUGIN}

# config for conda within plugin image
ARG MINIFORGE_VERSION=24.1.2-0
ENV PATH=${CONDA_DIR}/bin:${PATH}

ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8
ENV QP_QIIME2_DBS=/databases
ENV QP_QIIME2_FILTER_QZA=/filtering/

RUN apt-get -y  update && \
	apt-get install -y --no-install-recommends \
		git \
		wget \
		libpq-dev \
		python3-dev \
		gcc \
		build-essential \
		zip \
		unzip \
		tzdata \
		ca-certificates \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*

# configure timezone
RUN ln -fs /usr/share/zoneinfo/Etc/UTC /etc/localtime \
	&& dpkg-reconfigure -f noninteractive tzdata

# install miniforge3 for "conda"
# see https://github.com/conda-forge/miniforge-images/blob/master/ubuntu/Dockerfile
RUN wget --no-verbose https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/Miniforge3-${MINIFORGE_VERSION}-Linux-x86_64.sh -O /tmp/miniforge3.sh && \
	/bin/bash /tmp/miniforge3.sh -b -p ${CONDA_DIR} && \
	echo ". ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate base" >> /etc/skel/.bashrc && \
	echo ". ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate base" >> ~/.bashrc && \
	conda init && \
	rm -f /tmp/miniforge3.sh

# install tornado based trigger layer in base environment
RUN pip install -U pip \
	&& pip install --no-cache-dir tornado

# Download qiime2 yaml and  Create conda env
# The remove list is the result of the jupyter notebook "determine_spare_conda_dependencies.ipynb"
RUN wget --quiet https://data.qiime2.org/distro/core/qiime2-2023.5-py38-linux-conda.yml \
	&& conda env create --name ${PLUGIN} -y --file qiime2-2023.5-py38-linux-conda.yml \
	&& conda remove -n ${PLUGIN} --force htslib r-bh pigz bioconductor-summarizedexperiment q2-demux python-isal q2-dada2 q2-alignment gneiss r-futile.logger r-rcppparallel q2-fragment-insertion dnaio mafft pbzip2 cutadapt q2-quality-filter q2-quality-control gawk pcre xopen q2-vsearch q2-deblur r-futile.options r-hwriter xyzservices sortmerna bioconductor-biocparallel bioconductor-genomicalignments hmmer bioconductor-decontam bioconductor-rhtslib bioconductor-delayedarray bioconductor-shortread bioconductor-dada2 deblur samtools r-matrixstats r-lambda.r r-bitops isa-l bowtie2 sepp r-snow bioconductor-genomicranges openjdk q2-cutadapt bioconductor-matrixgenerics r-formatr q2-gneiss blast bokeh dendropy giflib bioconductor-rsamtools \
  	&& conda clean --all -y \
  	&& rm -rf ${CONDA_DIR}/pkgs
# Make RUN commands use the new environment:
# append --format docker to the build command, see https://github.com/containers/podman/issues/8477
SHELL ["conda", "run", "-p", "${CONDA_DIR}/envs/${PLUGIN}", "/bin/bash", "-c"]

# Install qiita_client
#RUN pip install https://github.com/qiita-spots/qiita_client/archive/master.zip
RUN pip install -U pip && \
	git clone -b master https://github.com/qiita-spots/qiita_client.git && \
	cd qiita_client && \
	pip install --no-cache-dir .

# Install qiita-files and q2-mislabeled
RUN pip install https://github.com/qiita-spots/qiita-files/archive/master.zip \
	&& pip install https://github.com/biocore/q2-mislabeled/archive/refs/heads/main.zip \
	&& pip install q2-umap q2-greengenes2

# Install qiita plugin
#RUN git clone https://github.com/qiita-spots/qp-qiime2.git
RUN git clone --depth 1 -b master https://github.com/qiita-spots/${PLUGIN}.git /${PLUGIN}
WORKDIR /${PLUGIN}
RUN sed -i "s|self.basedir, '..', '..', '|'/|g" /${PLUGIN}/qp_qiime2/tests/test_qiime2.py && \
    sed -i "s|'gneiss', ||" /${PLUGIN}/qp_qiime2/qp_qiime2.py && \
	pip install -e . && \
	pip install --upgrade certifi && \
	pip install pip-system-certs

# configuring the databases available for QIIME 2
RUN mkdir /databases && \
	wget --no-check-certificate --quiet -O "/databases/gg-13-8-99-515-806-nb-classifier.qza" "https://data.qiime2.org/2021.4/common/gg-13-8-99-515-806-nb-classifier.qza"

# configuring the filtering QZAs available for QIIME 2
RUN mkdir /filtering && \
	wget --no-check-certificate -O /filtering/bloom-analyses.zip https://github.com/knightlab-analyses/bloom-analyses/archive/refs/heads/master.zip && \
    unzip -j /filtering/bloom-analyses.zip bloom-analyses-master/data/qiime2-artifacts-for-qiita/*.qza -d /filtering/ && \
    rm -f /filtering/bloom-analyses.zip

# TODO: should the plugin get the server configuration?!
RUN export QIITA_CONFIG_FP=/qiita/config_qiita_oidc.cfg


WORKDIR /

# Handling of certificates, such that plugin can verify qiita main
RUN mkdir -p ${QIITA_CERT_DIR}/
COPY Certificates/tinqiita/*_server* ${QIITA_CERT_DIR}/
ENV REQUESTS_CA_BUNDLE=${QIITA_CERT_DIR}/tinqiita_server_certificates.pem
ENV SSL_CERT_FILE=${QIITA_CERT_DIR}/tinqiita_server_certificates.pem

# setup qiita plugin
RUN mkdir -p ${QIITA_PLUGINS_DIR}/
ENV QIITA_PLUGINS_DIR=${QIITA_PLUGINS_DIR}

#RUN export QIITA_ROOTCA_CERT=/unshared_certificates/ci_rootca.crt
RUN chmod u+x /${PLUGIN}/scripts/configure_qiime2 /${PLUGIN}/scripts/start_qiime2 && \
	ln -s /${PLUGIN}/scripts/configure_qiime2 /${PLUGIN}/scripts/configure_${PLUGIN} && \
	ln -s /${PLUGIN}/scripts/start_qiime2 /${PLUGIN}/scripts/start_${PLUGIN} && \
	/${PLUGIN}/scripts/configure_${PLUGIN} --env-script 'true' --server-cert `find ${QIITA_CERT_DIR}/ -name "*_server.crt" -type f` https && \
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
