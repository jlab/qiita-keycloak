# base image: ubuntu:24.04
FROM ubuntu:24.04

ARG MINIFORGE_VERSION=24.1.2-0

# set environments
ENV CONDA_DIR=/opt/conda
ENV PATH=${CONDA_DIR}/bin:${PATH}

# install system dependencies
RUN apt-get -y update
RUN apt-get -y --fix-missing install \
    git \
    wget 

# install miniforge
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

# create conda environment
RUN conda create --quiet -n multiqc python=3.9 pip
SHELL ["conda", "run", "-p", "/opt/conda/envs/multiqc", "/bin/bash", "-c"]

ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

# install fastqc and multiqc
RUN conda install --quiet --yes -c bioconda fastqc 
RUN conda install --quiet --yes -c bioconda multiqc

# install qiita plugins
RUN pip install https://github.com/qiita-spots/qiita_client/archive/master.zip
RUN pip install https://github.com/qiita-spots/qiita-files/archive/master.zip

# install qp-multiqc plugin (lokal)
RUN git clone https://github.com/jlab/qp-multiqc.git
#COPY ./Images/qp-multiqc /qp-multiqc
WORKDIR qp-multiqc
RUN pip install -e .

# optional: wenn du system-Zertifikate brauchst
RUN pip install pip-system-certs

# plugin configuration and start script
RUN export QIITA_CONFIG_FP=/qiita/config_qiita_oidc.cfg
WORKDIR /
COPY start_qp-multiqc.sh .
RUN chmod 755 start_qp-multiqc.sh
RUN mkdir -p /unshared_plugins
ENV QIITA_PLUGINS_DIR=/unshared_plugins/

# put in certificates
COPY Certificates /unshared_certificates
RUN cat /unshared_certificates/stefan_rootca.crt >> `python -c "import certifi; print(certifi.where())"`
RUN export REQUESTS_CA_BUNDLE=`python -c "import certifi; print(certifi.where())"`
RUN export SSL_CERT_FILE=`python -c "import certifi; print(certifi.where())"`

# plugin setup 
RUN sed -i "s/f'Entered BaseQiitaPlugin._register_command({command.name})'/'Entered BaseQiitaPlugin._register_command(%s)' % command.name/"  $CONDA_PREFIX/lib/python3.9/site-packages/qiita_client/plugin.py
RUN chmod +x /qp-multiqc/scripts/configure_qp_multiqc
RUN /qp-multiqc/scripts/configure_qp_multiqc --env-script "true" --server-cert /unshared_certificates/stefan_server.crt
RUN sed -i -E "s/^START_SCRIPT = .+/START_SCRIPT = python \/start_plugin.py qp-multiqc/" /unshared_plugins/*.conf

# start script
CMD ["./start_qp-multiqc.sh"]
