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

if req.status_code != 200:
    print(req.status_code)
    print(req.content, file=sys.stderr)
    sys.exit(1)

retvalues = json.loads(req.text)
if pluginname in ['qp-woltka']:
    # as the woltka plugin uses slurm, its external job-id is expected to be
    # returned by the start_qtp-woltka script. We thus have to emulate this
    # behavior here.
    print(retvalues['stdout'], end="")
    # to report errors, qiita also needs to read STDERR content
    if 'stderr' in retvalues.keys():
        print(retvalues['stderr'], file=sys.stderr, end="")
else:
    if 'stderr' in retvalues.keys():
        print("=== request STDERR ===\n%s" % retvalues['stderr'])
    else:
        print("=== request STDERR: empty ===\n")
    if 'stdout' in retvalues.keys():
        print("=== request STDOUT ===\n%s" % retvalues['stdout'])
    else:
        print("=== request STDOUT: empty ===\n")
