FROM ubuntu:24.04

ARG MINIFORGE_VERSION=24.1.2-0

ENV CONDA_DIR=/opt/conda
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
RUN wget https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/Miniforge3-${MINIFORGE_VERSION}-Linux-x86_64.sh -O /tmp/miniforge3.sh && \
	/bin/bash /tmp/miniforge3.sh -b -p ${CONDA_DIR} && \
	echo ". ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate base" >> /etc/skel/.bashrc && \
	echo ". ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate base" >> ~/.bashrc && \
	conda init && \
	rm -f /tmp/miniforge3.sh

# Download qtp-biom yaml
RUN wget https://data.qiime2.org/distro/core/qiime2-2022.11-py38-linux-conda.yml

# Create conda env
RUN conda env create --quiet -n qtp-biom --file qiime2-2022.11-py38-linux-conda.yml
# Make RUN commands use the new environment:
# append --format docker to the build command, see https://github.com/containers/podman/issues/8477
SHELL ["conda", "run", "-p", "/opt/conda/envs/qtp-biom", "/bin/bash", "-c"]

RUN pip install -U pip
RUN pip install https://github.com/qiita-spots/qiita_client/archive/master.zip
RUN pip install https://github.com/qiita-spots/qiita-files/archive/master.zip
RUN git clone https://github.com/qiita-spots/qtp-biom.git
WORKDIR qtp-biom
RUN pip install -e .
RUN pip install --upgrade certifi
RUN pip install pip-system-certs
RUN conda install tornado
COPY trigger.py /trigger.py

##  Export cert and config filepaths
RUN export QIITA_ROOTCA_CERT=/qiita/qiita_core/support_files/ci_server.crt
RUN export QIITA_CONFIG_FP=/qiita/config_qiita_oidc.cfg

WORKDIR /

COPY start_qtp-biom.sh .
RUN chmod 755 start_qtp-biom.sh

RUN mkdir -p /unshared_plugins
ENV QIITA_PLUGINS_DIR=/unshared_plugins/

RUN /qtp-biom/scripts/configure_biom --env-script "source /home/joe/.bashrc; conda activate env_deblur" --server-cert /qiita/qiita_core/support_files/ci_rootca.crt


CMD ["conda", "run", "-n", "qtp-biom", "./start_qtp-biom.sh"]