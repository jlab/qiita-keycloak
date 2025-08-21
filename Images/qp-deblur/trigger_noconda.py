import tornado.ioloop
import tornado.web
import json
import subprocess
from glob import glob
import sys
import traceback
import os

plugin_start_script = None

class RunCommandHandler(tornado.web.RequestHandler):
    def post(self):
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
            cmd = '%s %s %s %s' % (plugin_start_script, qiita_worker_url, job_id, output_dir)
            result = subprocess.run(cmd, shell=True, universal_newlines=True, executable='/bin/bash', stdout=subprocess.PIPE, stderr=subprocess.PIPE)

            # Antwort zurueckgeben
            self.write({
                "stdout": result.stdout,
                "stderr": result.stderr,
                "returncode": result.returncode,
                "cmd": cmd,
            })

        except Exception as e:
            self.set_status(500)
            # a hack to learn which docker service I am in
            plugin_name = os.path.basename(plugin_start_script).replace('start_', '')
            print("Error in service '%s': %s" % (plugin_name, str(e)), file=sys.stderr)
            traceback.print_exc()
            self.write({"error": str(e)})

class RunConfigHandler(tornado.web.RequestHandler):
  def get(self):
    try:
      for fp_config in glob('/unshared_plugins/*.conf'):
        with open(fp_config, 'r') as f:
          self.write('\n'.join(f.readlines()) + '\n')
    except Exception as e:
      self.set_status(500)
      self.write({"error": str(e)})

def make_app():
    return tornado.web.Application([
        (r"/run", RunCommandHandler),
        (r"/config", RunConfigHandler),
    ])

if __name__ == "__main__":
    plugin_start_script = sys.argv[1]

    app = make_app()
    app.listen(5000)  # Server auf Port 5000 starten
    print("Server laeuft auf http://localhost:5000", file=sys.stderr)
    tornado.ioloop.IOLoop.current().start()
