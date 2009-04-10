""" BaseJob class definitions. """

import sys
import threading
import traceback

from baseplugin import BasePlugin

def print_traceback(log):
    traceback.print_exc(file=log._file)
    traceback.print_exc(file=sys.stdout)

class DefaultDict(dict):
    """ Dictionary with a default value for a missing key.

    Trivial DefaultDict implementation. Basically returns the default valuei
    for missing keys.

    TODO: Python2.5 has __missing__ for dict subclasses, we should use
    this (or collections.defaultdict) instead when switching to 2.5"""

    def __init__(self, default = None, *args, **kw):
        """ Init method. """

        dict.__init__(self, *args, **kw)
        self.default = default

    def __getitem__(self, key):
        """ Get an item of the dictionary. """

        return self.get(key, self.default)


class BaseJob(threading.Thread):
    """ Base class for job implementation in spvd. """

    class RuntimeError(Exception):
        def __init__(self, error):
            Exception.__init__(self, error)

    def __init__(self, logger, infos):
        """ Init method. """

        threading.Thread.__init__(self)
        self.infos = infos
        self.logger = logger
        self.finished = False
        self.error = False
        self.setDaemon(True)
        self.ident = "%s job_id=%s " % (self.infos['plugin'], self.infos['job_id'])
        self.log("Job created")

    def run(self):
        """ Starts the job implemented by this plugin. """

        try:
            self.log("Job started")
            try:
                self.go()
            except Exception, e:
                self.log("Job returned an error: %s " % (str(e)))
                print_traceback(self.logger)
                self.infos['description'] = str(e)
                self.infos['status'] = 'ERROR'
                return

            self.log("Job finished")
        except Exception:
            self.log('Fatal error: job stopped')
            print_traceback(self.logger)

    def set_status(self, status):
        """ Set status of the job. """

        if status == 'finished':
            self.finished = True
            self.error = False
        elif status == 'error':
            self.finished = False
            self.error = True
        else:
            raise BaseJob.RuntimeError("Job finished with an unknown status: %s" % status)

    def log(self, message):
        """ Custom logging method. """

        self.logger.write(self.ident + message)

