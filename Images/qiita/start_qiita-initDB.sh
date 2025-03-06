#!/bin/bash

CONDA_DIR=/opt/conda
ENV_NAME=qiita
#PORT=21174

# We execute qiita-env make every time. We expect that it will fail always but the very first time, as the qiita DB should exist from then on
source $CONDA_DIR/etc/profile.d/conda.sh; conda activate $CONDA_DIR/envs/$ENV_NAME; cd /qiita; qiita-env make --no-load-ontologies 2> .env-make.err || true
# To avoid confusing the user, STDERR is written into a file and only reported if it does not contain the text that we expect to see if it just reports the existing DB
grep 'already present on the system. You can drop it by running' .env-make.err > /dev/null || cat .env-make.err
