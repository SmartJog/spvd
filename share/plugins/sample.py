from baseplugin import BasePlugin
from basejob import BaseJob
import time
import logging

PLUGIN_NAME = "sample"

class Job(BaseJob):

    def __init__(self, log_name, infos):
        BaseJob.__init__(self, log_name, infos)

    def nothing(self):
        logging.getLogger(log_name + '.' + 'nothing').info('This check is doing nothing.')
        time.sleep(4)
        self.infos['status'] = 'FINISHED'

    def pierrot(self):
        logging.getLogger(log_name + '.' + 'pierrot').info('Au clair de la lune.')
        self.infos['status'] = 'FINISHED'

class Plugin(BasePlugin):

    require = { }
    optional = { }

    def __init__(self, log_name, event, url=None, params=None):
        BasePlugin.__init__(self, PLUGIN_NAME, log_name, event, url, params)

    def create_new_job(self, job):
        return Job(self.log_name, job)
