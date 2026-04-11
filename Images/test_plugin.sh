#!/bin/bash

echo "plugin to be tested is: '$PLUGIN'"

# by default, clone from master. But can also clone different branches
branch="${PLUGIN_BRANCH:-master}"
# by default, clone from qiita-spots branch. But can also use alternative forks
fork="${PLUGIN_FORK:-qiita-spots}"

# install dependencies
apt-get update
apt-get -y --fix-missing install git
if [ "qp-target-gene" == "$PLUGIN" ]; then
    REQUESTS_CA_BUNDLE="" pip2 install "pytest<5";
else
    REQUESTS_CA_BUNDLE="" pip install pytest;
fi;

if [ "qp-qiime2" != "$PLUGIN" ]; then
    # clone plugin repository
    git clone -b ${branch} https://github.com/${fork}/${PLUGIN};
    hash=$(cd ${PLUGIN} && git rev-parse HEAD);
    echo "Clone from '${fork}', branch '${branch}', commit '${hash}'" 1>&2;
fi;

# NOTE: client api reset only works when communicating with Qitta Master,
# thus, you need to directly address the port of the master container. Don't
# go through nginx!

# fix qiita base url in client
for f in `find /usr/local/lib/python*/site-packages/qiita_client/ /usr/local/lib/python*/dist-packages/qiita_client/ /opt/conda/envs/qp-qiime2/lib/python3.8/site-packages/qiita_client/ -name "testing.py"`; do
    sed -i 's|URL = "https://localhost:8383"|URL = "https://tinqiita-qiita-1:21174"|' $f;
done

# fix qiita base url in qtp-sequencing plugin tests
for f in `find /${PLUGIN}/*/tests/ -name 'test_*.py'`; do
    sed -i 's|https://localhost:21174|https://tinqiita-qiita-1:21174|' $f;
    # below seen in qp-target-gene
    sed -i 's|plugin("https://localhost:21174", .register., .ignored.)|plugin("https://tinqiita-qiita-1:21174", "register", "ignored")|' $f;
done

# fix qiita base url in qtp-diversity plugin tests. Use . instead of " or ' to be more general
for f in `find /${PLUGIN}/*/tests/ -name 'test_*.py'`; do
    sed -i "s|plugin(.https://localhost:8383., .register., .ignored.)|plugin('https://tinqiita-nginx-1:8383', 'register', 'ignored')|" $f;
    # below seen in qtp-biom
    sed -i 's|plugin("https://localhost:8383", job_id, self.out_dir)|plugin("https://tinqiita-nginx-1:8383", job_id, self.out_dir)|' $f;
done

# better save than sorry
export QIITA_PORT=21174
export QIITA_ROOTCA_CERT=$SSL_CERT_FILE

# either (old) plugins ignore this at all OR adapted plugins switch to https file transfer
export QIITA_PLUGINCOUPLING=https

# change into plugin source directory and execute actual tests
if [ "qp-qiime2" == "$PLUGIN" ]; then
    source /opt/conda/etc/profile.d/conda.sh; conda activate /opt/conda/envs/${PLUGIN}; cd ${PLUGIN} && pytest;
else
    cd ${PLUGIN} && pytest;
fi;
