FROM ubuntu:24.04 AS builder

ARG MINIFORGE_VERSION=24.1.2-0
ARG QIIME2RELEASE=2022.11

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
RUN conda install tornado
COPY trigger.py /trigger.py

# Download qiime2 yaml
RUN wget -q https://data.qiime2.org/distro/core/qiime2-${QIIME2RELEASE}-py38-linux-conda.yml

RUN sed -n '/channels/,/dependencies/p' qiime2-${QIIME2RELEASE}-py38-linux-conda.yml > tinyq2.yml && \
	echo "  - q2-metadata=${QIIME2RELEASE}" >> tinyq2.yml && \
	echo "  - q2-mystery-stew=${QIIME2RELEASE}" >> tinyq2.yml && \
	echo "  - q2-types=${QIIME2RELEASE}" >> tinyq2.yml && \
	echo "  - q2-diversity=${QIIME2RELEASE}" >> tinyq2.yml && \
	echo "  - q2-diversity-lib=${QIIME2RELEASE}" >> tinyq2.yml && \
	echo "  - q2cli=${QIIME2RELEASE}" >> tinyq2.yml && \
	echo "  - q2templates=${QIIME2RELEASE}" >> tinyq2.yml && \
	echo "  - q2-taxa=${QIIME2RELEASE}" >> tinyq2.yml && \
	echo "  - typeguard=2.13.3" >> tinyq2.yml && \
#	echo "  - unifrac-binaries=1.1.1" >> tinyq2.yml && \
	echo "  - qiime2" >> tinyq2.yml

# Create conda env
RUN conda config --set channel_priority strict && conda env create --name qiime2 -y --file tinyq2.yml
# Make RUN commands use the new environment:
# append --format docker to the build command, see https://github.com/containers/podman/issues/8477
SHELL ["conda", "run", "-p", "/opt/conda/envs/qiime2", "/bin/bash", "-c"]

RUN pip install -U pip
# RUN pip install https://github.com/qiita-spots/qiita_client/archive/master.zip
RUN git clone -b master https://github.com/qiita-spots/qiita_client.git
RUN cd qiita_client && pip install --no-cache-dir .

# RUN pip install https://github.com/qiita-spots/qiita-files/archive/master.zip
RUN git clone -b master https://github.com/qiita-spots/qiita-files.git
RUN cd /qiita-files && pip install -e . -v

RUN pip install https://github.com/biocore/q2-mislabeled/archive/refs/heads/main.zip
RUN git clone https://github.com/qiita-spots/qtp-diversity.git
WORKDIR /qtp-diversity
RUN sed -i "s|'qiita-files @ https://github.com/'||" setup.py
RUN sed -i "s|'qiita-spots/qiita-files/archive/master.zip',||" setup.py
RUN sed -i "s|'qiita_client @ https://github.com/qiita-spots/'||" setup.py
RUN sed -i "s|'qiita_client/archive/master.zip'||" setup.py
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
RUN repo=q2-taxa; mkdir -p /$repo && wget -O- https://github.com/qiime2/$repo/archive/refs/tags/${QIIME2RELEASE}.0.tar.gz | tar -xz --strip-components=1 -C /$repo
RUN repo=q2-diversity; mkdir -p /$repo && wget -O- https://github.com/qiime2/$repo/archive/refs/tags/${QIIME2RELEASE}.1.tar.gz | tar -xz --strip-components=1 -C /$repo
RUN repo=q2-diversity-lib; mkdir -p /$repo && wget -O- https://github.com/qiime2/$repo/archive/refs/tags/${QIIME2RELEASE}.0.tar.gz | tar -xz --strip-components=1 -C /$repo

RUN repo=unifrac; mkdir -p /$repo && wget -O- https://github.com/biocore/unifrac/archive/refs/tags/1.1.1.tar.gz | tar -xz --strip-components=1 -C /$repo

COPY requirements.txt ./requirements.txt
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt

RUN sed -n '/channels/,/dependencies/p' qiime2-${QIIME2RELEASE}-py38-linux-conda.yml > deps.yml && \
	echo "  - umap-learn" >> deps.yml && \
	echo "  - unifrac=1.1.1" >> deps.yml && \
	echo "  - unifrac-binaries=1.1.1" >> deps.yml && \
	echo "  - qiime2" >> deps.yml

# Create conda env
RUN conda config --set channel_priority strict && conda env create --name dependencies -y --file deps.yml

# ==========================
# Stage 2: Runtime
# ==========================
FROM python:3.8-slim

# python package compile in build stage
COPY --from=builder /wheels /wheels

RUN pip install --no-cache-dir /wheels/* \
	&& rm -rf rm -rf `find /usr/local/lib/python3.8/site-packages -type d -name "tests" | grep -v numpy`

COPY start_qtp-diversity.sh .
RUN chmod 755 start_qtp-diversity.sh

RUN mkdir -p /unshared_plugins
ENV QIITA_PLUGINS_DIR=/unshared_plugins/

COPY --from=builder /opt/conda/envs/dependencies/bin/* /opt/conda/bin/
COPY --from=builder /opt/conda/envs/dependencies/sbin/* /opt/conda/sbin/
COPY --from=builder /opt/conda/envs/dependencies/lib/* /opt/conda/lib/
COPY --from=builder /opt/conda/envs/dependencies/x86_64-conda-linux-gnu/* /opt/conda/x86_64-conda-linux-gnu/
ENV PATH=$PATH:/opt/conda/bin:/opt/conda/sbin
# RUN for d in `echo bin lib sbin x86_64-conda-linux-gnu`; do cp -r /dep_conda/$d/* /usr/local/$d/; done

RUN ln -s /usr/local/lib/python3.8/site-packages/scikit_learn.libs/libgomp-a34b3233.so.1.0.0 /lib/x86_64-linux-gnu/libgomp.so.1

# # everything for unifrac
# # COPY --from=builder /opt/conda/envs/qiime2/bin/ssu /usr/local/bin/ssu
# # COPY --from=builder /opt/conda/envs/qiime2/bin/faithpd /usr/local/bin/faithpd
# # COPY --from=builder /opt/conda/envs/qiime2/lib/libssu.so                 /usr/local/lib/libssu.so
# # COPY --from=builder /opt/conda/envs/qiime2/lib/libopenblasp-r0.3.25.so   /usr/local/lib/libopenblasp-r0.3.25.so
# # COPY --from=builder /opt/conda/envs/qiime2/lib/libhdf5_hl_cpp.so.100.1.4 /usr/local/lib/libhdf5_hl_cpp.so.100
# # COPY --from=builder /opt/conda/envs/qiime2/lib/libhdf5_hl.so.100.1.3     /usr/local/lib/libhdf5_hl.so.100
# # COPY --from=builder /opt/conda/envs/qiime2/lib/libhdf5.so.103.2.0        /usr/local/lib/libhdf5.so.103
# # COPY --from=builder /opt/conda/envs/qiime2/lib/libgfortran.so.5.0.0      /usr/local/lib/libgfortran.so.5
# # COPY --from=builder /opt/conda/envs/qiime2/lib/libquadmath.so.0.0.0      /usr/local/lib/libquadmath.so.0
# # COPY --from=builder /opt/conda/envs/qiime2/lib/libhdf5_cpp.so.103.2.0    /usr/local/lib/libhdf5_cpp.so.103
# # COPY --from=builder /opt/conda/envs/qiime2/lib/libhdf5_hl_cpp.so.100.1.4 /usr/local/lib/libhdf5_hl_cpp.so.100
# # COPY --from=builder /opt/conda/envs/qiime2/lib/libhdf5_hl.so.100.1.3     /usr/local/lib/libhdf5_hl.so.100
# # COPY --from=builder /opt/conda/envs/qiime2/lib/libhdf5.so.103.2.0        /usr/local/lib/libhdf5.so.103
# # COPY --from=builder /opt/conda/envs/qiime2/lib/libcrypto.so.1.1          /usr/local/lib/libcrypto.so.1.1
# # COPY --from=builder /opt/conda/envs/qiime2/lib/libcurl.so.4.8.0          /usr/local/lib/libcurl.so.4
# # COPY --from=builder /opt/conda/envs/qiime2/lib/libnghttp2.so.14.24.1     /usr/local/lib/libnghttp2.so.14
# # COPY --from=builder /opt/conda/envs/qiime2/lib/libssh2.so.1.0.1          /usr/local/lib/libssh2.so.1
# # COPY --from=builder /opt/conda/envs/qiime2/lib/libssl.so.1.1             /usr/local/lib/libssl.so.1.1
# # RUN ln -s /usr/local/lib/libopenblasp-r0.3.25.so /usr/local/lib/libcblas.so.3
# # RUN ln -s /usr/local/lib/libopenblasp-r0.3.25.so /usr/local/lib/liblapacke.so.3
# # RUN for f in `echo "libssu.so libhdf5_cpp.so.103 liblapacke.so.3 libcblas.so.3 libhdf5_hl_cpp.so.100 libhdf5_hl.so.100 libhdf5.so.103 libcrypto.so.1.1 libcurl.so.4 libgfortran.so.5 libnghttp2.so.14 libssh2.so.1 libssl.so.1.1 libquadmath.so.0"`; do ln -s /usr/local/lib/$f /lib/x86_64-linux-gnu/$f; done

# # COPY trigger_noconda.py /trigger.py
# # ENV LC_ALL=C.UTF-8
# # ENV LANG=C.UTF-8

# # ##  Export cert and config filepaths
# # COPY qiita_server_certificates/qiita_server_certificates.pem /qiita_server_certificates/qiita_server_certificates.pem
# # ENV REQUESTS_CA_BUNDLE=/qiita_server_certificates/qiita_server_certificates.pem
# # ENV SSL_CERT_FILE=/qiita_server_certificates/qiita_server_certificates.pem

# # #RUN export QIITA_ROOTCA_CERT=/unshared_certificates/ci_rootca.crt
# # RUN chmod u+x /usr/local/bin/configure_diversity_types /usr/local/bin/start_diversity_types
# # COPY qiita_server_certificates/*_server.* /qiita_server_certificates/
# # RUN configure_diversity_types --env-script "true" --ca-cert `find /qiita_server_certificates/ -name "*_server.crt" -type f`
# # RUN sed -i -E "s/^START_SCRIPT = .+/START_SCRIPT = python \/start_plugin.py qtp-diversity/" /unshared_plugins/*.conf

# # CMD ["./start_qtp-diversity.sh"]

