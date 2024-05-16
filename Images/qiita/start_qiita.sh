#!/bin/bash

#first we start the redis server
redis-server --daemonize yes --port 7777
redis-server --daemonize yes --port 6379

#building the database without ontologies
qiita-env make --no-load-ontologies

#starting the webserver without building the docs
qiita pet webserver --no-build-docs start