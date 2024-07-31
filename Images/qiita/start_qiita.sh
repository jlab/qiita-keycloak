#!/bin/bash

# first we start the redis server
# redis-server --daemonize yes --port 7777
# redis-server --daemonize yes --port 6379

export QIITA_CONFIG_FP="/qiita/config_qiita_oidc.cfg"
# TODO: kick out the supervisor -> one "master" image and one "worker" image and then they do shenanigans together via replicas
# conda list
if [ "$( psql -XtAc "SELECT 1 FROM postgres WHERE datname='qiita_test'" )" = '1' ]
then
    # supervisord -c /supervisor_foreground.conf
    qiita pet webserver --no-build-docs start --port 21174 --master
else
    qiita-env make --no-load-ontologies
    qiita pet webserver --no-build-docs start --port 21174 --master
    # supervisord -c /supervisor_foreground.conf
fi

# building the database without ontologies
# qiita-env make --no-load-ontologies # || true

# starting the webserver without building the docs
# qiita pet webserver --no-build-docs start

# supervisord -c /supervisor_foreground.conf