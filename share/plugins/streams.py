from baseplugin import BasePlugin
from basejob import BaseJob
import urllib2

PLUGIN_NAME = "streams"

class Job(BaseJob):

    def __init__(self, logger, infos, min_fetch=1024):
        BaseJob.__init__(self, logger, infos)

        self.min_fetch = int(min_fetch)
        self.url = self.infos['address']
        if self.url.startswith('mms://') or self.url.endswith('wmv') or self.url.endswith('wma'):
            self.kind = 'Windows'
        else:
            self.kind = 'Regular'

        if self.url.startswith('mms://'):
            self.url = 'http://' + self.url[6:]

    def get_stream(self):
        """ Check that a stream is reachable. """

        try:
            if self.kind == 'Windows':
                # Mimic mplayer behavior to some extent
                headers = {'Accept': '*/*',
                    'User-Agent': 'NSPlayer/4.1.0.3856',
                    'Pragma': 'xClientGUID={c77e7400-738a-11d2-9add-0020af0a3278}',
                    'Pragma': 'no-cache,rate=1.000000,stream-time=0,stream-offset=0:0,request-context=2,max-duration=0',
                    'Pragma': 'xPlayStrm=1',
                }
                request = urllib2.Request(self.url, None, headers)
                stream = urllib2.urlopen(request)
            else:
                stream = urllib2.urlopen(self.url)

            data = stream.read(self.min_fetch)

            if len(data) < self.min_fetch:
                self.infos['message'] = 'Could not get enough data, stream <%s> might be down' % self.url
                self.infos['status'] = 'ERROR'
                self.set_status('error')
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
        """ Init method of the streams plugin.

        @params is a dictionnary of optional parameters among:
        streams_min_fetch: minimum data to fetch to check if the sream is alive

        @see BasePlugin documentation
        """

        streams_params = { 'streams_min_fetch': 1024 }
        streams_params.update(params)

        BasePlugin.__init__(self, PLUGIN_NAME, log, url, streams_params)

    def create_new_job(self, job):
        return Job(self.logger, job, self.params['streams_min_fetch'])

