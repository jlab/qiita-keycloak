#!/bin/bash

# first we start the redis server
redis-server --daemonize yes --port 7777
redis-server --daemonize yes --port 6379

export QIITA_CONFIG_FP="/config_qiita_oidc.cfg"

conda list

# building the database without ontologies
qiita-env make --no-load-ontologies # || true

# starting the webserver without building the docs
# qiita pet webserver --no-build-docs start

supervisord -c /supervisor_foreground.conf