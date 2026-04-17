import tornado.ioloop
import tornado.web
import json
import subprocess
from glob import glob
import sys

conda_env_name = None
plugin_start_script = None
plugin_src_dir = None


class RunCommandHandler(tornado.web.RequestHandler):
    def post(self):
        try:
            data = json.loads(self.request.body)
            qiita_worker_url = data.get('url')
            job_id = data.get('job_id')
            output_dir = data.get('output_dir')

            if not qiita_worker_url or not job_id or not output_dir:
                self.set_status(400)
                self.write({"error": "Kein Befehl angegeben"})
                return

            cmd = (
                'source /opt/conda/etc/profile.d/conda.sh; '
                'conda activate /opt/conda/envs/%s; '
                '%s/scripts/%s %s %s %s'
            ) % (
                conda_env_name,
                plugin_src_dir,
                plugin_start_script,
                qiita_worker_url,
                job_id,
                output_dir,
            )
            result = subprocess.run(
                cmd,
                shell=True,
                capture_output=True,
                text=True,
                executable='/bin/bash',
            )

            self.write(
                {
                    "stdout": result.stdout,
                    "stderr": result.stderr,
                    "returncode": result.returncode,
                    "cmd": cmd,
                }
            )

        except Exception as e:
            self.set_status(500)
            plugin_name = "unknown"
            for f in glob('/start_*.sh'):
                plugin_name = f.split('_')[-1].replace('.sh', '')
                break
            print("Error in service '%s': %s" % (plugin_name, str(e)), file=sys.stderr)
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
    return tornado.web.Application(
        [
            (r"/run", RunCommandHandler),
            (r"/config", RunConfigHandler),
        ]
    )


if __name__ == "__main__":
    conda_env_name = sys.argv[1]
    plugin_start_script = sys.argv[2]
    plugin_src_dir = sys.argv[3]

    app = make_app()
    app.listen(5000)
    print("Server laeuft auf http://localhost:5000", file=sys.stderr)
    tornado.ioloop.IOLoop.current().start()
