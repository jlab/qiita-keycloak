#!/bin/bash


export QIITA_CONFIG_FP="/qiita/config_qiita_oidc.cfg"

qiita pet webserver --no-build-docs start --port 21175

