""" Fetches events from sjevents. """

from baseplugin import BasePlugin
from basejob import BaseJob
from importer import Importer

PLUGIN_NAME = "events"

class Job(BaseJob):

    def __init__(self, logger, infos):
        BaseJob.__init__(self, logger, infos)
        self.importer = Importer()
        self.importer['distant_url'] = 'https://' + self.infos['address'] + '/exporter/'

    def get_last_errors(self):
        self.log('get_last_errors', 'write last errors')
        try:
            events = self.importer.call('sjevents', 'get_events', status='ERROR')

            if len(events) > 0:
                self.infos['message'] = 'There are ERROR events'
                self.infos['status'] = 'ERROR'
            else:
                self.infos['message'] = 'No ERROR events'
                self.infos['status'] = 'OK'

            self.log('get_last_errors', 'Got %d events in error.' % len(events))
        except Exception, error:
            self.infos['message'] = 'Importer error <' + str(error) + '>'
            self.infos['status'] = 'ERROR'

class Plugin(BasePlugin):

    require = { }
    optional = { }

    def __init__(self, log, event, url=None, params=None):
        BasePlugin.__init__(self, PLUGIN_NAME, log, event, url, params)

    def create_new_job(self, job):
        return Job(self.logger, job)

