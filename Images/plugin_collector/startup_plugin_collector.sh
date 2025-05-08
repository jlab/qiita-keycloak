#!/bin/bash

# copy certificates into shared volume, if not present there already
for f in `find /unshared_certificates -type f -name "*" | xargs`; do
	test -f /qiita_certificates/`basename $f` || cp -v $f /qiita_certificates/`basename $f`;
done

# it seems to be necessary to give the plugin container some lead time
# TODO: this might be more appropriately be addressed with healthchecks in the compose file
sleep 3
# create WORKING_DIR, UPLOAD_DATA_DIR and BASE_DATA_DIR in shared volume
mkdir -p /qiita_data/working_dir/ /qiita_data/uploads/
python3 /collect_configs.py
python3 /fix_test_db.py
