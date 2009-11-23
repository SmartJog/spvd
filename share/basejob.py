""" BaseJob class definitions. """

import logging
import traceback


class BaseJobRuntimeError(Exception):
    """ BaseJob Exceptions. """

    def __init__(self, error):
        """ Init method. """
        Exception.__init__(self, error)


class BaseJob:
    """ Base class for job implementation in spvd. """

    def __init__(self, log_name, infos):
        """ Init method. """

        self.infos = infos
        self.log_name = log_name
        self.ident = "%s job_id=%s " % (self.infos['plugin'], self.infos['status_id'])

    def run(self):
        """ Starts the job implemented by this plugin. """

        try:
            self.go()

        except Exception, error:
            logging.getLogger(self.log_name).critical('Fatal error: job stopped')
            logging.getLogger(self.log_name).critical(traceback.format_exc())
            self.infos['description'] = str(error)
            self.infos['status'] = 'ERROR'

        return self.infos

    def go(self):
        """ Calls specific check in BaseJob class of the plugin. """

        if hasattr(self, self.infos['plugin_check']):
            getattr(self, self.infos['plugin_check'])()
        else:
            message = 'Job does not implement <%s> method' % self.infos['plugin_check']

            self.infos['message'] = message
            self.infos['status'] = 'ERROR'

            logging.getLogger(self.log_name).error(message)
            raise BaseJobRuntimeError(message)

