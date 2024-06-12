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
RUN conda create --quiet --yes -n nginx nginx

COPY nginx_qiita.conf .
COPY start_nginx.sh .

RUN chmod 777 nginx_qiita.conf
RUN chmod 777 start_nginx.sh

RUN mkdir /var/log/nginx

#ENTRYPOINT ["/bin/bash",  "-l", "-c" ]
ENTRYPOINT ["conda", "run", "-n", "nginx", "./start_nginx.sh"]