import os
import sys
import requests
import json

PORT = 5000
API_ENDPOINT = "run"

pluginname, qiita_server_url, job_id, output_dir = sys.argv[1:]

req = requests.post('http://%s%s-1:%s/run' % ('tinqiita-', pluginname, PORT),
                    json={'url': qiita_server_url,
                          'job_id': job_id,
                          'output_dir': output_dir})
print(req.status_code)
if req.status_code != 200:
    print(req.content)

retvalues = json.loads(req.text)
if 'stderr' in retvalues.keys():
    print("=== request STDERR ===\n%s" % retvalues['stderr'])
else:
    print("=== request STDERR: empty ===\n")
if 'stdout' in retvalues.keys():
    print("=== request STDOUT ===\n%s" % retvalues['stdout'])
else:
    print("=== request STDOUT: empty ===\n")
