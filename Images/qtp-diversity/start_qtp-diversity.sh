#!/bin/bash

export REQUESTS_CA_BUNDLE=/qiita_certificates/k8s_qiita_certificates.pem
export SSL_CERT_FILE=/qiita_certificates/k8s_qiita_certificates.pem

cd / && python trigger.py start_diversity_types

tail -f /dev/null
