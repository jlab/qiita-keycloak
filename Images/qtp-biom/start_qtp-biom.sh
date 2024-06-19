#!/bin/bash

export QIITA_ROOTCA_CERT=/qiita/qiita_core/support_files/ci_server.crt
export QIITA_CONFIG_FP=/qiita/config_qiita_oidc.cfg
export QIITA_PLUGINS_DIR=/qiita/plugins/

configure_biom --env-script "source /opt/conda/bin/activate ; conda activate qtp-biom" --server-cert $QIITA_ROOTCA_CERT

start_biom https://localhost:8383 register ignored

#sleep 30000000000000000000000000000