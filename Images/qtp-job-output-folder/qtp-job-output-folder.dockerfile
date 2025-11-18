# VERSION: 2025.11.12

# ==========================
# Stage 1: Build wheels
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

# install tornado based trigger layer in base environment
RUN pip install -U pip

# Create conda env
RUN conda create --name qtp-job-output-folder -y python=3.6 pip==9.0.3
# Make RUN commands use the new environment:
# append --format docker to the build command, see https://github.com/containers/podman/issues/8477
SHELL ["conda", "run", "-p", "/opt/conda/envs/qtp-job-output-folder", "/bin/bash", "-c"]

RUN pip install -U pip

#RUN pip install https://github.com/qiita-spots/qiita_client/archive/master.zip
#RUN git clone -b master https://github.com/qiita-spots/qiita_client.git
RUN git clone -b refactor_exposeBaseDataDir https://github.com/jlab/qiita_client.git
RUN cd qiita_client && pip install --no-cache-dir .

# RUN pip install https://github.com/qiita-spots/qiita-files/archive/master.zip
RUN git clone -b master https://github.com/qiita-spots/qiita-files.git
RUN cd /qiita-files && pip install -e . -v

RUN git clone -b  uncouple_clientpush   https://github.com/jlab/qtp-job-output-folder.git
WORKDIR /qtp-job-output-folder
RUN sed -i "s|'qiita-files @ https://github.com/'||" setup.py
RUN sed -i "s|'qiita-spots/qiita-files/archive/master.zip',||" setup.py
RUN sed -i "s|'qiita_client @ https://github.com/'||" setup.py
RUN sed -i "s|'qiita-spots/qiita_client/archive/master.zip'||" setup.py
RUN pip install -e .

WORKDIR /
COPY requirements.txt /requirements.txt
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r /requirements.txt


# ==========================
# Stage 2: Runtime
# ==========================
FROM python:3.6-slim

# let the container know it's plugin name
ENV PLUGIN=qtp-job-output-folder

# python package compile in build stage
COPY --from=builder /wheels /wheels

RUN pip install --no-cache-dir /wheels/* \
	&& rm -rf rm -rf `find /usr/local/lib/python3.6/site-packages -type d -name "tests" | grep -v numpy`

COPY trigger_noconda.py /trigger.py

COPY start_qtp-job-output-folder.sh .
RUN chmod 755 start_qtp-job-output-folder.sh

RUN mkdir -p /unshared_plugins
ENV QIITA_PLUGINS_DIR=/unshared_plugins/

##  Export cert and config filepaths
COPY qiita_server_certificates/qiita_server_certificates.pem /qiita_server_certificates/qiita_server_certificates.pem
ENV REQUESTS_CA_BUNDLE=/qiita_server_certificates/qiita_server_certificates.pem
ENV SSL_CERT_FILE=/qiita_server_certificates/qiita_server_certificates.pem

#RUN export QIITA_ROOTCA_CERT=/unshared_certificates/ci_rootca.crt
RUN chmod u+x /usr/local/bin/configure_qtp_job_output_folder /usr/local/bin/start_qtp_job_output_folder
COPY qiita_server_certificates/*_server.* /qiita_server_certificates/
RUN configure_qtp_job_output_folder --env-script "true" --ca-cert `find /qiita_server_certificates/ -name "*_server.crt" -type f` https
RUN sed -i -E "s/^START_SCRIPT = .+/START_SCRIPT = python \/start_plugin.py qtp-job-output-folder/" /unshared_plugins/*.conf

# for testing
COPY test_plugin.sh /test_plugin.sh

CMD ["./start_qtp-job-output-folder.sh"]
