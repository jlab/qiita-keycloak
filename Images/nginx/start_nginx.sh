#!/bin/sh
mkdir -p /var/run/nginx/ /usr/local/var/tmp/nginx/

nginx -t -c /qiita_configuration/nginx_qiita.conf
nginx -c /qiita_configuration/nginx_qiita.conf
