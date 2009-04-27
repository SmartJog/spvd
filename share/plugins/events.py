""" Fetches events from sjevents. """

from baseplugin import BasePlugin
from basejob import BaseJob
import time
from importer import Importer

PLUGIN_NAME = "events"

class Job(BaseJob):

    def __init__(self, logger, infos):
        BaseJob.__init__(self, logger, infos)
        self.importer = Importer()
        self.importer['distant_url'] = 'https://' + self.infos['address'] + '/exporter/'

    def get_last_errors(self):
        self.log('write last errors')
        try:
            events = self.importer.call('sjevents', 'get_events', status='ERROR')

            if len(events) > 0:
                self.infos['message'] = 'There are ERROR events'
                self.infos['status'] = 'ERROR'
            else:
                self.infos['message'] = 'No ERROR events'
                self.infos['status'] = 'OK'

            self.log('Got %d events in error.' % len(events))
            self.set_status('finished')
        except:
            self.infos['message'] = 'Importer error'
            self.set_status('error')

class Plugin(BasePlugin):

    def __init__(self, log, url=None):
        BasePlugin.__init__(self, PLUGIN_NAME, log, url)
        pass

    def create_new_job(self, job):
        return Job(self.logger, job)

