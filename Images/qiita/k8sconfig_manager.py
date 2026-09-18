from os import environ
from functools import partial
from configparser import ConfigParser, Error

class MissingConfigSection(Error):
    """Exception when the config file is missing a required section"""

    def __init__(self, section):
        super(MissingConfigSection, self).__init__(
            "Missing section(s): %r" % (section,)
        )
        self.section = section
        self.args = (section,)

class K8SConfigurationManager(object):
    """Holds configuration to launch a qiita plugin via k8s.
    
    Parameters
    ----------
    conf_fp: str, optional
        Filepath to the configuration file. Default: /k8s_config.cfg
    
    Raises
    ------
    Error
        When an option is no longer available.    
    """
    def __init__(self):
        # If conf_fp is None, we default to the test configuration file
        try:
            conf_fp = environ["K8S_CONFIG_FP"]
        except KeyError:
            conf_fp = '/k8s_config.cfg'
        self.conf_fp = conf_fp

        # Parse the configuration file
        config = ConfigParser()
        with open(conf_fp, newline=None) as conf_file:
            config.read_file(conf_file)

        _required_sections = {"kubernetes"}
        if not _required_sections.issubset(set(config.sections())):
            missing = _required_sections - set(config.sections())
            raise MissingConfigSection(", ".join(missing))

        self._get_k8s(config)

    def _get_k8s(self, config):
        """
        Parse configutations for the kubernetes section. This will
        impact where and how future plugin jobs are run.
        """
        sec_get = partial(config.get, 'kubernetes')

        self.volume_mount_path = sec_get('VOLUME_MOUNT_PATH', fallback=None)
        self.volume_name = sec_get('VOLUME_NAME', fallback=None)
        self.pvc_name = sec_get('PVC_NAME', fallback=None)

        self.image_pull_policy = sec_get('IMAGE_PULL_POLICY', fallback='IfNotPresent')
        self.image_pull_secrets = sec_get('IMAGE_PULL_SECRETS', fallback=None)
        self.tag = sec_get('IMAGE_TAG', fallback='def')

        self.namespace = sec_get('NAMESPACE', fallback=None)

        