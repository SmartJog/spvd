""" BaseJob class definitions. """

import logging
import traceback
import time
import os
import sys

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
        self.ident = "%s job_id=%s " % (self.infos['check']['plugin'], self.infos['status']['status_id'])

        self.log = logging.getLogger(self.infos['check']['plugin'] + '.' + self.infos['check']['plugin_check'] + '.' + str(self.infos['status']['status_id']))
        self.old_status = self.infos['status']['check_status']

        if options.nodaemon:
            self.log_handler = logging.StreamHandler(sys.stdout)
        else:
            log_dir = options.logdir + '/' + self.infos['check']['plugin']
            if os.path.exists(log_dir) is False:
                os.mkdir(log_dir)
            self.log_handler = logging.FileHandler(log_dir + '/' + self.infos['check']['plugin_check'] + '.log')

        ident = "%5s %s:%s %s %s : " % (
                "#" + str(self.infos['status']['status_id']),
                self.infos['check']['plugin'],
                self.infos['check']['plugin_check'],
                self.infos['group']['name'],
                self.infos['object']['address'])
        self.log_handler.setFormatter(logging.Formatter('%(asctime)s %(levelname)-8s ' + ident + '%(message)s'))
        self.log.addHandler(self.log_handler)

        if params.has_key('debug') and params['debug'] is True:
            self.log.setLevel(logging.DEBUG)
        else:
            self.log.setLevel(logging.INFO)

        self.log.propagate = 0

    def __del__(self):
        self.log.removeHandler (self.log_handler)
        self.log_handler.close()

    def set_check_status(self, check_status, check_message, status_infos=None):
        """ Helper function to prepare check's status. """

        if check_status not in self._valid_status:
            message = 'Job returned an invalid status <%s>' % check_status
            self.log.error(message)
            raise BaseJobRuntimeError(message)

        self.infos['status']['check_message'] = check_message
        self.infos['status']['check_status'] = check_status
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

        self.log.error(self.old_status + "   " +  self.infos['status']['check_status'])
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

