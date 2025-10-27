#!/bin/bash
cat /qiita_certificates/k8s_rootca.crt >> `python3 -c "import certifi; print(certifi.where())"`

export REQUESTS_CA_BUNDLE=`python3 -c "import certifi; print(certifi.where())"`
export SSL_CERT_FILE=`python3 -c "import certifi; print(certifi.where())"`

cd / && python3 trigger.py start_target_gene

tail -f /dev/null
