# -*- coding: utf-8 -*-

""" BaseJob class definitions. """

from __future__ import with_statement

import logging
import traceback
import time
import os
import sys
import threading
try:
    from logging import LoggerAdapter
except ImportError:
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

    class BaseError(Exception):
        """ Base class for BaseJob Exceptions. """

        def __init__(self, error):
            """ Init method. """
            Exception.__init__(self, error)

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
        with __handler_lock__:
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

        self.log.warning('This module is using [set_check_status] which is deprecated.'
            ' Please upgrade it or fill a bug report if an update does not exist.')

        if check_status not in self._valid_status:
            message = 'Job returned an invalid status <%s>' % check_status
            self.log.error(message)
            raise BaseJob.BaseError(message)

        self.infos['status']['check_message'] = check_message
        self.infos['status']['check_status'] = check_status
        if status_infos:
            self.infos['status']['status_infos'].update(status_infos)

    def run(self):
        """ Starts the job implemented by this plugin. """

        status, message = '', ''
        try:
            status, message = self.go()

        except TypeError, error:
            # Transitional catch
            self.log.warning('This module is not returning its status like it should.'
                ' This is a deprecated behavior.'
                ' Please upgrade it or fill a bug report if an update does not exist.')

        except (BaseJob.BaseError, BaseJobRuntimeError), error:
            # Expected exception, nothing to worry about
            self.log.error(str(error))
            status, message = 'ERROR', str(error)

        except Exception, error:
            # Unexpected exception, should log a traceback
            self.log.critical('Fatal error: job stopped')
            self.log.critical(traceback.format_exc())
            status, message = 'ERROR', str(error)

        if status not in self._valid_status:
            status, message = 'ERROR', 'Job returned an invalid status <%s>' % status
            self.log.error(message)

        self.infos['status']['check_message'] = message
        self.infos['status']['check_status'] = status

        if self.infos['check']['check_infos'].get('history', False) == 'true' and self.old_status != self.infos['status']['check_status']:
            self.log.debug('Saving new history checkpoint: ' + str(self.old_status) + " -> " +  str(self.infos['status']['check_status']))
            self.infos['status']['status_infos'].update({'history-%d-%s' % (int(time.time()),  self.infos['status']['check_status'].lower()): self.infos['status']['check_message']})

        return self.infos

    def go(self):
        """ Calls specific check in BaseJob class of the plugin. """

        if hasattr(self, self.infos['check']['plugin_check']):
            return getattr(self, self.infos['check']['plugin_check'])()
        else:
            message = 'Job does not implement <%s> method' % self.infos['check']['plugin_check']
            raise BaseJob.BaseError(message)

