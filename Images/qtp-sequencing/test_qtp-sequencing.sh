#!/bin/bash

echo "plugin to be tested is: '$PLUGIN':wq"

# install dependencies
apt-get update
apt-get install git
pip install pytest

# clone plugin repository
git clone https://github.com/qiita-spots/${PLUGIN}

# fix qiita base url in client
for f in `find /usr/local/lib/python*/site-packages/qiita_client/ -name "testing.py"`; do
    sed -i 's|URL = "https://localhost:8383"|URL = "https://tinqiita-nginx-1:8383"|' $f;
done

# fix qiita base url in plugin tests
for f in `find ${PLUGIN}/*/tests/ -name 'test_*.py'`; do
    sed -i 's|https://localhost:21174|https://tinqiita-nginx-1:8383|' $f;
done

# better save than sorry
export QIITA_PORT=8383;

# change into plugin source directory
cd ${PLUGIN}

# execute actual tests
pytest
