from baseplugin import BasePlugin
from basejob import BaseJob
import time

PLUGIN_NAME = "sample"

class Job(BaseJob):

    def __init__(self, logger, infos):
        BaseJob.__init__(self, logger, infos)

    def nothing(self):
        self.log('This check is doing nothing.')
        time.sleep(4)
        self.set_status('finished')

    def pierrot(self):
        self.log('Au clair de la lune.')
        self.set_status('finished')

class Plugin(BasePlugin):

    def __init__(self, log, url=None):
        BasePlugin.__init__(self, PLUGIN_NAME, log, url)
        pass

    def create_new_job(self, job):
        return Job(self.logger, job)

