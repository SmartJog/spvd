from baseplugin import BasePlugin
from basejob import BaseJob

PLUGIN_NAME = "sample"

class Job(BaseJob):

    def __init__(self, logger, infos):
        BaseJob.__init__(self, logger, infos)

    def go(self):
        self.log('Sample plugin online !')

class Plugin(BasePlugin):

    def __init__(self, log):
        BasePlugin.__init__(self, PLUGIN_NAME, log)
        pass

    def createNewJob(self, job):
        return  Job(self.logger, job)

