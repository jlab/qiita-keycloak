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

# biom artifact validation throws an error since provenance tracking of Qiime2 cannot get proper time zone information, if not configured here
# https://stackoverflow.com/questions/21717411/timezone-information-missing-in-pytz
RUN dpkg-reconfigure -f noninteractive tzdata

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

# Download qtp-biom yaml
RUN wget https://raw.githubusercontent.com/qiime2/distributions/refs/heads/dev/2025.7/tiny/released/qiime2-tiny-ubuntu-latest-conda.yml
RUN echo "- q2-feature-table" >> qiime2-tiny-ubuntu-latest-conda.yml
RUN sed -i "s|- conda-forge|- https://packages.qiime2.org/qiime2/2025.7/amplicon/released/\n- conda-forge|" qiime2-tiny-ubuntu-latest-conda.yml
# Create conda env
RUN conda env create --quiet -n qtp-biom --file qiime2-tiny-ubuntu-latest-conda.yml
# Make RUN commands use the new environment:
# append --format docker to the build command, see https://github.com/containers/podman/issues/8477
SHELL ["conda", "run", "-p", "/opt/conda/envs/qtp-biom", "/bin/bash", "-c"]

RUN pip install -U pip
RUN pip install https://github.com/qiita-spots/qiita_client/archive/master.zip
# RUN pip install https://github.com/qiita-spots/qiita-files/archive/master.zip
COPY ./qiita-files /qiita-files
RUN cd /qiita-files && pip install -e . -v
# RUN git clone https://github.com/qiita-spots/qtp-biom.git
COPY ./qtp-biom /qtp-biom
WORKDIR qtp-biom
RUN pip install -e .
RUN pip install --upgrade certifi
RUN pip install pip-system-certs
RUN conda install tornado
COPY trigger.py /trigger.py

# TODO: should the plugin get the server configuration?!
RUN export QIITA_CONFIG_FP=/qiita/config_qiita_oidc.cfg

WORKDIR /

COPY start_qtp-biom.sh .
RUN chmod 755 start_qtp-biom.sh

RUN mkdir -p /unshared_plugins
ENV QIITA_PLUGINS_DIR=/unshared_plugins/

##  Export cert and config filepaths
COPY qiita_server_certificates/qiita_server_certificates.pem /qiita_server_certificates/qiita_server_certificates.pem
ENV REQUESTS_CA_BUNDLE=/qiita_server_certificates/qiita_server_certificates.pem
ENV SSL_CERT_FILE=/qiita_server_certificates/qiita_server_certificates.pem

#RUN export QIITA_ROOTCA_CERT=/unshared_certificates/ci_rootca.crt
COPY qiita_server_certificates/*_server.* /qiita_server_certificates/
RUN /qtp-biom/scripts/configure_biom --env-script "true" --server-cert `find /qiita_server_certificates/ -name "*_server.crt" -type f`
RUN sed -i -E "s/^START_SCRIPT = .+/START_SCRIPT = python \/start_plugin.py qtp-biom/" /unshared_plugins/*.conf

CMD ["./start_qtp-biom.sh"]
