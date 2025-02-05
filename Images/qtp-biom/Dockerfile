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
	gcc
RUN apt-get -y install build-essential
# install miniforge3 for "conda"
# see https://github.com/conda-forge/miniforge-images/blob/master/ubuntu/Dockerfile
RUN wget https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/Miniforge3-${MINIFORGE_VERSION}-Linux-x86_64.sh -O /tmp/miniforge3.sh && \
	/bin/bash /tmp/miniforge3.sh -b -p ${CONDA_DIR} && \
	echo ". ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate base" >> /etc/skel/.bashrc && \
	echo ". ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate base" >> ~/.bashrc \
	conda init

# Download qtp-biom yaml
RUN wget https://data.qiime2.org/distro/core/qiime2-2022.11-py38-linux-conda.yml

# Create conda env
RUN conda env create --quiet -n qtp-biom --file qiime2-2022.11-py38-linux-conda.yml

#  Export cert and config filepaths
RUN export QIITA_ROOTCA_CERT=/qiita/qiita_core/support_files/ci_server.crt
RUN export QIITA_CONFIG_FP=/qiita/config_qiita_oidc.cfg

# Make RUN commands use the new environment:
# append --format docker to the build command, see https://github.com/containers/podman/issues/8477
SHELL ["conda", "run", "-n", "qtp-biom", "/bin/bash", "-c"]

RUN pip install -U pip
RUN pip install https://github.com/qiita-spots/qiita_client/archive/master.zip
RUN pip install https://github.com/qiita-spots/qtp-biom/archive/master.zip
RUN git clone https://github.com/qiita-spots/qtp-biom.git

RUN pip install --upgrade certifi
RUN pip install pip-system-certs

RUN sed -i 's/2.1.4 - Qiime2/2.1.5 - Qiime2 Annas Version/g' /qtp-biom/qtp_biom/__init__.py

COPY start_qtp-biom.sh .
RUN chmod 755 start_qtp-biom.sh

ENTRYPOINT ["conda", "run", "-n", "qtp-biom", "./start_qtp-biom.sh"]