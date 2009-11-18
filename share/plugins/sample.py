from baseplugin import BasePlugin
from basejob import BaseJob
import time

PLUGIN_NAME = "sample"

class Job(BaseJob):

    def __init__(self, logger, infos):
        BaseJob.__init__(self, logger, infos)

    def nothing(self):
        self.log('nothing', 'This check is doing nothing.')
        time.sleep(4)
        self.infos['status'] = 'FINISHED'

    def pierrot(self):
        self.log('pierrot', 'Au clair de la lune.')
        self.infos['status'] = 'FINISHED'

class Plugin(BasePlugin):

    def __init__(self, log, event, url=None, params=None):
        BasePlugin.__init__(self, PLUGIN_NAME, log, event, url, params)

    def create_new_job(self, job):
        return Job(self.logger, job)

