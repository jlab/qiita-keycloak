# VERSION: 2025.09.12

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
	zip \
	tzdata

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
RUN pip install tornado
COPY trigger.py /trigger.py

# Download qiime2 yaml
RUN wget --quiet https://data.qiime2.org/distro/core/qiime2-2023.5-py38-linux-conda.yml

# Create conda env
RUN conda env create --name qiime2 -y --file qiime2-2023.5-py38-linux-conda.yml \
  && conda clean --all -y \
  && rm -rf /opt/conda/pkgs
# Make RUN commands use the new environment:
# append --format docker to the build command, see https://github.com/containers/podman/issues/8477
SHELL ["conda", "run", "-p", "/opt/conda/envs/qiime2", "/bin/bash", "-c"]

RUN pip install -U pip
RUN pip install https://github.com/qiita-spots/qiita_client/archive/master.zip
RUN pip install https://github.com/qiita-spots/qiita-files/archive/master.zip
RUN pip install https://github.com/biocore/q2-mislabeled/archive/refs/heads/main.zip
RUN pip install q2-umap q2-greengenes2
RUN git clone https://github.com/qiita-spots/qp-qiime2.git
WORKDIR /qp-qiime2

RUN sed -i "s|self.basedir, '..', '..', '|'/|g" /qp-qiime2/qp_qiime2/tests/test_qiime2.py

RUN pip install -e .
RUN pip install --upgrade certifi
RUN pip install pip-system-certs

# configuring the databases available for QIIME 2
RUN mkdir /databases
RUN wget --quiet -O "/databases/gg-13-8-99-515-806-nb-classifier.qza" "https://data.qiime2.org/2021.4/common/gg-13-8-99-515-806-nb-classifier.qza"
RUN export QP_QIIME2_DBS=/databases

# configuring the filtering QZAs available for QIIME 2
RUN mkdir /filtering
RUN wget -O /filtering/bloom-analyses.zip https://github.com/knightlab-analyses/bloom-analyses/archive/refs/heads/master.zip \
  && unzip -j /filtering/bloom-analyses.zip bloom-analyses-master/data/qiime2-artifacts-for-qiita/*.qza -d /filtering/ \
  && rm -f /filtering/bloom-analyses.zip
RUN export QP_QIIME2_FILTER_QZA=/filtering/

# TODO: should the plugin get the server configuration?!
RUN export QIITA_CONFIG_FP=/qiita/config_qiita_oidc.cfg

# let the container know it's plugin name
ENV PLUGIN=qp-qiime2

# configure language
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

# configure timezone
RUN ln -fs /usr/share/zoneinfo/Etc/UTC /etc/localtime
RUN dpkg-reconfigure -f noninteractive tzdata


WORKDIR /

COPY start_qp-qiime2.sh .
RUN chmod 755 start_qp-qiime2.sh

RUN mkdir -p /unshared_plugins
ENV QIITA_PLUGINS_DIR=/unshared_plugins/

##  Export cert and config filepaths
COPY qiita_server_certificates/qiita_server_certificates.pem /qiita_server_certificates/qiita_server_certificates.pem
ENV REQUESTS_CA_BUNDLE=/qiita_server_certificates/qiita_server_certificates.pem
ENV SSL_CERT_FILE=/qiita_server_certificates/qiita_server_certificates.pem

#RUN export QIITA_ROOTCA_CERT=/unshared_certificates/ci_rootca.crt
RUN chmod u+x /qp-qiime2/scripts/configure_qiime2 /qp-qiime2/scripts/start_qiime2
ENV QP_QIIME2_DBS=/databases
ENV QP_QIIME2_FILTER_QZA=/filtering/
COPY qiita_server_certificates/*_server.* /qiita_server_certificates/
RUN /qp-qiime2/scripts/configure_qiime2 --env-script 'true' --server-cert `find /qiita_server_certificates/ -name "*_server.crt" -type f`
RUN sed -i -E "s/^START_SCRIPT = .+/START_SCRIPT = python \/start_plugin.py qp-qiime2/" /unshared_plugins/*.conf

# for testing
COPY test_plugin.sh /test_plugin.sh

CMD ["./start_qp-qiime2.sh"]
