# VERSION: 2025.08.22

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
WORKDIR /qtp-biom
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
RUN echo "scikit-bio" >> req.txt
RUN echo "bp" >> req.txt
# RUN echo "flufl.lock" >> req.txt
# RUN echo "decorator" >> req.txt
# RUN echo "bibtexparser" >> req.txt
# RUN echo "tzlocal" >> req.txt
# RUN echo "dill" >> req.txt
# RUN echo "charset_normalizer==2.1.1" >> req.txt
RUN echo "biom-format" >> req.txt
RUN echo "seaborn" >> req.txt
RUN echo "jinja2" >> req.txt
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r req.txt

RUN mkdir -p /unshared_plugins
ENV QIITA_PLUGINS_DIR=/unshared_plugins/

##  Export cert and config filepaths
COPY qiita_server_certificates/qiita_server_certificates.pem /qiita_server_certificates/qiita_server_certificates.pem
# ENV REQUESTS_CA_BUNDLE=/qiita_server_certificates/qiita_server_certificates.pem
# ENV SSL_CERT_FILE=/qiita_server_certificates/qiita_server_certificates.pem

#RUN export QIITA_ROOTCA_CERT=/unshared_certificates/ci_rootca.crt
COPY qiita_server_certificates/*_server.* /qiita_server_certificates/
RUN /qtp-biom/scripts/configure_biom --env-script "true" --server-cert `find /qiita_server_certificates/ -name "*_server.crt" -type f`
RUN sed -i -E "s/^START_SCRIPT = .+/START_SCRIPT = python \/start_plugin.py qtp-biom/" /unshared_plugins/*.conf
#RUN sed -i "s|self._verify = ca_cert|self._verify = False|" /opt/conda/envs/qtp-biom/lib/python3.8/site-packages/qiita_client/qiita_client.py

ARG Q2_RELEASE=2022.11
WORKDIR /q2_src/
RUN wget "https://github.com/qiime2/q2-feature-table/archive/refs/tags/${Q2_RELEASE}.0.tar.gz" -O - | tar -xzvf -
RUN wget "https://github.com/qiime2/q2templates/archive/refs/tags/${Q2_RELEASE}.0.tar.gz" -O - | tar -xzvf -

# ==========================
# Stage 2: Runtime
# ==========================
FROM python:3.8-slim

# python package compile in build stage
COPY --from=builder /wheels /wheels
# ^^ ?? MB


RUN pip install --no-cache-dir /wheels/*
ARG Q2_RELEASE=2022.11

COPY --from=builder /q2_src/q2-feature-table-${Q2_RELEASE}.0/q2_feature_table/_summarize /q2summarize/
COPY --from=builder /q2_src/q2templates-${Q2_RELEASE}.0/q2templates/util.py /q2summarize/util.py
COPY --from=builder /q2_src/q2templates-${Q2_RELEASE}.0/q2templates/_templates.py /q2summarize/_templates.py
COPY --from=builder /q2_src/q2templates-${Q2_RELEASE}.0/q2templates/templates /q2summarize/templates/
RUN sed -i "s|from .util import|import sys; sys.path.append('/'); from q2summarize.util import|" /q2summarize/_templates.py
RUN sed -i "s|pkg_resources.resource_filename('q2templates', 'templates')|'/q2summarize/templates/'|" /q2summarize/_templates.py
RUN sed -i "s|pd.option_context('display.max_colwidth', -1)|pd.option_context('display.max_colwidth', None)|" /q2summarize/util.py
RUN sed -i "s|sample_metadata = sample_metadata.filter_ids(|df = sample_metadata.loc[[s for s in sample_frequencies.index if s in sample_metadata.index], :]|" /q2summarize/_vega_spec.py
RUN sed -i "s|^[[:space:]]*sample_frequencies.index)||" /q2summarize/_vega_spec.py
RUN sed -i "s|df = sample_metadata.to_dataframe()||" /q2summarize/_vega_spec.py
RUN echo "from ._visualizer import summarize; __all__ = ['summarize']" > /q2summarize/__init__.py

RUN apt-get -y update
RUN apt-get -y --fix-missing install patch
WORKDIR /q2summarize
COPY _visualizer.py.patch /q2summarize/
RUN patch -p1 _visualizer.py < _visualizer.py.patch
# # COPY --from=builder /q2_src/ /q2_all
COPY summary.py.patch /summary.py.patch
WORKDIR /
RUN patch -p0 < /summary.py.patch

COPY --from=builder /opt/conda/envs/qtp-biom/lib/libgomp.so.1.0.0 /lib/x86_64-linux-gnu/libgomp.so.1

# install tornado based trigger layer in base environment
RUN pip install -U --no-cache-dir tornado pip-system-certs
COPY trigger_noconda.py /trigger.py
# ^^ 848 MB

WORKDIR /

COPY start_qtp-biom.sh .
RUN chmod 755 start_qtp-biom.sh


RUN mkdir -p /unshared_plugins
ENV QIITA_PLUGINS_DIR=/unshared_plugins/

##  Export cert and config filepaths
COPY qiita_server_certificates/qiita_server_certificates.pem /qiita_server_certificates/qiita_server_certificates.pem
ENV REQUESTS_CA_BUNDLE=/qiita_server_certificates/qiita_server_certificates.pem
ENV SSL_CERT_FILE=/qiita_server_certificates/qiita_server_certificates.pem

RUN sed -i "s|^#\!.*|#\!/usr/local/bin/python|" /usr/local/bin/configure_biom
RUN sed -i "s|^#\!.*|#\!/usr/local/bin/python|" /usr/local/bin/start_biom

#RUN export QIITA_ROOTCA_CERT=/unshared_certificates/ci_rootca.crt
COPY qiita_server_certificates/*_server.* /qiita_server_certificates/
RUN /usr/local/bin/configure_biom --env-script "true" --server-cert `find /qiita_server_certificates/ -name "*_server.crt" -type f`
RUN sed -i -E "s/^START_SCRIPT = .+/START_SCRIPT = python \/start_plugin.py qtp-biom/" /unshared_plugins/*.conf

# remove conda command from tigger.py
RUN sed -i "s|source /opt/conda/etc/profile.d/conda.sh; conda activate /opt/conda/envs/%s;||" /trigger.py && sed -i "s|conda_env_name, ||" /trigger.py

CMD ["./start_qtp-biom.sh"]

#/usr/local/lib/python3.8/site-packages/qtp_biom/summary.py

# COPY 2_20250704-123139.txt /q2summarize/2_20250704-123139.txt
# COPY reference-hit.biom /q2summarize/
# RUN mkdir -p /q2summarize/test.xxx
#/usr/local/lib/python3.8/site-packages

#COPY --from=builder /opt/conda/envs/qtp-biom/lib/python3.8/site-packages/qiime2 /usr/local/lib/python3.8/site-packages/qiime2
#COPY --from=builder /opt/conda/envs/qtp-biom/lib/python3.8/site-packages/qiime2-2022.11.1-py3.8.egg-info /usr/local/lib/python3.8/site-packages/
# COPY --from=builder /opt/conda/envs/qtp-biom/lib/python3.8/site-packages/ /usr/local/lib/python3.8/site-packages/
# COPY --from=builder /opt/conda/envs/qtp-biom/lib/libopenblasp-r0.3.21.so /usr/local/lib/libopenblasp-r0.3.21.so
# COPY --from=builder /opt/conda/envs/qtp-biom/lib/libgfortran.so.5.0.0 /usr/local/lib/libgfortran.so.5
# COPY --from=builder /opt/conda/envs/qtp-biom/lib/libquadmath.so.0.0.0 /usr/local/lib/libquadmath.so.0

# RUN ln -s /usr/local/lib/libopenblasp-r0.3.21.so /usr/local/lib/libcblas.so.3
# RUN ln -s /usr/local/lib/libopenblasp-r0.3.21.so /usr/local/lib/libblas.so.3
# RUN ln -s /usr/local/lib/libopenblasp-r0.3.21.so /usr/local/lib/liblapack.so.3
# RUN ln -s /usr/local/lib/libopenblasp-r0.3.21.so /usr/local/lib/liblapacke.so.3

# COPY --from=builder /opt/conda/envs/qtp-biom/lib/libhdf5.so.103.2.0 /usr/local/lib/libhdf5.so.103
# COPY --from=builder /opt/conda/envs/qtp-biom/lib/libcrypto.so.1.1 /usr/local/lib/libcrypto.so.1.1
# COPY --from=builder /opt/conda/envs/qtp-biom/lib/libcurl.so.4.8.0 /usr/local/lib/libcurl.so.4

# COPY --from=builder /opt/conda/envs/qtp-biom/lib/libnghttp2.so.14.24.1 /usr/local/lib/libnghttp2.so.14
# COPY --from=builder /opt/conda/envs/qtp-biom/lib/libssh2.so.1.0.1 /usr/local/lib/libssh2.so.1
# COPY --from=builder /opt/conda/envs/qtp-biom/lib/libssh2.so.1.0.1 /usr/local/lib/libssh2.so.1
# COPY --from=builder /opt/conda/envs/qtp-biom/lib/libssl.so.1.1 /usr/local/lib/libssl.so.1.1
# COPY --from=builder /opt/conda/envs/qtp-biom/lib/libhdf5_hl.so.100.1.3 /usr/local/lib/libhdf5_hl.so.100 
# COPY --from=builder /opt/conda/envs/qtp-biom/lib/libjpeg.so.9.5.0 /usr/local/lib/libjpeg.so.9
# COPY --from=builder /opt/conda/envs/qtp-biom/lib/libopenjp2.so.2.5.0 /usr/local/lib/libopenjp2.so.7
# COPY --from=builder /opt/conda/envs/qtp-biom/lib/libtiff.so.5.8.0 /usr/local/lib/libtiff.so.5

# COPY --from=builder /opt/conda/envs/qtp-biom/lib/libLerc.so.4 /usr/local/lib/libLerc.so.4
# COPY --from=builder /opt/conda/envs/qtp-biom/lib/libdeflate.so.0 /usr/local/lib/libdeflate.so.0
# COPY --from=builder /opt/conda/envs/qtp-biom/lib/libfreetype.so.6.18.3 /usr/local/lib/libfreetype.so.6
# COPY --from=builder /opt/conda/envs/qtp-biom/lib/liblcms2.so.2.0.14 /usr/local/lib/iblcms2.so.2
# COPY --from=builder /opt/conda/envs/qtp-biom/lib/libwebp.so.7.1.5 /usr/local/lib/libwebp.so.7
# COPY --from=builder /opt/conda/envs/qtp-biom/lib/libwebpdemux.so.2.0.11 /usr/local/lib/libwebpdemux.so.2
# COPY --from=builder /opt/conda/envs/qtp-biom/lib/libwebpmux.so.3.0.10 /usr/local/lib/libwebpmux.so.3
# COPY --from=builder /opt/conda/envs/qtp-biom/lib/libxcb.so.1.1.0 /usr/local/lib/libxcb.so.1

# ENV REQUESTS_CA_BUNDLE=/opt/conda/lib/python3.10/site-packages/certifi/cacert.pem
# ENV SSL_CERT_FILE=/opt/conda/lib/python3.10/site-packages/certifi/cacert.pem
# RUN pip install biom-format

#libwebp.so.7 libwebpmux.so.3 libwebpdemux.so.2 liblcms2.so.2 libfreetype.so.6 libxcb.so.1 libwebp.so.7 libLerc.so.4 libdeflate.so.0

# WORKDIR /usr/local/lib/python3.8/site-packages/qtp_biom
# RUN echo 'python summary.py' > /root/.bash_history
# # # RUN pip install -U pip
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








# export REQUESTS_CA_BUNDLE=/opt/conda/lib/python3.10/site-packages/certifi/cacert.pem
# export SSL_CERT_FILE=/opt/conda/lib/python3.10/site-packages/certifi/cacert.pem
# pip install biom-format seaborn jinja2
# cd /_summarize && mkdir -p /test.xxx
# python _visualizer.py