#!/bin/bash

CONDA_DIR=/opt/conda
ENV_NAME=qiita

if [ -n "${MASTER}" ] && [ ! -d /qiita/qiita_db/__pycache__ ]; then
	source $CONDA_DIR/etc/profile.d/conda.sh; conda activate $CONDA_DIR/envs/$ENV_NAME; cd /qiita; pip install -e . --no-binary redbiom;
fi

# register self signed certificate for keycloak
cp /keycloak_certificates/keycloak_rootca.crt /keycloak_certificates/keycloak_server.crt /usr/local/share/ca-certificates/
update-ca-certificates

# proper listening and reacting to SIGTERM
cleanup() {
    echo "Received SIGTERM, stopping..."
    kill "$PY_PID" 2>/dev/null
    wait "$PY_PID"
    exit 0
}
trap cleanup SIGTERM SIGINT

source $CONDA_DIR/etc/profile.d/conda.sh
conda activate $CONDA_DIR/envs/$ENV_NAME
cd /qiita
# start Qiita and safe PID in variable
qiita pet webserver --no-build-docs start --port $PORT $MASTER 2> /logs/qiita_pet$MASTER.log 1>&2 &
PY_PID=$!

# wait till Qiita process is terminated
wait "$PY_PID"
