#!/bin/sh
mkdir -p /var/run/nginx/ /usr/local/var/tmp/nginx/

nginx -t -c /qiita_configuration/nginx_qiita.conf

# proper listening and reacting to SIGTERM
cleanup() {
    echo "Received SIGTERM, stopping..."
    kill "$PY_PID" 2>/dev/null
    wait "$PY_PID"
    exit 0
}
trap cleanup SIGTERM SIGINT

# start nginx and safe PID in variable
nginx -c /qiita_configuration/nginx_qiita.conf &
PY_PID=$!

# wait till nginx process is terminated
wait "$PY_PID"
