# VERSION: 2026.04.08

# variables, specifically for this plugin
# qiita plugin name
ARG PLUGIN=qp-woltka

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

# config for conda within plugin image
ARG MINIFORGE_VERSION=24.1.2-0
ENV PATH=${CONDA_DIR}/bin:${PATH}

ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

RUN apt-get -y update && \
	apt-get -y --fix-missing install \
		git \
		wget \
		python3-dev \
 		build-essential \
		parallel \
		cmake \
		zlib1g-dev \
        libtbb-dev \
		zip unzip \
		xz-utils \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*

ARG SEQKIT_VERSION=2.8.2
RUN cd / \
	&& wget https://github.com/BenLangmead/bowtie2/releases/download/v2.5.0/bowtie2-2.5.0-linux-x86_64.zip \
    && unzip bowtie2-2.5.0-linux-x86_64.zip \
    && wget -q https://github.com/shenwei356/seqkit/releases/download/v${SEQKIT_VERSION}/seqkit_linux_amd64.tar.gz \
    && tar -xzf seqkit_linux_amd64.tar.gz -C /usr/local/bin/ seqkit \
    && rm seqkit_linux_amd64.tar.gz

# install miniforge3 for "conda"
# see https://github.com/conda-forge/miniforge-images/blob/master/ubuntu/Dockerfile
RUN wget --no-verbose https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/Miniforge3-${MINIFORGE_VERSION}-Linux-x86_64.sh -O /tmp/miniforge3.sh && \
	/bin/bash /tmp/miniforge3.sh -b -p ${CONDA_DIR} && \
	echo ". ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate base" >> /etc/skel/.bashrc && \
	echo ". ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate base" >> ~/.bashrc && \
	conda init && \
	rm -f /tmp/miniforge3.sh

# Create conda env
RUN conda create --quiet -n ${PLUGIN} -c conda-forge -c bioconda python=3.9 biom-format bowtie2==2.5.0 seqkit
# Make RUN commands use the new environment:
# append --format docker to the build command, see https://github.com/containers/podman/issues/8477
SHELL ["conda", "run", "-p", "${CONDA_DIR}/envs/${PLUGIN}", "/bin/bash", "-c"]

# Install qiita_client
RUN git clone -b refactor_chunked_filepush_v2 https://github.com/jlab/qiita_client.git && \
	cd qiita_client && \
	pip install --no-cache-dir .

RUN git clone https://github.com/wasade/mxdx.git /mxdx \
	&& cd /mxdx \
	&& pip install .

RUN git clone https://github.com/AmandaBirmingham/pysyndna.git /pysyndna \
	&& cd /pysyndna \
	&& pip install .

# Install woltka (not the plugin)
RUN git clone --depth 1 -b v0.1.7 https://github.com/qiyunzhu/woltka.git /woltka \
	&& cd /woltka \
	&& rm -rf woltka/q2/tests woltka/tests \
	&& pip install .

RUN git clone https://github.com/biocore/micov.git /micov \
	&& cd /micov \
	&& pip install .

# Install qiita plugin
RUN git clone -b main https://github.com/qiita-spots/${PLUGIN}.git /${PLUGIN} \
	&& cd /${PLUGIN} \
	&& sed "s|'pysyndna @ git+https://github.com/AmandaBirmingham/'||" -i setup.py \
	&& sed "s|'pysyndna.git#egg=pysyndna',||" -i setup.py \
	&& sed "s|'woltka @ git+https://github.com/qiyunzhu/'||" -i setup.py \
    && sed "s|'woltka.git#egg=woltka',||" -i setup.py \
	&& sed "s|'mxdx @ git+https://github.com/wasade/'||" -i setup.py \
    && sed "s|'mxdx.git#egg=mxdx',||" -i setup.py \
    && sed "s|'micov @ git+https://github.com/biocore/'||" -i setup.py \
    && sed "s|'micov.git#egg=micov'||" -i setup.py \
	&& rm -rf qp_woltka/support_files/*.fastq.gz qp_woltka/support_files/alignment.tar \
 	&& pip install .

# test for correct version numbers
RUN woltka_version=`woltka --version` && \
	bowtie2_version=`bowtie2 --version` && \
	if [[ $woltka_version != *"0.1.7"* ]]; then echo "wrong woltka version", $woltka_version; exit 1; fi && \
	if [[ $bowtie2_version != *"2.5.0"* ]]; then echo "wrong bowtie2 version", $bowtie2_version; exit 1; fi

COPY requirements.txt ./requirements.txt
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt

# install sam_filter
RUN wget https://github.com/jianshu93/sam_filter/releases/download/v0.1.0/sam_filter_Linux_x86-64_v01.0.zip \
	&& unzip sam_filter_Linux_x86-64_v01.0.zip \
	&& chmod a+x ./sam_filter \
	&& mv ./sam_filter /usr/local/bin/sam_filter

# ==========================
# Stage 2: Runtime
# ==========================
FROM python:3.9-slim
ARG PLUGIN
ARG QIITA_PLUGINS_DIR
ARG QIITA_CERT_DIR
ARG CONDA_DIR

# let the container know it's plugin name
ENV PLUGIN=${PLUGIN}

# copy bowtie2 binaries from build stage
COPY --from=builder /bowtie2-2.5.0-linux-x86_64/bowtie2 /usr/bin/
COPY --from=builder /bowtie2-2.5.0-linux-x86_64/bowtie2-align-l /usr/bin/
COPY --from=builder /bowtie2-2.5.0-linux-x86_64/bowtie2-align-s /usr/bin/
COPY --from=builder /bowtie2-2.5.0-linux-x86_64/bowtie2-build /usr/bin/
COPY --from=builder /bowtie2-2.5.0-linux-x86_64/bowtie2-build-l /usr/bin/
COPY --from=builder /bowtie2-2.5.0-linux-x86_64/bowtie2-build-s /usr/bin/
COPY --from=builder /bowtie2-2.5.0-linux-x86_64/bowtie2-inspect /usr/bin/
COPY --from=builder /bowtie2-2.5.0-linux-x86_64/bowtie2-inspect-l /usr/bin/
COPY --from=builder /bowtie2-2.5.0-linux-x86_64/bowtie2-inspect-s /usr/bin/
COPY --from=builder /usr/local/bin/seqkit /usr/local/bin/
COPY --from=builder /usr/local/bin/sam_filter /usr/local/bin/sam_filter

RUN apt-get update && apt-get install -y --no-install-recommends \
    parallel \
	seqkit \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# python package compile in build stage
RUN --mount=type=bind,from=builder,source=/wheels,target=/wheels \
	# install python packages (this is huge)
	pip install --no-cache-dir --no-index --find-links=/wheels /wheels/*.whl \
	# clean up biom test files
	&& rm -rf /usr/local/lib/python3.9/site-packages/biom/tests \
	# strip *.so libraries
	&& apt-get update && apt-get install binutils -y --no-install-recommends \
	&& find /usr/local/lib/python3.9/site-packages -name "*.so" -exec strip --strip-unneeded {} + || true \
	&& apt-get purge -y binutils && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*


# install tornado based trigger layer in base environment
RUN pip install -U --no-cache-dir tornado pip-system-certs

# use git branch instead of pypi version (stored via wheel)
COPY --from=builder /qiita_client /qiita_client
RUN cd /qiita_client && pip install .

WORKDIR /

# Handling of certificates, such that plugin can verify qiita main
RUN mkdir -p ${QIITA_CERT_DIR}/
COPY Certificates/tinqiita/*_server* ${QIITA_CERT_DIR}/
ENV REQUESTS_CA_BUNDLE=${QIITA_CERT_DIR}/tinqiita_server_certificates.pem
ENV SSL_CERT_FILE=${QIITA_CERT_DIR}/tinqiita_server_certificates.pem

ENV QC_WOLTKA_DB_DP=/databases/
ENV QC_WOLTKA_SYNDNA_DB_DP=/databases/synDNA
# fake presence of databases, which get later mounted to the container
RUN mkdir -p ${QC_WOLTKA_DB_DP}/wol ${QC_WOLTKA_DB_DP}/rep82 && \
	touch ${QC_WOLTKA_DB_DP}/wol/WoLmin.1.bt2 && \
	touch ${QC_WOLTKA_DB_DP}/rep82/5min.1.bt2

# setup qiita plugin
ENV QIITA_PLUGINS_DIR=${QIITA_PLUGINS_DIR}
ENV ENVIRONMENT='dummy'
RUN mkdir -p ${QIITA_PLUGINS_DIR}/ && \
	ln -s /usr/local/bin/configure_woltka /usr/local/bin/configure_${PLUGIN} && \
    ln -s /usr/local/bin/start_woltka /usr/local/bin/start_${PLUGIN} && \
	configure_${PLUGIN} --env-script "true; export ENVIRONMENT=${ENVIRONMENT}" --ca-cert `find ${QIITA_CERT_DIR}/ -name "*_server.crt" -type f` && \
 	sed -i -E "s/^START_SCRIPT = .+/START_SCRIPT = python \/start_plugin.py ${PLUGIN}/" ${QIITA_PLUGINS_DIR}/*.conf

# copy http listener
COPY trigger.py /trigger.py

# for job execution
COPY start_plugin.sh .

# for testing
COPY test_plugin.sh /test_plugin.sh

# for reference, if user wants to inspect image
COPY *.dockerfile /

# add our little python script that simulates a SLURM cluster
COPY sbatch /bin/sbatch

# integrated tests for presence of binaries
# if this chain of commands fails, it is most likely that one of the binaries
# is missing in the container!
RUN grep --version | grep "GNU grep" \
    && find --version | grep findutils \
    && parallel --version | grep "GNU Parallel" \
    && date --version | grep "GNU coreutils" \
    && hostname --version | grep hostname \
    && tar --version | grep "GNU tar" \
    && cut --version | grep "GNU coreutils" \
    && sed --version | grep "GNU sed" \
    && gzip --version | grep "gzip " \
    && awk --version | grep "mawk " \
    && xz --version | grep "XZ Utils" \
	&& mxdx --help | grep "multiplexing and demultiplexing" \
	&& bowtie2 --version | grep "version 2.5.0" \
	&& seqkit --help | grep "Version: 2." \
	&& micov --help | grep "microbiome coverage"
	
CMD ["./start_plugin.sh"]
