""" BaseJob class definitions. """

import logging
import traceback
import time
import os
import sys
import threading
from sjutils.loggeradapter import LoggerAdapter

# Adding handlers to loggers is not thread-safe *AT ALL*.
# This lock is used to protect multiple accesses to the "logger.handlers"
# variable below
__handler_lock__ = threading.Lock()


class BaseJobRuntimeError(Exception):
    """ BaseJob Exceptions. """

    def __init__(self, error):
        """ Init method. """
        Exception.__init__(self, error)


class BaseJob:
    """ Base class for job implementation in spvd. """

    _valid_status = ('FINISHED', 'WARNING', 'ERROR')

    def __init__(self, options, infos, params):
        """ Init method. """

        self.infos = infos

        self.old_status = self.infos['status']['check_status']
        self.old_status_infos = self.infos['status']['status_infos']
        self.infos['status']['status_infos'] = {}

        logger_per_job = logging.getLogger("spvd.jobs.%s.%s" % (self.infos['check']['plugin'],
                                                                self.infos['check']['plugin_check']))

        if options.nodaemon:
            logger = logging.getLogger("spvd.jobs")
        else:
            logger = logger_per_job

        # critical section around logger.handlers
        global __handler_lock__
        __handler_lock__.acquire()
        if len(logger.handlers) == 0:
            if options.nodaemon:
                log_handler = logging.StreamHandler(sys.stdout)
            else:
                log_dir = options.logdir + '/' + self.infos['check']['plugin']
                if os.path.exists(log_dir) is False:
                    os.mkdir(log_dir)
                log_file = "%s/%s.log" % (log_dir, self.infos['check']['plugin_check'])
                log_handler = logging.FileHandler(log_file)

            formatter_string = '%(asctime)s %(levelname)-8s %(statusid)5s ' + \
                               '%(plugin)s:%(check)s %(group)s %(object)s : %(message)s'
            log_handler.setFormatter(logging.Formatter(formatter_string))
            logger.addHandler(log_handler)

            if params.get('debug', False):
                logger.setLevel(logging.DEBUG)
            else:
                logger.setLevel(logging.INFO)

            logger.propagate = False
        # end of critical section
        __handler_lock__.release()

        # Jobs will always use logger_per_job here, even in nodaemon mode,
        # since "spvd.jobs" will trap all log messages in that case.
        self.log = LoggerAdapter(logger_per_job, {
            'plugin':   self.infos['check']['plugin'],
            'check':    self.infos['check']['plugin_check'],
            'statusid': "#" + str(self.infos['status']['status_id']),
            'group':    self.infos['group']['name'],
            'object':   self.infos['object']['address']})

    def set_check_status(self, check_status, check_message, status_infos=None):
        """ Helper function to prepare check's status. """

        if check_status not in self._valid_status:
            message = 'Job returned an invalid status <%s>' % check_status
            self.log.error(message)
            raise BaseJobRuntimeError(message)

        self.infos['status']['check_message'] = check_message
        self.infos['status']['check_status'] = check_status
        if status_infos:
            self.infos['status']['status_infos'].update(status_infos)

    def run(self):
        """ Starts the job implemented by this plugin. """

        try:
            self.go()

        except Exception, error:
            self.log.critical('Fatal error: job stopped')
            self.log.critical(traceback.format_exc())
            self.infos['status']['check_message'] = str(error)
            self.infos['status']['check_status'] = 'ERROR'

        self.log.error(str(self.old_status) + "   " +  str(self.infos['status']['check_status']))
        if self.infos['check']['check_infos'].get('history', False) == 'true' and self.old_status != self.infos['status']['check_status']:
            self.log.debug('Saving new history checkpoint')
            self.infos['status']['status_infos'].update({'history-%d-%s' % (int(time.time()),  self.infos['status']['check_status'].lower()): self.infos['status']['check_message']})

        return self.infos

    def go(self):
        """ Calls specific check in BaseJob class of the plugin. """

        if hasattr(self, self.infos['check']['plugin_check']):
            getattr(self, self.infos['check']['plugin_check'])()
        else:
            message = 'Job does not implement <%s> method' % self.infos['check']['plugin_check']

            self.infos['status']['check_message'] = message
            self.infos['status']['check_status'] = 'ERROR'

            self.log.error(message)
            raise BaseJobRuntimeError(message)

