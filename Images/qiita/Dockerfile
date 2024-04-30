FROM ubuntu:22.04

ARG MINIFORGE_VERSION=24.1.2-0

ENV CONDA_DIR=/opt/conda
ENV PATH=${CONDA_DIR}/bin:${PATH}

RUN apt-get -y update
RUN apt-get -y install \
	git \
	wget

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

#RUN mkdir Git
#RUN git clone -b dev https://github.com/qiita-spots/qiita.git


#https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
