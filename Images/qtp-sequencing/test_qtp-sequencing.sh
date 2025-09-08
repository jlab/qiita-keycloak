#!/bin/bash

echo "plugin to be tested is: '$PLUGIN':wq"

# install dependencies
apt-get update
apt-get -y --fix-missing install git
pip install pytest

# clone plugin repository
git clone https://github.com/qiita-spots/${PLUGIN}

# NOTE: client api reset only works when communicating with Qitta Master,
# thus, you need to directly address the port of the master container. Don't
# go through nginx!

# fix qiita base url in client
for f in `find /usr/local/lib/python*/site-packages/qiita_client/ -name "testing.py"`; do
    sed -i 's|URL = "https://localhost:8383"|URL = "https://tinqiita-qiita-1:21174"|' $f;
done

# fix qiita base url in plugin tests
for f in `find /${PLUGIN}/*/tests/ -name 'test_*.py'`; do
    sed -i 's|https://localhost:21174|https://tinqiita-qiita-1:21174|' $f;
done

# better save than sorry
export QIITA_PORT=21174
export QIITA_ROOTCA_CERT=$SSL_CERT_FILE

# change into plugin source directory and execute actual tests
cd ${PLUGIN} && pytest
