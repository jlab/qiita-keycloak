FROM ubuntu:22.04

ARG MINIFORGE_VERSION=24.1.2-0

ENV CONDA_DIR=/opt/conda
ENV PATH=${CONDA_DIR}/bin:${PATH}

RUN apt-get -y update
RUN apt-get -y install \
	git \
	wget
RUN apt-get -y install build-essential
# install miniforge3 for "conda"
# see https://github.com/conda-forge/miniforge-images/blob/master/ubuntu/Dockerfile
RUN wget https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/Miniforge3-${MINIFORGE_VERSION}-Linux-x86_64.sh -O /tmp/miniforge3.sh && \
	/bin/bash /tmp/miniforge3.sh -b -p ${CONDA_DIR} && \
	echo ". ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate base" >> /etc/skel/.bashrc && \
	echo ". ${CONDA_DIR}/etc/profile.d/conda.sh && conda activate base" >> ~/.bashrc \
	conda init

# create conda env for qiita with all necessary dependencies (conda and pip)
RUN conda create --quiet --yes -n qiita python=3.9 pip libgfortran numpy nginx cython anaconda::redis

# Make RUN commands use the new environment:
# append --format docker to the build command, see https://github.com/containers/podman/issues/8477
SHELL ["conda", "run", "-n", "qiita", "/bin/bash", "-c"]

RUN pip install -U pip
RUN pip install \
	sphinx \
	sphinx-bootstrap-theme \
	nose-timer \
	Click \
	coverage

#Clone the Qiita Repo
#RUN git clone -b master https://github.com/qiita-spots/qiita.git
RUN git clone -b auth_oidc https://github.com/jlab/qiita.git

#We need to install necessary dependencies
#as well as some extra dependencies for psycopg2 to work
RUN git clone https://github.com/psycopg/psycopg2.git
RUN apt-get -y update
RUN apt-get -y install libpq-dev python3-dev gcc
RUN pg_config --version
RUN export PATH=/usr/lib/postgresql/14.11/bin/:$PATH
RUN pip install psycopg2-binary
RUN pip install -e psycopg2/.

#Install pip packaages for Qiita
RUN pip install -e qiita/. --no-binary redbiom
RUN pip install "Jinja2<3.1"


#Configuring the Qiita Config to run inside the container
#RUN sed -i 's/BASE_URL = https:\/\/localhost:8383/BASE_URL = https:\/\/localhost:21174\//' qiita/qiita_core/support_files/config_test.cfg
#RUN sed -i 's/\/home\/runner\/work\/qiita\/qiita\//\/qiita\//' qiita/qiita_core/support_files/config_test.cfg

COPY config_qiita_oidc.cfg .
RUN chmod 777 config_qiita_oidc.cfg

#Copy Bash Script to run Qiita to the container
COPY start_qiita.sh .
RUN chmod 777 start_qiita.sh

#I will leave this ENTRYPOINT here as a comment in case debugging
#is necessary
#ENTRYPOINT ["/bin/bash"]
ENTRYPOINT ["conda", "run", "-n", "qiita", "./start_qiita.sh"]