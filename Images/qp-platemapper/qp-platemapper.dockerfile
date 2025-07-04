FROM ubuntu:24.04

ARG MINIFORGE_VERSION=24.1.2-0

ENV CONDA_DIR=/opt/conda
ENV PATH=${CONDA_DIR}/bin:${PATH}

RUN apt-get -y  update
RUN apt-get -y --fix-missing install \
	git \
	wget \
	libpq-dev \
	python3-dev \
	gcc \
	build-essential \
	zip

# install miniforge3 for "conda"
# see https://github.com/conda-forge/miniforge-images/blob/master/ubuntu/Dockerfile
RUN wget https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/Miniforge3-${MINIFORGE_VERSION}-Linux-x86_64.sh -O /tmp/miniforge3.sh && \
	/bin/bash /tmp/miniforge3.sh -b -p ${CONDA_DIR} && \
	echo ". ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate base" >> /etc/skel/.bashrc && \
	echo ". ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate base" >> ~/.bashrc && \
	conda init && \
	rm -f /tmp/miniforge3.sh

# install tornado based trigger layer in base environment
RUN pip install -U pip
RUN conda install tornado
COPY trigger.py /trigger.py

# Download qiime2 yaml
RUN wget --quiet https://data.qiime2.org/distro/core/qiime2-2023.5-py38-linux-conda.yml

# Create conda env
RUN conda env create --name platemapper -y --file qiime2-2023.5-py38-linux-conda.yml
# Make RUN commands use the new environment:
# append --format docker to the build command, see https://github.com/containers/podman/issues/8477
SHELL ["conda", "run", "-p", "/opt/conda/envs/platemapper", "/bin/bash", "-c"]

RUN pip install -U pip
RUN pip install https://github.com/qiita-spots/qiita_client/archive/master.zip
RUN pip install https://github.com/qiita-spots/qiita-files/archive/master.zip
RUN pip install https://github.com/biocore/q2-mislabeled/archive/refs/heads/main.zip
RUN git clone https://github.com/qiita-spots/qp-qiime2.git
WORKDIR qp-qiime2
RUN pip install -e .
RUN pip install --upgrade certifi
RUN pip install pip-system-certs

WORKDIR /
RUN git clone -b    make_qiita_plugin https://github.com/jlab/qp-platemapper.git
WORKDIR qp-platemapper
RUN rm -f pyproject.toml
RUN pip install -e .

# TODO: should the plugin get the server configuration?!
RUN export QIITA_CONFIG_FP=/qiita/config_qiita_oidc.cfg

WORKDIR /

COPY start_qp-platemapper.sh .
RUN chmod 755 start_qp-platemapper.sh

RUN mkdir -p /unshared_plugins
ENV QIITA_PLUGINS_DIR=/unshared_plugins/

##  Export cert and config filepaths
COPY Certificates /unshared_certificates
RUN cat /unshared_certificates/stefan_rootca.crt >> `python -c "import certifi; print(certifi.where())"`  # append own rootCA onto chain of trust
RUN export REQUESTS_CA_BUNDLE=`python -c "import certifi; print(certifi.where())"`
RUN export SSL_CERT_FILE=`python -c "import certifi; print(certifi.where())"`

#RUN export QIITA_ROOTCA_CERT=/unshared_certificates/ci_rootca.crt
RUN chmod u+x /qp-platemapper/scripts/configure_platemapper /qp-platemapper/scripts/start_platemapper
RUN /qp-platemapper/scripts/configure_platemapper  --env-script 'true' --server-cert /unshared_certificates/stefan_server.crt
RUN sed -i -E "s/^START_SCRIPT = .+/START_SCRIPT = python \/start_plugin.py qp-platemapper/" /unshared_plugins/*.conf

CMD ["./start_qp-platemapper.sh"]
