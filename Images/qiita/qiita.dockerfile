# VERSION: 2025.09.09

FROM ubuntu:24.04

ARG MINIFORGE_VERSION=24.1.2-0
ARG MODZIP_VERSION=1.3.0
ARG NGINX_VERSION=1.26.0

ENV CONDA_DIR=/opt/conda
ENV PATH=${CONDA_DIR}/bin:${PATH}

RUN apt-get -y update
# install following packages for nginx compilation: libpcre2-dev, libxslt-dev and libgd-dev
RUN apt-get -y --fix-missing install \
	git \
	wget \
	libpq-dev \
	python3-dev \
	gcc \
	libpcre2-dev \
	libxslt-dev \
	libgd-dev \
	postgresql-client
RUN apt-get -y install build-essential
# install miniforge3 for "conda"
# see https://github.com/conda-forge/miniforge-images/blob/master/ubuntu/Dockerfile
RUN wget https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/Miniforge3-${MINIFORGE_VERSION}-Linux-x86_64.sh -O /tmp/miniforge3.sh && \
	/bin/bash /tmp/miniforge3.sh -b -p ${CONDA_DIR} && \
	echo ". ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate base" >> /etc/skel/.bashrc && \
	echo ". ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate base" >> ~/.bashrc \
	conda init

# create conda env for qiita with all necessary dependencies (conda and pip)
RUN conda create --quiet --yes -n qiita python=3.9 pip libgfortran numpy cython anaconda::redis
# TODO: Redis container
# Make RUN commands use the new environment:
# append --format docker to the build command, see https://github.com/containers/podman/issues/8477
SHELL ["conda", "run", "-n", "qiita", "/bin/bash", "-c"]

RUN pip install -U pip
RUN pip install \
	sphinx \
	sphinx-bootstrap-theme \
	nose-timer \
	Click \
	coverage \
	psycopg2-binary


# Clone the Qiita Repo
# RUN git clone -b master https://github.com/qiita-spots/qiita.git
RUN git clone -b auth_oidc https://github.com/jlab/qiita.git

# should tests re-populate the DB, ensure private plugin, qtp-biom and qp-target-gene use the correct conda env
RUN sed -i "s|'source /home/runner/.profile; conda activate qiita'|'source /opt/conda/etc/profile.d/conda.sh; conda activate /opt/conda/envs/qiita'|" /qiita/qiita_db/support_files/populate_test_db.sql
RUN sed -i "s|'source ~/virtualenv/python2.7/bin/activate; export PATH=\$HOME/miniconda3/bin/:\$PATH; . activate qtp-biom'|'true'|" /qiita/qiita_db/support_files/populate_test_db.sql
RUN sed -i "s|'source activate qiita'|'true'|" /qiita/qiita_db/support_files/populate_test_db.sql

# We need to install necessary dependencies
# as well as some extra dependencies for psycopg2 to work
RUN git clone https://github.com/psycopg/psycopg2.git
RUN export PATH=/usr/lib/postgresql/14.11/bin/:$PATH
RUN pip install -e psycopg2/.

# Install pip packaages for Qiita
RUN pip install -e qiita --no-binary redbiom

# A qiita configuration file is directly mounted into the qiita container via the compose file

# Copy Bash Script to run Qiita to the container. start_qiita differentiates between one "master" and multiple workers
COPY start_qiita.sh .
COPY start_qiita-initDB.sh .
RUN chmod 755 start_qiita.sh start_qiita-initDB.sh

RUN apt-get install -y curl
COPY start_plugin.py /start_plugin.py
RUN chmod a+x /start_plugin.py

# hide certificate and server configuration copy from source code
RUN rm -rf /qiita/qiita_core/support_files

# hide default configurations from github sources
RUN rm -f /qiita/qiita_pet/nginx_example.conf /qiita/qiita_pet/supervisor_example.conf /qiita/qiita_pet/support_files/config_portal.cfg

COPY drop_workflows.py /drop_workflows.py

# install aspera client for ENA submission
RUN conda install hcc::aspera-cli

# something is wired with permissions of the git repo?!
RUN git config --global --add safe.directory /qiita

# CMD ["conda", "run", "-n", "qiita"]
