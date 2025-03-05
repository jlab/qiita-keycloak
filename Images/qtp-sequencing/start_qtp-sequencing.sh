#!/bin/bash

#export QIITA_ROOTCA_CERT=/qiita/qiita_core/support_files/ci_server.crt
export QIITA_CONFIG_FP=/qiita_configurations/qiita_server.cfg
CONDA_DIR=/opt/conda
ENV_NAME=qtp-sequencing

# Commented out because I wanted to jump onto the container to crawl into the code (it crashes during the start_biom step)

#configure_biom --env-script "source /opt/conda/bin/activate ; conda activate qtp-biom" --server-cert $QIITA_ROOTCA_CERT

#start_biom https://localhost:8383 register ignored
#start_biom http://qiita:8383 register ignored
#source $CONDA_DIR/etc/profile.d/conda.sh; conda activate $CONDA_DIR/envs/$ENV_NAME; cd / && python trigger.py
source /opt/conda/etc/profile.d/conda.sh; conda activate /opt/conda/envs/qtp-sequencing; cd / && python trigger.py qtp-sequencing start_qtp_sequencing /qtp-sequencing

tail -f /dev/null
