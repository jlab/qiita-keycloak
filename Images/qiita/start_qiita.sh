#!/bin/bash

CONDA_DIR=/opt/conda
ENV_NAME=qiita
#PORT=21174

#sleep 300000
#export QIITA_CONFIG_FP="/qiita/config_qiita_oidc.cfg"
if [ -n "${MASTER}" ] && [ ! -d /qiita/qiita_db/__pycache__ ]; then
	source $CONDA_DIR/etc/profile.d/conda.sh; conda activate $CONDA_DIR/envs/$ENV_NAME; cd /qiita; pip install -e . --no-binary redbiom;
fi

# # We execute qiita-env make every time. We expect that it will fail always but the very first time, as the qiita DB should exist from then on
# source $CONDA_DIR/etc/profile.d/conda.sh; conda activate $CONDA_DIR/envs/$ENV_NAME; cd /qiita; qiita-env make --no-load-ontologies 2> .env-make.err || true
# # To avoid confusing the user, STDERR is written into a file and only reported if it does not contain the text that we expect to see if it just reports the existing DB
# grep 'already present on the system. You can drop it by running' .env-make.err > /dev/null || cat .env-make.err

# This was commented out bc it stopped working anymore and i was focusing on fixing something else, if you create the database for the first
# time you will have to pick the appropriate options.
#if [ "$( export PGPASSWORD='postgres'; psql -h qiita-db -U postgres -XtAc "SELECT 1 FROM postgres WHERE datname='qiita_test'" )" = '1' ]
#then
#    qiita pet webserver --no-build-docs start --port 21174 --master
#else
#    qiita-env make --no-load-ontologies
#    qiita pet webserver --no-build-docs start --port 21174 --master
#fi
#qiita-env make --no-load-ontologies; true
#mkdir -p /qiita/plugins
#sleep 3
source $CONDA_DIR/etc/profile.d/conda.sh; conda activate $CONDA_DIR/envs/$ENV_NAME; cd /qiita && qiita pet webserver --no-build-docs start --port $PORT $MASTER 2> /logs/qiita_pet$MASTER.log 1>&2

tail -f /dev/null
