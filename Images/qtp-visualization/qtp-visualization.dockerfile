# VERSION: 2025.11.04

FROM ubuntu:24.04 AS builder

ARG MINIFORGE_VERSION=24.1.2-0
ARG QIIME2RELEASE=2023.5

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

# Download qiime2 yaml (make sure to use a qiime2 version that is able to visualize qiime artifacts of the correct version)
RUN wget --quiet https://data.qiime2.org/distro/core/qiime2-${QIIME2RELEASE}-py38-linux-conda.yml

RUN sed -n '/channels/,/dependencies/p' qiime2-${QIIME2RELEASE}-py38-linux-conda.yml > tinyq2.yml && \
	echo "  - q2-metadata=${QIIME2RELEASE}" >> tinyq2.yml && \
	echo "  - q2-mystery-stew=${QIIME2RELEASE}" >> tinyq2.yml && \
	echo "  - q2-types=${QIIME2RELEASE}" >> tinyq2.yml && \
	echo "  - q2cli=${QIIME2RELEASE}" >> tinyq2.yml && \
	echo "  - q2templates=${QIIME2RELEASE}" >> tinyq2.yml && \
	echo "  - typeguard=2.13.3" >> tinyq2.yml && \
	echo "  - qiime2" >> tinyq2.yml

# Create conda env
RUN conda config --set channel_priority strict && conda env create --name qtp-visualization -y --file tinyq2.yml
# Make RUN commands use the new environment:
# append --format docker to the build command, see https://github.com/containers/podman/issues/8477
SHELL ["conda", "run", "-p", "/opt/conda/envs/qtp-visualization", "/bin/bash", "-c"]

ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

RUN pip install -U pip
#RUN pip install https://github.com/qiita-spots/qiita_client/archive/master.zip
RUN git clone -b uncouple_clientpush https://github.com/jlab/qiita_client.git
RUN cd qiita_client && pip install --no-cache-dir .

#RUN pip install https://github.com/qiita-spots/qiita-files/archive/master.zip
RUN git clone -b master https://github.com/qiita-spots/qiita-files.git
RUN cd /qiita-files && pip install -e . -v

RUN git clone -b uncouple_clientpush https://github.com/jlab/qtp-visualization.git
WORKDIR /qtp-visualization
RUN sed -i "s|'qiita_client', 'click >= 3.3', 'qiime2'|'click >= 3.3'|" setup.py
RUN pip install -e .
RUN pip install --upgrade certifi
RUN pip install pip-system-certs

WORKDIR /

RUN repo=q2-metadata; mkdir -p /$repo && wget -O- https://github.com/qiime2/$repo/archive/refs/tags/${QIIME2RELEASE}.0.tar.gz | tar -xz --strip-components=1 -C /$repo
RUN repo=q2-mystery-stew; mkdir -p /$repo && wget -O- https://github.com/qiime2/$repo/archive/refs/tags/${QIIME2RELEASE}.0.tar.gz | tar -xz --strip-components=1 -C /$repo
RUN repo=q2-types; mkdir -p /$repo && wget -O- https://github.com/qiime2/$repo/archive/refs/tags/${QIIME2RELEASE}.0.tar.gz | tar -xz --strip-components=1 -C /$repo
RUN repo=q2cli; mkdir -p /$repo && wget -O- https://github.com/qiime2/$repo/archive/refs/tags/${QIIME2RELEASE}.1.tar.gz | tar -xz --strip-components=1 -C /$repo
RUN repo=q2templates; mkdir -p /$repo && wget -O- https://github.com/qiime2/$repo/archive/refs/tags/${QIIME2RELEASE}.0.tar.gz | tar -xz --strip-components=1 -C /$repo
RUN repo=qiime2; mkdir -p /$repo && wget -O- https://github.com/qiime2/$repo/archive/refs/tags/${QIIME2RELEASE}.1.tar.gz | tar -xz --strip-components=1 -C /$repo

COPY requirements.txt ./requirements.txt
# RUN conda install cython
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt
# RUN pip install iow



# ==========================
# Stage 2: Runtime
# ==========================
FROM python:3.8-slim

# let the container know it's plugin name
ENV PLUGIN=qtp-visualization

# python package compile in build stage
COPY --from=builder /wheels /wheels

RUN pip install --no-cache-dir /wheels/* \
	&& rm -rf rm -rf `find /usr/local/lib/python3.8/site-packages -type d -name "tests" | grep -v numpy`

COPY start_qtp-visualization.sh .
RUN chmod 755 start_qtp-visualization.sh

RUN mkdir -p /unshared_plugins
ENV QIITA_PLUGINS_DIR=/unshared_plugins/

COPY trigger_noconda.py /trigger.py

##  Export cert and config filepaths
COPY qiita_server_certificates/qiita_server_certificates.pem /qiita_server_certificates/qiita_server_certificates.pem
ENV REQUESTS_CA_BUNDLE=/qiita_server_certificates/qiita_server_certificates.pem
ENV SSL_CERT_FILE=/qiita_server_certificates/qiita_server_certificates.pem

RUN chmod u+x /usr/local/bin/configure_visualization_types /usr/local/bin/start_visualization_types
COPY qiita_server_certificates/*_server.* /qiita_server_certificates/
# qiime2 expects to have a CONDA_PREFIX set, see https://github.com/qiime2/qiime2/blob/812fd09cf80b4ed76c1f39827ae2dba729448436/qiime2/sdk/parallel_config.py#L30
ENV CONDA_PREFIX=/usr/local
RUN configure_visualization_types --env-script "true" --server-cert `find /qiita_server_certificates/ -name "*_server.crt" -type f` https
RUN sed -i -E "s/^START_SCRIPT = .+/START_SCRIPT = python \/start_plugin.py qtp-visualization/" /unshared_plugins/*.conf

# for testing
COPY test_plugin.sh /test_plugin.sh

CMD ["./start_qtp-visualization.sh"]