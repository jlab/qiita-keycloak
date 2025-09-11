#!/bin/bash

cat /qiita_certificates/k8s_rootca.crt >> `python -c "import certifi; print(certifi.where())"`

export REQUESTS_CA_BUNDLE=`python -c "import certifi; print(certifi.where())"`
export SSL_CERT_FILE=`python -c "import certifi; print(certifi.where())"`

cd / && python trigger.py start_qtp_sequencing

tail -f /dev/null
