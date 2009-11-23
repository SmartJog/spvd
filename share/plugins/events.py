""" Fetches events from sjevents. """

from baseplugin import BasePlugin
from basejob import BaseJob
from importer import Importer

import logging

PLUGIN_NAME = "events"

class Job(BaseJob):

    def __init__(self, log_name, infos):
        BaseJob.__init__(self, log_name, infos)
        self.importer = Importer()
        self.importer['distant_url'] = 'https://' + self.infos['address'] + '/exporter/'

    def get_last_errors(self):
        logging.getLogger(log_name + '.' + 'get_last_errors').info('write last errors')
        try:
            events = self.importer.call('sjevents', 'get_events', status='ERROR')

            if len(events) > 0:
                self.infos['message'] = 'There are ERROR events'
                self.infos['status'] = 'ERROR'
            else:
                self.infos['message'] = 'No ERROR events'
                self.infos['status'] = 'OK'

            logging.getLogger(log_name + '.' + 'get_last_errors').info('Got %d events in error.' % len(events))
        except Exception, error:
            self.infos['message'] = 'Importer error <' + str(error) + '>'
            self.infos['status'] = 'ERROR'

class Plugin(BasePlugin):

    require = { }
    optional = { }
    checks = [ 'get_last_errors' ]

    def __init__(self, log_name, event, url=None, params=None):
        BasePlugin.__init__(self, PLUGIN_NAME, log_name, event, url, params)

    def create_new_job(self, job):
        return Job(self.logger, job)

