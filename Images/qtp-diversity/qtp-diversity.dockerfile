# VERSION: 2026.04.12

# variables, specifically for this plugin
# qiita plugin name
ARG PLUGIN=qtp-diversity

# variables, identical for whole qiita setup
ARG QIITA_PLUGINS_DIR=/unshared_plugins
ARG QIITA_CERT_DIR=/qiita_server_certificates

# for clear dockerfile
ARG CONDA_DIR=/opt/conda

# ==========================
# Stage 1: Build wheels
# ==========================
FROM ubuntu:24.04 AS builder
ARG PLUGIN
ARG QIITA_PLUGINS_DIR
ARG QIITA_CERT_DIR
ARG CONDA_DIR
ARG QIIME2RELEASE=2022.11

ARG MINIFORGE_VERSION=24.1.2-0
ENV PATH=${CONDA_DIR}/bin:${PATH}

RUN apt-get -y update && \
	apt-get -y --fix-missing install \
		git \
		wget \
		libpq-dev \
		python3-dev \
		gcc \
		build-essential \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*

# install miniforge3 for "conda"
# see https://github.com/conda-forge/miniforge-images/blob/master/ubuntu/Dockerfile
RUN wget --no-verbose https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/Miniforge3-${MINIFORGE_VERSION}-Linux-x86_64.sh -O /tmp/miniforge3.sh && \
	/bin/bash /tmp/miniforge3.sh -b -p ${CONDA_DIR} && \
	echo ". ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate base" >> /etc/skel/.bashrc && \
	echo ". ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate base" >> ~/.bashrc && \
	conda init && \
	rm -f /tmp/miniforge3.sh

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
	echo "  - unifrac-binaries=1.1.1" >> tinyq2.yml && \
	echo "  - qiime2" >> tinyq2.yml

# Create conda env
RUN conda config --set channel_priority strict && conda env create --name ${PLUGIN} -y --file tinyq2.yml
# Make RUN commands use the new environment:
# append --format docker to the build command, see https://github.com/containers/podman/issues/8477
SHELL ["conda", "run", "-p", "${CONDA_DIR}/envs/${PLUGIN}", "/bin/bash", "-c"]

# Install qiita_client
# RUN pip install https://github.com/qiita-spots/qiita_client/archive/master.zip
RUN pip install -U pip && \
	git clone -b master https://github.com/qiita-spots/qiita_client.git && \
	cd qiita_client && \
	pip install --no-cache-dir .

# Install qiita-files
# RUN pip install https://github.com/qiita-spots/qiita-files/archive/master.zip
RUN git clone -b master https://github.com/qiita-spots/qiita-files.git && \
	cd /qiita-files && \
	pip install -e . -v

# Install qiita plugin
#RUN pip install https://github.com/biocore/q2-mislabeled/archive/refs/heads/main.zip
RUN git clone -b master https://github.com/qiita-spots/${PLUGIN}.git /${PLUGIN}
WORKDIR /${PLUGIN}
RUN sed -i "s|'qiita-files @ https://github.com/'||" setup.py && \
	sed -i "s|'qiita-spots/qiita-files/archive/master.zip',||" setup.py && \
	sed -i "s|'qiita_client @ https://github.com/qiita-spots/'||" setup.py && \
	sed -i "s|'qiita_client/archive/master.zip'||" setup.py && \
	pip install -e . && \
	pip install --upgrade certifi && \
	pip install pip-system-certs

WORKDIR /

RUN repo=q2-metadata; mkdir -p /$repo && wget -O- https://github.com/qiime2/$repo/archive/refs/tags/${QIIME2RELEASE}.0.tar.gz | tar -xz --strip-components=1 -C /$repo && \
	repo=q2-mystery-stew; mkdir -p /$repo && wget -O- https://github.com/qiime2/$repo/archive/refs/tags/${QIIME2RELEASE}.0.tar.gz | tar -xz --strip-components=1 -C /$repo && \
	repo=q2-types; mkdir -p /$repo && wget -O- https://github.com/qiime2/$repo/archive/refs/tags/${QIIME2RELEASE}.0.tar.gz | tar -xz --strip-components=1 -C /$repo && \
	repo=q2cli; mkdir -p /$repo && wget -O- https://github.com/qiime2/$repo/archive/refs/tags/${QIIME2RELEASE}.1.tar.gz | tar -xz --strip-components=1 -C /$repo && \
	repo=q2templates; mkdir -p /$repo && wget -O- https://github.com/qiime2/$repo/archive/refs/tags/${QIIME2RELEASE}.0.tar.gz | tar -xz --strip-components=1 -C /$repo && \
	repo=qiime2; mkdir -p /$repo && wget -O- https://github.com/qiime2/$repo/archive/refs/tags/${QIIME2RELEASE}.1.tar.gz | tar -xz --strip-components=1 -C /$repo && \
	repo=q2-taxa; mkdir -p /$repo && wget -O- https://github.com/qiime2/$repo/archive/refs/tags/${QIIME2RELEASE}.0.tar.gz | tar -xz --strip-components=1 -C /$repo && \
	repo=q2-diversity; mkdir -p /$repo && wget -O- https://github.com/qiime2/$repo/archive/refs/tags/${QIIME2RELEASE}.1.tar.gz | tar -xz --strip-components=1 -C /$repo && \
	repo=q2-diversity-lib; mkdir -p /$repo && wget -O- https://github.com/qiime2/$repo/archive/refs/tags/${QIIME2RELEASE}.0.tar.gz | tar -xz --strip-components=1 -C /$repo && \
	repo=unifrac; mkdir -p /$repo && wget -O- https://github.com/biocore/unifrac/archive/refs/tags/1.1.1.tar.gz | tar -xz --strip-components=1 -C /$repo

# the below one is huge as it installs sourece tracker as dependencies. I think (smj 2025-09-09) that we "just" need the type definition for the CI tests of qtp-diversity. Thus, patch dependency away
RUN repo=q2-mislabeld; mkdir -p /$repo && wget -O- https://github.com/biocore/q2-mislabeled/archive/refs/tags/2023.2.tar.gz | tar -xz --strip-components=1 -C /$repo && cd /$repo && sed -i "s|'sourcetracker @ https://github.com/'||" setup.py && sed -i "s|'wasade/sourcetracker2/archive/be_sparse.zip'||" setup.py && pip install -e .

COPY requirements.txt ./requirements.txt
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt

RUN cd ${CONDA_DIR}/envs/${PLUGIN}/lib/python3.8/site-packages/q2_diversity/ && \
	tar czvf /q2_diversity_assets.tgz _beta/adonis_assets _beta/beta_rarefaction_assets _beta/mantel_assets _beta/beta_group_significance_assets _alpha/alpha_group_significance_assets _alpha/alpha_correlation_assets _alpha/alpha_rarefaction_assets 


# ==========================
# Stage 2: Runtime
# ==========================
FROM python:3.8-slim
ARG PLUGIN
ARG QIITA_PLUGINS_DIR
ARG QIITA_CERT_DIR
ARG CONDA_DIR

# let the container know it's plugin name
ENV PLUGIN=${PLUGIN}

RUN --mount=type=bind,from=builder,source=/wheels,target=/wheels \
	pip install --no-cache-dir /wheels/* \
	&& rm -rf rm -rf `find /usr/local/lib/python3.8/site-packages -type d -name "tests" | grep -v numpy` \
	# for smaller docker container: strip *.so libraries
	&& apt-get update && apt-get install binutils -y --no-install-recommends \
	&& find /usr/local/lib/python3.8/site-packages -name "*.so" -exec strip --strip-unneeded {} + || true \
	&& apt-get purge -y binutils && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*


RUN ln -s /usr/local/lib/python3.8/site-packages/scikit_learn.libs/libgomp-a34b3233.so.1.0.0 /lib/x86_64-linux-gnu/libgomp.so.1

# everything for unifrac
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/bin/ssu /usr/local/bin/ssu
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/bin/faithpd /usr/local/bin/faithpd
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libssu.so                 /usr/local/lib/libssu.so
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libopenblasp-r0.3.25.so   /usr/local/lib/libopenblasp-r0.3.25.so
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libhdf5_hl_cpp.so.100.1.4 /usr/local/lib/libhdf5_hl_cpp.so.100
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libhdf5_hl.so.100.1.3     /usr/local/lib/libhdf5_hl.so.100
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libhdf5.so.103.2.0        /usr/local/lib/libhdf5.so.103
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libgfortran.so.5.0.0      /usr/local/lib/libgfortran.so.5
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libquadmath.so.0.0.0      /usr/local/lib/libquadmath.so.0
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libhdf5_cpp.so.103.2.0    /usr/local/lib/libhdf5_cpp.so.103
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libhdf5_hl_cpp.so.100.1.4 /usr/local/lib/libhdf5_hl_cpp.so.100
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libhdf5_hl.so.100.1.3     /usr/local/lib/libhdf5_hl.so.100
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libhdf5.so.103.2.0        /usr/local/lib/libhdf5.so.103
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libcrypto.so*             /usr/local/lib/
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libcurl.so.4.8.0          /usr/local/lib/libcurl.so.4
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libnghttp2.so.*           /usr/local/lib/
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libssh2.so.1.0.1          /usr/local/lib/libssh2.so.1
COPY --from=builder ${CONDA_DIR}/envs/${PLUGIN}/lib/libssl.so*                /usr/local/lib/
RUN ln -s /usr/local/lib/libopenblasp-r0.3.25.so /usr/local/lib/libcblas.so.3 && \
	ln -s /usr/local/lib/libopenblasp-r0.3.25.so /usr/local/lib/liblapacke.so.3 && \
	for f in `echo "libssu.so libhdf5_cpp.so.103 liblapacke.so.3 libcblas.so.3 libhdf5_hl_cpp.so.100 libhdf5_hl.so.100 libhdf5.so.103 libcrypto.so.1.1 libcurl.so.4 libgfortran.so.5 libnghttp2.so.14 libssh2.so.1 libssl.so.1.1 libquadmath.so.0"`; do ln -s /usr/local/lib/$f /lib/x86_64-linux-gnu/$f; done

# fix an pandas deprecation issue, i.e. patch q2templates code
RUN sed -i "s/'display.max_colwidth', -1/'display.max_colwidth', None/" /usr/local/lib/python3.8/site-packages/q2templates/util.py

ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

# initialize qiim2
RUN qiime

# copy qiime2 diversity assets
COPY --from=builder /q2_diversity_assets.tgz /usr/local/lib/python3.8/site-packages/q2_diversity/q2_diversity_assets.tgz
RUN cd /usr/local/lib/python3.8/site-packages/q2_diversity && tar xzvf q2_diversity_assets.tgz

# Handling of certificates, such that plugin can verify qiita main
RUN mkdir -p ${QIITA_CERT_DIR}/
COPY Certificates/tinqiita/*_server* ${QIITA_CERT_DIR}/
ENV REQUESTS_CA_BUNDLE=${QIITA_CERT_DIR}/tinqiita_server_certificates.pem
ENV SSL_CERT_FILE=${QIITA_CERT_DIR}/tinqiita_server_certificates.pem

# setup qiita plugin
ENV QIITA_PLUGINS_DIR=${QIITA_PLUGINS_DIR}
RUN mkdir -p ${QIITA_PLUGINS_DIR}/ && \
	chmod u+x /usr/local/bin/configure_diversity_types && \
	chmod u+x /usr/local/bin/start_diversity_types && \
	ln -s /usr/local/bin/configure_diversity_types /usr/local/bin/configure_${PLUGIN} && \
	ln -s /usr/local/bin/start_diversity_types /usr/local/bin/start_${PLUGIN} && \
	configure_${PLUGIN} --env-script "true" --ca-cert `find ${QIITA_CERT_DIR}/ -name "*_server.crt" -type f` https && \
	sed -i -E "s/^START_SCRIPT = .+/START_SCRIPT = python \/start_plugin.py ${PLUGIN}/" ${QIITA_PLUGINS_DIR}/*.conf

# copy http listener
COPY trigger.py /trigger.py

# for job execution
COPY start_plugin.sh .

# for testing
COPY test_plugin.sh /test_plugin.sh

# for reference, if user wants to inspect image
COPY *.dockerfile /

CMD ["./start_plugin.sh"]
