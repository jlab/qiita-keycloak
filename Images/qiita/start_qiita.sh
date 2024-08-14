#!/bin/bash
#sleep 300000
export QIITA_CONFIG_FP="/qiita/config_qiita_oidc.cfg"

if [ "$( psql -h localhost -U postgres -XtAc "SELECT 1 FROM postgres WHERE datname='qiita_test'" )" = '1' ]
then
    qiita pet webserver --no-build-docs start --port 21174 --master
else
    qiita-env make --no-load-ontologies
    qiita pet webserver --no-build-docs start --port 21174 --master
fi
