# VERSION: 2025.08.29

FROM ubuntu:24.04 AS builder

ARG MINIFORGE_VERSION=24.1.2-0
ARG QIIME2RELEASE=2022.8

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
# RUN conda install tornado

# Download qtp-biom yaml
# RUN wget https://raw.githubusercontent.com/qiime2/distributions/refs/heads/dev/${QIIME2RELEASE}/tiny/released/qiime2-tiny-ubuntu-latest-conda.yml
RUN wget https://data.qiime2.org/distro/core/qiime2-${QIIME2RELEASE}-py38-linux-conda.yml

RUN sed -n '/channels/,/dependencies/p' qiime2-2022.8-py38-linux-conda.yml > tinyq2.yml && \
	echo "  - q2-metadata=${QIIME2RELEASE}" >> tinyq2.yml && \
	echo "  - q2-mystery-stew=${QIIME2RELEASE}" >> tinyq2.yml && \
	echo "  - q2-types=${QIIME2RELEASE}" >> tinyq2.yml && \
	echo "  - q2cli=${QIIME2RELEASE}" >> tinyq2.yml && \
	echo "  - q2templates=${QIIME2RELEASE}" >> tinyq2.yml && \
	echo "  - qiime2=${QIIME2RELEASE}" >> tinyq2.yml && \
	echo "  - q2-feature-table=${QIIME2RELEASE}" >> tinyq2.yml

# # #RUN echo "- q2-feature-table" >> qiime2-${QIIME2RELEASE}-py38-linux-conda.yml
# # #RUN sed -i "s|- conda-forge|- https://packages.qiime2.org/qiime2/${QIIME2RELEASE}/passed/core/\n- conda-forge|" qiime2-${QIIME2RELEASE}-py38-linux-conda.yml
# Create conda env
RUN conda config --set channel_priority strict && conda env create --quiet -n qtp-biom --file tinyq2.yml
# Make RUN commands use the new environment:
# append --format docker to the build command, see https://github.com/containers/podman/issues/8477
SHELL ["conda", "run", "-p", "/opt/conda/envs/qtp-biom", "/bin/bash", "-c"]

RUN pip install -U pip
# RUN pip install https://github.com/qiita-spots/qiita_client/archive/master.zip
RUN git clone -b master https://github.com/qiita-spots/qiita_client.git
RUN cd qiita_client && pip install --no-cache-dir .

# RUN pip install https://github.com/qiita-spots/qiita-files/archive/master.zip
RUN git clone -b master https://github.com/qiita-spots/qiita-files.git
# COPY ./qiita-files /qiita-files
RUN cd /qiita-files && pip install -e . -v
RUN git clone https://github.com/qiita-spots/qtp-biom.git
# COPY ./qtp-biom /qtp-biom
WORKDIR /qtp-biom
RUN sed -i "s|'qiita-files @ https://github.com/qiita-spots/'||" setup.py
RUN sed -i "s|'qiita-files/archive/master.zip',||" setup.py
RUN sed -i "s|'qiita_client @ https://github.com/qiita-spots/'||" setup.py
RUN sed -i "s|'qiita_client/archive/master.zip'||" setup.py
RUN pip install -e .
RUN pip install --upgrade certifi
RUN pip install pip-system-certs
#RUN conda install tornado

# TODO: should the plugin get the server configuration?!
RUN export QIITA_CONFIG_FP=/qiita/config_qiita_oidc.cfg

WORKDIR /

#COPY start_qtp-biom.sh .
#RUN chmod 755 start_qtp-biom.sh

#RUN mkdir -p /unshared_plugins
#ENV QIITA_PLUGINS_DIR=/unshared_plugins/

##  Export cert and config filepaths
#COPY qiita_server_certificates/qiita_server_certificates.pem /qiita_server_certificates/qiita_server_certificates.pem
#ENV REQUESTS_CA_BUNDLE=/qiita_server_certificates/qiita_server_certificates.pem
#ENV SSL_CERT_FILE=/qiita_server_certificates/qiita_server_certificates.pem

#RUN export QIITA_ROOTCA_CERT=/unshared_certificates/ci_rootca.crt
#COPY qiita_server_certificates/*_server.* /qiita_server_certificates/
#RUN /qtp-biom/scripts/configure_biom --env-script "true" --server-cert `find /qiita_server_certificates/ -name "*_server.crt" -type f`
#RUN sed -i -E "s/^START_SCRIPT = .+/START_SCRIPT = python \/start_plugin.py qtp-biom/" /unshared_plugins/*.conf

# prepare for runtime stage
# WORKDIR /
RUN pip uninstall pip-system-certs -y
RUN repo=q2-feature-table; mkdir -p /$repo && wget -O- https://github.com/qiime2/$repo/archive/refs/tags/${QIIME2RELEASE}.1.tar.gz | tar -xz --strip-components=1 -C /$repo
RUN repo=q2-metadata; mkdir -p /$repo && wget -O- https://github.com/qiime2/$repo/archive/refs/tags/${QIIME2RELEASE}.0.tar.gz | tar -xz --strip-components=1 -C /$repo
RUN repo=q2-mystery-stew; mkdir -p /$repo && wget -O- https://github.com/qiime2/$repo/archive/refs/tags/${QIIME2RELEASE}.0.tar.gz | tar -xz --strip-components=1 -C /$repo
RUN repo=q2-types; mkdir -p /$repo && wget -O- https://github.com/qiime2/$repo/archive/refs/tags/${QIIME2RELEASE}.0.tar.gz | tar -xz --strip-components=1 -C /$repo
RUN repo=q2cli; mkdir -p /$repo && wget -O- https://github.com/qiime2/$repo/archive/refs/tags/${QIIME2RELEASE}.0.tar.gz | tar -xz --strip-components=1 -C /$repo
RUN repo=q2templates; mkdir -p /$repo && wget -O- https://github.com/qiime2/$repo/archive/refs/tags/${QIIME2RELEASE}.0.tar.gz | tar -xz --strip-components=1 -C /$repo
RUN repo=qiime2; mkdir -p /$repo && wget -O- https://github.com/qiime2/$repo/archive/refs/tags/${QIIME2RELEASE}.3.tar.gz | tar -xz --strip-components=1 -C /$repo

COPY requirements.txt ./requirements.txt
RUN conda install cython
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt
RUN pip install iow

CMD ["./start_plugin.sh"]

# ==========================
# Stage 2: Runtime
# ==========================
FROM python:3.8-slim

# let the container know it's plugin name
ENV PLUGIN=qtp-biom

# python package compile in build stage
COPY --from=builder /wheels /wheels

RUN pip install --no-cache-dir /wheels/* \
	&& rm -rf rm -rf `find /usr/local/lib/python3.8/site-packages -type d -name "tests" | grep -v numpy`
# ^^ 788MB

COPY --from=builder /opt/conda/envs/qtp-biom/lib/python3.8/site-packages/bp /usr/local/lib/python3.8/site-packages/bp
RUN ln -s /usr/local/lib/python3.8/site-packages/scikit_learn.libs/libgomp-a34b3233.so.1.0.0 /lib/x86_64-linux-gnu/libgomp.so.1

# install tornado based trigger layer in base environment
#RUN pip install -U --no-cache-dir tornado
COPY trigger_noconda.py /trigger.py

WORKDIR /

COPY start_plugin.sh .
RUN chmod 755 start_plugin.sh

RUN mkdir -p /unshared_plugins
ENV QIITA_PLUGINS_DIR=/unshared_plugins/

# RUN pip install pip-system-certs

#RUN sed -i "s|^#\!.*|#\!/usr/local/bin/python|" /usr/local/bin/configure_biom
#RUN sed -i "s|^#\!.*|#\!/usr/local/bin/python|" /usr/local/bin/start_biom

# use git branch instead of pypi version (stored via wheel)
#COPY --from=builder /qiita_client /qiita_client
#RUN cd qiita_client && pip install .

##  Export cert and config filepaths
COPY qiita_server_certificates/qiita_server_certificates.pem /qiita_server_certificates/qiita_server_certificates.pem
ENV REQUESTS_CA_BUNDLE=/qiita_server_certificates/qiita_server_certificates.pem
ENV SSL_CERT_FILE=/qiita_server_certificates/qiita_server_certificates.pem

#RUN mkdir -p /qiita_server_certificates/
COPY qiita_server_certificates/*_server.* /qiita_server_certificates/
RUN configure_biom --env-script "true" --server-cert `find /qiita_server_certificates/ -name "*_server.crt" -type f`
RUN sed -i -E "s/^START_SCRIPT = .+/START_SCRIPT = python \/start_plugin.py qtp-biom/" /unshared_plugins/*.conf

# fix an pandas deprecation issue, i.e. patch q2templates code
RUN sed -i "s/'display.max_colwidth', -1/'display.max_colwidth', None/" /usr/local/lib/python3.8/site-packages/q2templates/util.py

# remove conda command from tigger.py
# RUN sed -i "s|source /opt/conda/etc/profile.d/conda.sh; conda activate /opt/conda/envs/%s;||" /trigger.py && sed -i "s|conda_env_name, ||" /trigger.py

# for testing
COPY test_plugin.sh /test_plugin.sh

CMD ["./start_plugin.sh"]

# python -c "import qiime2.plugins.feature_table"