# VERSION: 2025.09.08

# ==========================
# Stage 1: Build wheels (~5.8 GB)
# ==========================
FROM ubuntu:24.04 AS builder

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

# Create conda env
RUN conda create --name qtp-sequencing -y -c conda-forge -c bioconda pip pigz quast fqtools python=3.9
# Make RUN commands use the new environment:
# append --format docker to the build command, see https://github.com/containers/podman/issues/8477
SHELL ["conda", "run", "-p", "/opt/conda/envs/qtp-sequencing", "/bin/bash", "-c"]

RUN pip install -U pip
#RUN pip install https://github.com/qiita-spots/qiita_client/archive/master.zip
RUN git clone -b master https://github.com/qiita-spots/qiita_client.git
RUN cd qiita_client && pip install --no-cache-dir .

# RUN pip install https://github.com/qiita-spots/qiita-files/archive/master.zip
RUN git clone -b master https://github.com/qiita-spots/qiita-files.git
RUN cd /qiita-files && pip install -e . -v

RUN git clone https://github.com/qiita-spots/qtp-sequencing.git
WORKDIR /qtp-sequencing
RUN sed -i "s|'qiita-files @ https://github.com/'||" setup.py
RUN sed -i "s|'qiita-spots/qiita-files/archive/master.zip',||" setup.py
RUN sed -i "s|'qiita_client @ https://github.com/'||" setup.py
RUN sed -i "s|'qiita-spots/qiita_client/archive/master.zip'||" setup.py
RUN pip install -e .
RUN pip install --upgrade certifi
RUN pip install pip-system-certs

COPY requirements.txt ./requirements.txt
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt

# ==========================
# Stage 2: Runtime
# ==========================
FROM python:3.9-slim

# let the container know it's plugin name
ENV PLUGIN=qtp-sequencing

# python package compile in build stage
COPY --from=builder /wheels /wheels

RUN pip install --no-cache-dir /wheels/* \
	&& rm -rf rm -rf `find /usr/local/lib/python3.9/site-packages -type d -name "tests" | grep -v numpy`

# "install" https://github.com/alastair-droop/fqtools
COPY --from=builder /opt/conda/envs/qtp-sequencing/bin/fqtools /usr/local/bin/fqtools
COPY --from=builder /opt/conda/envs/qtp-sequencing/lib/libhts.so.1.22.1 /lib/x86_64-linux-gnu/libhts.so.3
COPY --from=builder /opt/conda/envs/qtp-sequencing/lib/libdeflate.so.0 /lib/x86_64-linux-gnu/

# "install" pigz
COPY --from=builder /opt/conda/envs/qtp-sequencing/bin/pigz /usr/local/bin/

COPY trigger.py /trigger.py

# link to quast program
RUN ln -s /usr/local/bin/quast.py /usr/local/bin/quast

# WORKDIR /

COPY start_qtp-sequencing.sh .
RUN chmod 755 start_qtp-sequencing.sh

RUN mkdir -p /unshared_plugins
ENV QIITA_PLUGINS_DIR=/unshared_plugins/

##  Export cert and config filepaths
COPY qiita_server_certificates/qiita_server_certificates.pem /qiita_server_certificates/qiita_server_certificates.pem
ENV REQUESTS_CA_BUNDLE=/qiita_server_certificates/qiita_server_certificates.pem
ENV SSL_CERT_FILE=/qiita_server_certificates/qiita_server_certificates.pem

COPY qiita_server_certificates/*_server.* /qiita_server_certificates/
RUN configure_qtp_sequencing --env-script "true" --ca-cert `find /qiita_server_certificates/ -name "*_server.crt" -type f`
RUN sed -i -E "s/^START_SCRIPT = .+/START_SCRIPT = python \/start_plugin.py qtp-sequencing/" /unshared_plugins/*.conf

# for docker compose health check
RUN mkdir -p /usr/share/man/man1 && \
    echo "deb [trusted=yes] http://archive.debian.org/debian buster main" > /etc/apt/sources.list && \
    echo "deb [trusted=yes] http://archive.debian.org/debian-security buster/updates main" >> /etc/apt/sources.list && \
    echo "deb [trusted=yes] http://archive.debian.org/debian buster-updates main" >> /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends wget && \
    rm -rf /var/lib/apt/lists/*

# for testing
COPY test_plugin.sh /test_plugin.sh

CMD ["./start_qtp-sequencing.sh"]