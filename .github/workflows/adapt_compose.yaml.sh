#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="$1"
PLUGIN="$2"

#sed -i "s/qiita/KURT/g" $COMPOSE_FILE

# change images to be used from local to github internal builds
sed -i "s|image: local-\([^:]*\):latest|image: ghcr.io/jlab/qiita-keycloak/\1:testcandidate|" $COMPOSE_FILE
if [ "$PLUGIN" == "qp-qiime2" ]; then
    # the qp-qiime2 plugin needs qtp-visualization and qtp-diversity to be active as well
    sed -i "/this comment is a start flag for github action/,/this comment is a stop flag for github action/c\      ${PLUGIN}:\n        condition: service_started\n      qtp-diversity:\n        condition: service_started\n      qtp-visualization:\n        condition: service_started" $COMPOSE_FILE;
    sed -i "s|\(      - QIITA_PLUGINS=\"\).*|\1${PLUGIN}:qtp-diversity:qtp-visualization:\"|" $COMPOSE_FILE
else
    # for all other plugins: ensure only one plugin in registered and subsequently tested
    sed -i "/this comment is a start flag for github action/,/this comment is a stop flag for github action/c\      ${PLUGIN}:\n        condition: service_started" $COMPOSE_FILE
    sed -i "s|\(      - QIITA_PLUGINS=\"\).*|\1${PLUGIN}:\"|" $COMPOSE_FILE
fi;
# remove references to environment files, which would only be generated when according makefile target is build, which is not the case for github action
sed -i '/^    env_file:/ { N; d }' $COMPOSE_FILE
# deactivaty any mounts from src directory into container
sed -i "s|\(\s*- ./src.*\)|#\1|g" $COMPOSE_FILE
# use docker volume for log files instead of local directory
sed -i "s|\(\s*- \)./logs:|\1qiita-logs:|g" $COMPOSE_FILE
