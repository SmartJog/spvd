""" BaseJob class definitions. """

import sys
import threading
import traceback


def print_traceback(log):
    traceback.print_exc(file=log._file)
    traceback.print_exc(file=sys.stdout)


class BaseJobRuntimeError(Exception):
    """ BaseJob Exceptions. """

    def __init__(self, error):
        """ Init method. """
        Exception.__init__(self, error)


class BaseJob(threading.Thread):
    """ Base class for job implementation in spvd. """

    def __init__(self, logger, infos):
        """ Init method. """

        threading.Thread.__init__(self)
        self.infos = infos
        self.logger = logger
        self.finished = False
        self.error = False
        self.setDaemon(True)
        self.ident = "%s job_id=%s " % (self.infos['plugin'], self.infos['status_id'])
        self.log("Job created")

    def run(self):
        """ Starts the job implemented by this plugin. """

        try:
            self.log("Job started")
            try:
                self.go()
            except Exception, error:
                self.log("Job returned an error: %s " % (str(error)))
                print_traceback(self.logger)
                self.infos['description'] = str(error)
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
            raise BaseJobRuntimeError("Job finished with an unknown status: %s" % status)

    def log(self, message):
        """ Custom logging method. """

        self.logger.write(self.ident + message)

    def go(self):
        """ Calls specific check in BaseJob class of the plugin. """

        if hasattr(self, self.infos['plugin_check']):
            exec ('self.' + self.infos['plugin_check'] + '()')
        else:
            message = 'Job does not implement <%s> method' % self.infos['plugin_check']

            self.infos['message'] = message
            self.infos['status'] = 'ERROR'
            self.set_status('error')

            self.log(message)
            raise BaseJobRuntimeError(message)

