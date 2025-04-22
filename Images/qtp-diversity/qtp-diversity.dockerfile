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

# install tornado based trigger layer in base environment
RUN pip install -U pip
RUN conda install tornado
COPY trigger.py /trigger.py

# Download qiime2 yaml
RUN wget -q https://data.qiime2.org/distro/core/qiime2-2022.11-py38-linux-conda.yml

# Create conda env
RUN conda env create --name qiime2 -y --file qiime2-2022.11-py38-linux-conda.yml
# Make RUN commands use the new environment:
# append --format docker to the build command, see https://github.com/containers/podman/issues/8477
SHELL ["conda", "run", "-p", "/opt/conda/envs/qiime2", "/bin/bash", "-c"]

RUN pip install -U pip
RUN pip install https://github.com/qiita-spots/qiita_client/archive/master.zip
RUN pip install https://github.com/qiita-spots/qiita-files/archive/master.zip
RUN pip install https://github.com/biocore/q2-mislabeled/archive/refs/heads/main.zip
RUN git clone https://github.com/qiita-spots/qtp-diversity.git
WORKDIR qtp-diversity
RUN pip install -e .
RUN pip install --upgrade certifi
RUN pip install pip-system-certs

# TODO: should the plugin get the server configuration?!
RUN export QIITA_CONFIG_FP=/qiita/config_qiita_oidc.cfg

WORKDIR /

COPY start_qtp-diversity.sh .
RUN chmod 755 start_qtp-diversity.sh

RUN mkdir -p /unshared_plugins
ENV QIITA_PLUGINS_DIR=/unshared_plugins/

##  Export cert and config filepaths
COPY Certificates /unshared_certificates
RUN cat /unshared_certificates/stefan_rootca.crt >> `python -c "import certifi; print(certifi.where())"`  # append own rootCA onto chain of trust
RUN export REQUESTS_CA_BUNDLE=`python -c "import certifi; print(certifi.where())"`
RUN export SSL_CERT_FILE=`python -c "import certifi; print(certifi.where())"`

#RUN export QIITA_ROOTCA_CERT=/unshared_certificates/ci_rootca.crt
RUN chmod u+x /qtp-diversity/scripts/configure_diversity_types /qtp-diversity/scripts/start_diversity_types
RUN /qtp-diversity/scripts/configure_diversity_types --env-script "true" --ca-cert /unshared_certificates/stefan_server.crt
RUN sed -i -E "s/^START_SCRIPT = .+/START_SCRIPT = python \/start_plugin.py qtp-diversity/" /unshared_plugins/*.conf

CMD ["./start_qtp-diversity.sh"]
