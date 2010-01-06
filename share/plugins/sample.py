from baseplugin import BasePlugin
from basejob import BaseJob
import time
import logging

PLUGIN_NAME = "sample"

class Job(BaseJob):

    def __init__(self, log_dir, log_name, log_level, infos):
        BaseJob.__init__(self, log_dir, log_name, log_level, infos)

    # This method isn't called directly by a check but by another method inside
    # the plugin : its name MUST start with '_'.
    def _do_nothing(self):
        time.sleep(4)

    # This method is called by a check.
    def nothing(self):
        self.log.info('This check is doing nothing.')
        self._do_nothing()
        self.infos['status'] = 'FINISHED'

    # This method is called by a check.
    def pierrot(self):
        self.log.info('Au clair de la lune.')
        self.infos['status'] = 'FINISHED'

class Plugin(BasePlugin):

    # This dict defines the mandatory options to be configured to use this plugin.
    # Its form is : require = { 'option1_name' : option1_type, ... }
    require = { }

    # This dict defines the optional options of this plugin.
    # Its form is : optional = {'option1_name' : option1_type, ... }
    optional = { }

    def __init__(self, log_dir, log_name, log_level, event, url=None, params=None):
        BasePlugin.__init__(self, PLUGIN_NAME, log_dir, log_name, log_level, event, url, params)

    def create_new_job(self, job):
        return Job(self.log_dir, self.log_name, self.log_level, job)
