#!/bin/bash

cat /qiita_certificates/k8s_rootca.crt >> `python -c "import certifi; print(certifi.where())"`

export REQUESTS_CA_BUNDLE=/qiita_certificates/k8s_qiita_certificates.pem
export SSL_CERT_FILE=/qiita_certificates/k8s_qiita_certificates.pem

cd / && python trigger.py start_biom

tail -f /dev/null
