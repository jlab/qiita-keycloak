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

# Download qtp-biom yaml
RUN wget https://data.qiime2.org/distro/core/qiime2-2022.11-py38-linux-conda.yml

# Create conda env
RUN conda env create --quiet -n qtp-biom --file qiime2-2022.11-py38-linux-conda.yml
# Make RUN commands use the new environment:
# append --format docker to the build command, see https://github.com/containers/podman/issues/8477
SHELL ["conda", "run", "-p", "/opt/conda/envs/qtp-biom", "/bin/bash", "-c"]

WORKDIR /
RUN git clone https://github.com/qiita-spots/qiita_client.git
WORKDIR qiita_client
RUN pip install .

WORKDIR /
RUN git clone https://github.com/qiita-spots/qiita-files.git
WORKDIR qiita-files
RUN pip install .

WORKDIR /
RUN git clone https://github.com/qiita-spots/qtp-biom.git
WORKDIR qtp-biom
RUN sed -i "s|, 'qiime2', |, |" setup.py
RUN sed -i "s|'qiita-files @ https://github.com/qiita-spots/'||" setup.py
RUN sed -i "s|'qiita-files/archive/master.zip',||" setup.py
RUN sed -i "s|'qiita_client @ https://github.com/qiita-spots/'||" setup.py
RUN sed -i "s|'qiita_client/archive/master.zip'||" setup.py
RUN sed -i "s|^import qiime2$|import qiime2.metadata|" qtp_biom/summary.py

RUN pip install -e .
RUN pip install --upgrade certifi
RUN pip install pip-system-certs

RUN echo "-e /qiita_client" > req.txt
RUN echo "-e /qiita-files" >> req.txt
RUN echo "-e /qtp-biom" >> req.txt
RUN echo "pyyaml" >> req.txt
RUN echo "psutil" >> req.txt
RUN echo "flufl.lock" >> req.txt
RUN echo "decorator" >> req.txt
RUN echo "bibtexparser" >> req.txt
RUN echo "tzlocal" >> req.txt
RUN echo "dill" >> req.txt
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r req.txt

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
RUN sed -i "s|self._verify = ca_cert|self._verify = False|" /opt/conda/envs/qtp-biom/lib/python3.8/site-packages/qiita_client/qiita_client.py

# ==========================
# Stage 2: Runtime
# ==========================
FROM python:3.8-slim

# python package compile in build stage
COPY --from=builder /wheels /wheels
# ^^ ?? MB

RUN pip install --no-cache-dir /wheels/*

#COPY --from=builder /opt/conda/envs/qtp-biom/lib/python3.8/site-packages/qiime2 /usr/local/lib/python3.8/site-packages/qiime2
#COPY --from=builder /opt/conda/envs/qtp-biom/lib/python3.8/site-packages/qiime2-2022.11.1-py3.8.egg-info /usr/local/lib/python3.8/site-packages/
COPY --from=builder /opt/conda/envs/qtp-biom/lib/python3.8/site-packages/ /usr/local/lib/python3.8/site-packages/
COPY --from=builder /opt/conda/envs/qtp-biom/lib/libopenblasp-r0.3.21.so /usr/local/lib/libopenblasp-r0.3.21.so
COPY --from=builder /opt/conda/envs/qtp-biom/lib/libgfortran.so.5.0.0 /usr/local/lib/libgfortran.so.5
COPY --from=builder /opt/conda/envs/qtp-biom/lib/libquadmath.so.0.0.0 /usr/local/lib/libquadmath.so.0

RUN ln -s /usr/local/lib/libopenblasp-r0.3.21.so /usr/local/lib/libcblas.so.3
RUN ln -s /usr/local/lib/libopenblasp-r0.3.21.so /usr/local/lib/libblas.so.3
RUN ln -s /usr/local/lib/libopenblasp-r0.3.21.so /usr/local/lib/liblapack.so.3
RUN ln -s /usr/local/lib/libopenblasp-r0.3.21.so /usr/local/lib/liblapacke.so.3

# # RUN pip install -U pip
# # RUN conda install tornado
# # COPY trigger.py /trigger.py


# # COPY start_qtp-biom.sh .
# # RUN chmod 755 start_qtp-biom.sh

# # RUN mkdir -p /unshared_plugins
# # ENV QIITA_PLUGINS_DIR=/unshared_plugins/

# # ##  Export cert and config filepaths
# # COPY Certificates /unshared_certificates
# # RUN cat /unshared_certificates/stefan_rootca.crt >> `python -c "import certifi; print(certifi.where())"`  # append own rootCA onto chain of trust
# # RUN export REQUESTS_CA_BUNDLE=`python -c "import certifi; print(certifi.where())"`
# # RUN export SSL_CERT_FILE=`python -c "import certifi; print(certifi.where())"`

# # #RUN export QIITA_ROOTCA_CERT=/unshared_certificates/ci_rootca.crt
# # RUN /qtp-biom/scripts/configure_biom --env-script "true" --server-cert /unshared_certificates/stefan_server.crt
# # RUN sed -i -E "s/^START_SCRIPT = .+/START_SCRIPT = python \/start_plugin.py qtp-biom/" /unshared_plugins/*.conf

# # CMD ["./start_qtp-biom.sh"]
