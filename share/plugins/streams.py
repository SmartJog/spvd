from baseplugin import BasePlugin
from basejob import BaseJob
import time
import urllib2
from lxml.etree import ElementTree

PLUGIN_NAME = "streams"

class Job(BaseJob):

    def __init__(self, logger, infos):
        BaseJob.__init__(self, logger, infos)
        self.url = self.infos['address']

    def get_stream(self):
        """ Check that a stream is reachable. """

        try:
            stream = urllib2.urlopen(self.url)
            tree = ElementTree()

            tree = ElementTree.parse(stream)
            for outline in tree.findall("//outline"):
              print outline.get('xmlUrl') 

            if pl[0]
            if stream.readline() = '<asx version="3.0">':
                for atom in stream.readlines():
                    if atom.strip().startswith('<ref href'):
                        url = 
                        urls.append()

            for url in urls:

            if len(data) == 100:
                self.infos['message'] = 'Stream OK'
                self.infos['status'] = 'FINISHED'
                self.set_status('finished')
            else:
                self.infos['message'] = 'Could not get enough data, stream might be down'
                self.infos['status'] = 'ERROR'
                self.set_status('error')

        except URLError, error:
            self.infos['message'] = 'URLError: <' + str(error) + '>'
            self.infos['status'] = 'ERROR'
            self.set_status('error')


class Plugin(BasePlugin):

    def __init__(self, log, url=None, params=None):
        BasePlugin.__init__(self, PLUGIN_NAME, log, url, params)
        pass

    def create_new_job(self, job):
        return Job(self.logger, job)

