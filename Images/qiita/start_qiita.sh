#!/bin/bash
#sleep 300000
export QIITA_CONFIG_FP="/qiita/config_qiita_oidc.cfg"

# This was commented out bc it stopped working anymore and i was focusing on fixing something else, if you create the database for the first
# time you will have to pick the appropriate options.
#if [ "$( export PGPASSWORD='postgres'; psql -h qiita-db -U postgres -XtAc "SELECT 1 FROM postgres WHERE datname='qiita_test'" )" = '1' ]
#then
#    qiita pet webserver --no-build-docs start --port 21174 --master
#else
#    qiita-env make --no-load-ontologies
#    qiita pet webserver --no-build-docs start --port 21174 --master
#fi
#qiita-env make --no-load-ontologies
qiita pet webserver --no-build-docs start --port 21174 --master