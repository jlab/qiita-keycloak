FROM ubuntu:24.04

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
RUN conda install --yes tornado
COPY trigger.py /trigger.py

# Create conda env
RUN conda create --yes --quiet -n multiqc_report -c bioconda python=3.9 pip
# Make RUN commands use the new environment:
# append --format docker to the build command, see https://github.com/containers/podman/issues/8477
SHELL ["conda", "run", "-p", "/opt/conda/envs/multiqc_report", "/bin/bash", "-c"]

ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

RUN pip install -U pip

RUN pip install https://github.com/qiita-spots/qiita_client/archive/master.zip
RUN pip install https://github.com/qiita-spots/qiita-files/archive/master.zip
# Include plugin source in the image build context.
# COPY src/qtp-multiqc-report /qtp-multiqc-report # only for live coding

RUN mkdir -p /tmp/qp-multiqc /qtp-multiqc-report \
 && cd /tmp/qp-multiqc \
 && git clone --depth 1 --no-checkout https://github.com/jlab/qp-multiqc.git . \
 && git sparse-checkout init --cone \
 && git sparse-checkout set qtp-multiqc-report \
 && git checkout main \
 && cp -a /tmp/qp-multiqc/qtp-multiqc-report/. /qtp-multiqc-report/ \
 && rm -rf /tmp/qp-multiqc

WORKDIR /qtp-multiqc-report

RUN pip install -e .
RUN pip install pip-system-certs

# TODO: should the plugin get the server configuration?!
RUN export QIITA_CONFIG_FP=/qiita/config_qiita_oidc.cfg

WORKDIR /

COPY start_qtp-multiqc-report.sh .
RUN chmod 755 start_qtp-multiqc-report.sh

RUN mkdir -p /unshared_plugins
ENV QIITA_PLUGINS_DIR=/unshared_plugins/

##  Export cert and config filepaths
COPY Certificates /unshared_certificates
RUN cat /unshared_certificates/stefan_rootca.crt >> `python -c "import certifi; print(certifi.where())"`  # append own rootCA onto chain of trust
RUN export REQUESTS_CA_BUNDLE=`python -c "import certifi; print(certifi.where())"`
RUN export SSL_CERT_FILE=`python -c "import certifi; print(certifi.where())"`

#RUN export QIITA_ROOTCA_CERT=/unshared_certificates/ci_rootca.crt
#RUN sed -i "s/f'Entered BaseQiitaPlugin._register_command({command.name})'/'Entered BaseQiitaPlugin._register_command(%s)' % command.name/"  $CONDA_PREFIX/lib/python3.5/site-packages/qiita_client/plugin.py
RUN chmod u+x /qtp-multiqc-report/scripts/configure_qtp_multiqc_report
RUN python /qtp-multiqc-report/scripts/configure_qtp_multiqc_report --env-script "true" --server-cert /unshared_certificates/stefan_server.crt
RUN sed -i -E "s/^START_SCRIPT = .+/START_SCRIPT = python \/start_plugin.py qtp-multiqc-report/" /unshared_plugins/*.conf

CMD ["./start_qtp-multiqc-report.sh"]
