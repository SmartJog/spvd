from baseplugin import BasePlugin
from basejob import BaseJob
import urllib2
from lxml.etree import ElementTree

PLUGIN_NAME = "streams"

class Job(BaseJob):

    def __init__(self, logger, infos):
        BaseJob.__init__(self, logger, infos)
        self.url = self.infos['address']

    def get_stream(self):
        """ Check that a stream is reachable. """

        # All stream have a corresponding asx playlist
        if not self.url.endswith('asx'):
            self.url = self.url[0:-3] + 'asx'

        try:
            urls = []
            playlist = urllib2.urlopen(self.url)
            tree = ElementTree()
            parser = tree.parse(playlist)

            # Extract all urls from playlist
            for ref in parser.xpath('//ref'):
                url = ref.get('href')

                if url.startswith('mms://'):
                    url = 'http://' + url[6:]

                if url not in urls:
                    urls.append(url)

            # Check connectivity of each stream
            for url in urls:
                stream = urllib2.urlopen(url)
                data = stream.read(100)

                if len(data) < 100:
                    self.infos['message'] = 'Could not get enough data, stream <%s> might be down' % url
                    self.infos['status'] = 'ERROR'
                    self.set_status('error')
                    break
            else:
                self.infos['message'] = 'Stream OK'
                self.infos['status'] = 'FINISHED'
                self.set_status('finished')

        except urllib2.URLError, error:
            self.infos['message'] = 'URLError: <' + str(error) + '>'
            self.infos['status'] = 'ERROR'
            self.set_status('error')


class Plugin(BasePlugin):

    def __init__(self, log, url=None, params=None):
        BasePlugin.__init__(self, PLUGIN_NAME, log, url, params)

    def create_new_job(self, job):
        return Job(self.logger, job)

