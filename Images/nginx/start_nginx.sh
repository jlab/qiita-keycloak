#!/bin/bash
mkdir -p /opt/conda/envs/nginx/var/run/nginx/ /usr/local/var/tmp/nginx/

nginx -c /nginx_qiita.conf 