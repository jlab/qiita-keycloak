#!/bin/bash

# it seems to be necessary to give the plugin container some lead time
# TODO: this might be more appropriately be addressed with healthchecks in the compose file
sleep 3
# create WORKING_DIR, UPLOAD_DATA_DIR and BASE_DATA_DIR in shared volume
mkdir -p /qiita_data/working_dir/ /qiita_data/uploads/
python3 /collect_configs.py
python3 /fix_test_db.py

echo "plugin conf dir is >$QIITA_PLUGINS< and contains:"
ls -la $QIITA_PLUGINS
