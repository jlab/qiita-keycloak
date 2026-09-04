import os
import sys
import requests
import json

from kubernetes import client, config
from kubernetes.client.rest import ApiException

from k8sconfig_manager import K8SConfigurationManager


def start_plugin_docker(pluginname, qiita_server_url, job_id, output_dir):
    PORT = 5000
    API_ENDPOINT = "run"

    req = requests.post(
        'http://%s%s-1:%s/%s' % ('tinqiita-', pluginname, PORT, API_ENDPOINT),
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


def start_plugin_k8s(pluginname, qiita_server_url, job_id, output_dir):
    # load k8s qiita specific setting from file /k8s_config.cfg
    k8s_config = K8SConfigurationManager()

    # load cluster config to connect from pod to Kubernetes API
    # from docs "function handles API host discovery and authentication
    # automatically"
    config.load_incluster_config()

    # create API client
    v1 = client.BatchV1Api()
    podname = f"{pluginname}-{job_id}"

    # create pod object
    # set name and label of pod + set image and name of container
    container=client.V1Container(
        name=podname, 
        image=f"harbor.computational.bio.uni-giessen.de/tinqiita/{pluginname}:{k8s_config.tag}",
        image_pull_policy=k8s_config.image_pull_policy,
        args=[f"start_{pluginname}", f"{qiita_server_url}", f"{job_id}", f"{output_dir}"],
        volume_mounts=[client.V1VolumeMount(mount_path=k8s_config.volume_mount_path, name=k8s_config.volume_name)],
        env=[client.V1EnvVar(name='QIITA_PLUGINCOUPLING', value='filesystem')])
    pod = client.V1PodTemplateSpec(
        metadata=client.V1ObjectMeta(name=podname, labels={"app": f"{pluginname}"}),
        spec=client.V1PodSpec(
            containers=[container],
            restart_policy="Never",
            image_pull_secrets=[client.V1LocalObjectReference(name=k8s_config.image_pull_secrets)],
            volumes=[client.V1Volume(name=k8s_config.volume_name, persistent_volume_claim=client.V1PersistentVolumeClaimVolumeSource(claim_name=k8s_config.pvc_name))]
        )
    )

    job = client.V1Job(
        api_version="batch/v1",
        metadata=client.V1ObjectMeta(name=podname),
        kind="Job",
        spec=client.V1JobSpec(
            template=pod,
            backoff_limit=0
        )
    )
    v1.create_namespaced_job(namespace=k8s_config.namespace, body=job)
    print(f"k8s job {podname} created.")


if __name__ == "__main__":
    pluginname, qiita_server_url, job_id, output_dir = sys.argv[1:]

    fct_start_plugin = start_plugin_docker
    # a hacky? mechanism to check if this container is executed within a
    # kubernetes cluster
    if os.getenv('KUBERNETES_SERVICE_HOST', None) is not None:
        fct_start_plugin = start_plugin_k8s

    fct_start_plugin(pluginname, qiita_server_url, job_id, output_dir)
