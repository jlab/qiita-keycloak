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
	libgd-dev
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
	
# manually compile nginx to enable mod_zip
RUN wget https://github.com/evanmiller/mod_zip/archive/refs/tags/${MODZIP_VERSION}.tar.gz -O /usr/local/src/mod_zip-${MODZIP_VERSION}.tar.gz
RUN cd /usr/local/src/ && tar xzvf mod_zip-${MODZIP_VERSION}.tar.gz
RUN wget https://github.com/nginx/nginx/archive/refs/tags/release-${NGINX_VERSION}.tar.gz -O /usr/local/src/nginx-${NGINX_VERSION}.tar.gz
RUN cd /usr/local/src/ && tar xzvf nginx-${NGINX_VERSION}.tar.gz
# fix include for the iconv header
RUN sed "s|^#include <iconv.h>|#include \"/usr/include/iconv.h\"|" -i /usr/local/src/mod_zip-${MODZIP_VERSION}/ngx_http_zip_file.c
# ensure runtime library paths are correct and openssl headers can be found at compile time
RUN cd /usr/local/src/nginx-release-${NGINX_VERSION} && ./auto/configure \
	--http-log-path=var/log/nginx/access.log \
	--error-log-path=var/log/nginx/error.log \
	--pid-path=var/run/nginx/nginx.pid \
	--lock-path=var/run/nginx/nginx.lock \
	--http-client-body-temp-path=var/tmp/nginx/client \
	--http-proxy-temp-path=var/tmp/nginx/proxy \
	--http-fastcgi-temp-path=var/tmp/nginx/fastcgi \
	--http-scgi-temp-path=var/tmp/nginx/scgi \
	--http-uwsgi-temp-path=var/tmp/nginx/uwsgi \
	--sbin-path=sbin/nginx \
	--conf-path=etc/nginx/nginx.conf \
	--modules-path=lib/nginx/modules \
	--with-threads \
	--with-http_ssl_module \
	--with-http_v2_module \
	--with-http_realip_module \
	--with-http_addition_module \
	--with-http_sub_module \
	--with-http_gunzip_module \
	--with-http_gzip_static_module \
	--with-http_auth_request_module \
	--with-http_secure_link_module \
	--with-http_stub_status_module \
	--with-http_xslt_module=dynamic \
	--with-stream=dynamic \
	--with-http_image_filter_module=dynamic \
	--with-pcre \
	--with-pcre-jit \
	--with-cc-opt=" -I $CONDA_DIR/envs/qiita/include/openssl " \
	--with-ld-opt="" \
	--prefix=/usr/local \
	--add-module=/usr/local/src/mod_zip-${MODZIP_VERSION} \
	--with-ld-opt=" -Wl,-rpath,$CONDA_DIR/envs/qiita/lib "
RUN cd /usr/local/src/nginx-release-${NGINX_VERSION} && make
RUN cd /usr/local/src/nginx-release-${NGINX_VERSION} && make install

#cClone the Qiita Repo
# RUN git clone -b master https://github.com/qiita-spots/qiita.git
RUN git clone -b auth_oidc https://github.com/jlab/qiita.git

# We need to install necessary dependencies
# as well as some extra dependencies for psycopg2 to work
RUN git clone https://github.com/psycopg/psycopg2.git
RUN export PATH=/usr/lib/postgresql/14.11/bin/:$PATH
RUN pip install -e psycopg2/.

# Install pip packaages for Qiita
RUN pip install -e qiita --no-binary redbiom


# Copy modified config file to the container
COPY config_qiita_oidc.cfg /qiita/
RUN chmod 755 /qiita/config_qiita_oidc.cfg

# Copy Bash Script to run Qiita to the container
COPY start_qiita.sh .
RUN chmod 755 start_qiita.sh

COPY supervisor_foreground.conf .
RUN chmod 755 supervisor_foreground.conf

# I will leave this ENTRYPOINT here as a comment in case debugging
# is necessary
# SHELL ["/bin/bash"]
ENTRYPOINT ["conda", "run", "-n", "qiita", "./start_qiita.sh"]