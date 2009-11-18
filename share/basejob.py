""" BaseJob class definitions. """

import traceback


class BaseJobRuntimeError(Exception):
    """ BaseJob Exceptions. """

    def __init__(self, error):
        """ Init method. """
        Exception.__init__(self, error)


class BaseJob:
    """ Base class for job implementation in spvd. """

    def __init__(self, logger, infos):
        """ Init method. """

        self.infos = infos
        self.logger = logger
        self.ident = "%s job_id=%s " % (self.infos['plugin'], self.infos['status_id'])

    def run(self):
        """ Starts the job implemented by this plugin. """

        try:
            self.go()

        except Exception, error:
            self.log('%BASIC%', 'Fatal error: job stopped')
            self.log('%BASIC%', traceback.format_exc())
            self.infos['description'] = str(error)
            self.infos['status'] = 'ERROR'

        return self.infos

    def log(self, target, message):
        """ Custom logging method. """

        self.logger.log(target, self.ident + message)

    def go(self):
        """ Calls specific check in BaseJob class of the plugin. """

        if hasattr(self, self.infos['plugin_check']):
            getattr(self, self.infos['plugin_check'])()
        else:
            message = 'Job does not implement <%s> method' % self.infos['plugin_check']

            self.infos['message'] = message
            self.infos['status'] = 'ERROR'

            self.log('%BASIC%', message)
            raise BaseJobRuntimeError(message)

