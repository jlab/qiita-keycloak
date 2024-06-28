FROM ubuntu:22.04

ARG MINIFORGE_VERSION=24.1.2-0
ARG MODZIP_VERSION=1.3.0
ARG NGINX_VERSION=1.26.0

ENV CONDA_DIR=/opt/conda
ENV PATH=${CONDA_DIR}/bin:${PATH}

RUN apt-get -y update
RUN apt-get -y install \
	git \
	wget \
	libpcre2-dev \
	libxslt-dev \
	libgd-dev \
	libssl-dev
RUN apt-get -y install build-essential
# install miniforge3 for "conda"
# see https://github.com/conda-forge/miniforge-images/blob/master/ubuntu/Dockerfile
RUN wget https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/Miniforge3-${MINIFORGE_VERSION}-Linux-x86_64.sh -O /tmp/miniforge3.sh && \
	/bin/bash /tmp/miniforge3.sh -b -p ${CONDA_DIR} && \
	echo ". ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate base" >> /etc/skel/.bashrc && \
	echo ". ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate base" >> ~/.bashrc \
	conda init
RUN conda create --quiet --yes -n nginx 

SHELL ["conda", "run", "-n", "nginx", "/bin/bash", "-c"]

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

COPY nginx_qiita.conf .
COPY start_nginx.sh .

RUN chmod 777 nginx_qiita.conf
RUN chmod 777 start_nginx.sh

RUN mkdir /var/log/nginx

#ENTRYPOINT ["/bin/bash",  "-l", "-c" ]
ENTRYPOINT ["conda", "run", "-n", "nginx", "./start_nginx.sh"]