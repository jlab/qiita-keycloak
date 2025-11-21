import tornado.ioloop
import tornado.web
import json
import subprocess
from glob import glob
import sys
import traceback
import asyncio
import sys
import os

conda_env_name = None
plugin_start_script = None
plugin_src_dir = None

class RunCommandHandler(tornado.web.RequestHandler):
    async def post(self):
        try:
            # JSON-Request-Daten lesen
            data = json.loads(self.request.body.decode("utf-8"))
            qiita_worker_url = data.get('url')
            job_id = data.get('job_id')
            output_dir = data.get('output_dir')

            #command = data.get("command")

            if not qiita_worker_url or not job_id or not output_dir:
                self.set_status(400)
                self.write({"error": "Kein Befehl angegeben"})
                return

            # Systembefehl ausfuehren
            cmd = ""
            if conda_env_name is not None:
                cmd = 'source /opt/conda/etc/profile.d/conda.sh; conda activate /opt/conda/envs/%s; %s/scripts/%s %s %s %s' % (conda_env_name, plugin_src_dir, plugin_start_script, qiita_worker_url, job_id, output_dir)
            else:
                cmd = '%s %s %s %s' % (plugin_start_script, qiita_worker_url, job_id, output_dir)
            # Asynchronen Subprozess starten
            proc = await asyncio.create_subprocess_shell(
                cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                executable='/bin/bash'
            )
            stdout, stderr = await proc.communicate()
            #result = subprocess.run(cmd, shell=True, universal_newlines=True, executable='/bin/bash', stdout=subprocess.PIPE, stderr=subprocess.PIPE)

            if proc.returncode != 0:
                self.set_status(500)

            # Antwort zurueckgeben
            self.write({
                "stdout": stdout.decode(),
                "stderr": stderr.decode(),
                "returncode": proc.returncode,
                "cmd": cmd,
            })

        except Exception as e:
            self.set_status(500)
            # a hack to learn which docker service I am in
            plugin_name = "unknown"
            if conda_env_name is not None:
                for f in glob('/start_*.sh'):
                    plugin_name = f.split('_')[-1].replace('.sh', '')
                    break
            else:
                plugin_name = os.path.basename(plugin_start_script).replace('start_', '')
            print("Error in service '%s': %s" % (plugin_name, str(e)), file=sys.stderr)
            traceback.print_exc()
            self.write({"error": str(e)})

class RunConfigHandler(tornado.web.RequestHandler):
    async def get(self):
        try:
            for fp_config in glob('/unshared_plugins/*.conf'):
                with open(fp_config, 'r') as f:
                    self.write(''.join(f.readlines()) + '\n')
        except Exception as e:
            self.set_status(500)
            self.write({"error": str(e)})

def make_app():
    return tornado.web.Application([
        (r"/run", RunCommandHandler),
        (r"/config", RunConfigHandler),
    ])

if __name__ == "__main__":
    if len(sys.argv) == 1:
        plugin_start_script = sys.argv[1]
    elif len(sys.argv) == 3:
        conda_env_name = sys.argv[1]
        plugin_start_script = sys.argv[2]
        plugin_src_dir = sys.argv[3]
    else:
        print("Incorrect number of arguments provided\nUsage: trigger.py <conda_env_name> <plugin_start_script> <plugin_src_dir>  <-- for use with conda\n  or   trigger.py <plugin_start_script>  <-- for use without conda\n", file=sys.stderr)
        exit(1)

    app = make_app()
    app.listen(5000)  # Server auf Port 5000 starten
    print("Server laeuft auf http://localhost:5000", file=sys.stderr)
    tornado.ioloop.IOLoop.current().start()
