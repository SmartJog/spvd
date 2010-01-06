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

    def __init__(self, log_dir, log_name, log_level, infos):
        """ Init method. """

        self.infos = infos
        self.log_name = log_name
        self.log_level = log_level
        self.ident = "%s job_id=%s " % (self.infos['plugin'], self.infos['status_id'])

        self.log = logging.getLogger(self.log_name + '.' + self.infos['plugin'] + '.' + self.infos['plugin_check'])
        self.log_handler = logging.FileHandler(log_dir + self.infos['plugin_check'] + '.log')
        self.log_handler.setFormatter(logging.Formatter('%(asctime)s %(levelname)s ' + ("#%5s " % str(self.infos['status_id'])) + '%(message)s'))
        self.log.addHandler(self.log_handler)

        self.log.propagate = 0
        self.log.setLevel(self.log_level)

    def __del__(self):
        self.log.removeHandler (self.log_handler)
        self.log_handler.close()

    def run(self):
        """ Starts the job implemented by this plugin. """

        try:
            self.go()

        except Exception, error:
            self.log.critical('Fatal error: job stopped')
            self.log.critical(traceback.format_exc())
            self.infos['message'] = str(error)
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

            self.log.error(message)
            raise BaseJobRuntimeError(message)

