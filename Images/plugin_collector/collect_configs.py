import os
import requests
import sys

ENV_PLUGINS = 'QIITA_PLUGINS'
PORT = 5000
API_ENDPOINT = "config"

if ENV_PLUGINS not in os.environ or os.environ['QIITA_PLUGINS'] is None or os.environ['QIITA_PLUGINS'] == "":
    raise ValueError("No qiita plugins given for which configuration files should be retrieved! Environment variable '%s' not set!" % ENV_PLUGINS)

var_plugins = os.environ['QIITA_PLUGINS']
# strip potential quotes
if var_plugins.startswith('"') or var_plugins.startswith("'"):
    var_plugins = var_plugins[1:]
if var_plugins.endswith('"') or var_plugins.endswith("'"):
    var_plugins = var_plugins[:-1]

containers = [c for c in var_plugins.split(':') if c != ""]

print("retrieving %i qiita plugin configurations:" % len(containers), file=sys.stderr)
for i, container in enumerate(containers):
    if container == "":
        continue
    print('  (%i/%i) %s' % (i+1, len(containers), container), end="", file=sys.stderr)
    url = 'http://%s%s-1:%s/%s' % ('tinqiita-', container, PORT, API_ENDPOINT)
    print(" '%s'" % url, end="", file=sys.stderr)

    req = requests.get(url)
    if req.status_code != 200:
        print(" failed.", file=sys.stderr)
    else:
        fp_config = '/qiita_plugins/%s.conf' % container
        if os.path.exists(fp_config):
            print(" already present.", file=sys.stderr)
        else:
            with open(fp_config, 'w') as f:
                f.write(req.content.decode('utf-8'))
            print(" ok.", file=sys.stderr)

print("done.", file=sys.stderr)
