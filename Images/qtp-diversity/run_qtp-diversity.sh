#!/bin/bash

export REQUESTS_CA_BUNDLE=/qiita_certificates/qiita_certificates.pem
export SSL_CERT_FILE=/qiita_certificates/qiita_certificates.pem

QIITA_SERVER_URL=$1
JOB_ID=$2
OUTPUT_DIR=$3

start_diversity_types $QIITA_SERVER_URL $JOB_ID $OUTPUT_DIR