#!/bin/bash
ENV_NAME=qiime2

source /opt/conda/bin/activate 
conda activate $ENV_NAME

cat /qiita_certificates/k8s_rootca.crt >> `python -c "import certifi; print(certifi.where())"`

export REQUESTS_CA_BUNDLE=`python -c "import certifi; print(certifi.where())"`
export SSL_CERT_FILE=`python -c "import certifi; print(certifi.where())"`

QIITA_SERVER_URL=$1
JOB_ID=$2
OUTPUT_DIR=$3

start_qiime2 $QIITA_SERVER_URL $JOB_ID $OUTPUT_DIR