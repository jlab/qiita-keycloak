#!/bin/bash
export REQUESTS_CA_BUNDLE=/qiita_certificates/qiita_certificates.pem
export SSL_CERT_FILE=/qiita_certificates/qiita_certificates.pem


cd / && python3 trigger.py start_target_gene

tail -f /dev/null
