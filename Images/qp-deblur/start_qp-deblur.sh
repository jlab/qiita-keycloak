#!/bin/bash

cat /qiita_certificates/k8s_rootca.crt >> `python -c "import certifi; print(certifi.where())"`

export REQUESTS_CA_BUNDLE=`python -c "import certifi; print(certifi.where())"`
export SSL_CERT_FILE=`python -c "import certifi; print(certifi.where())"`

ln -s /qiita_data/reference/qp-deblur/references/* /opt/conda/envs/deblur/share/fragment-insertion/ref/

cd / && python trigger.py start_deblur

tail -f /dev/null
