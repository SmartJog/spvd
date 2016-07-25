# -*- coding: utf-8 -*-

""" BasePlugin definitions. """

import logging
import threading
import traceback
import os
import Queue
from sjutils import threadpool

class BasePluginError(Exception):
    """ Raised by BasePlugin. """

    def __init__(self, error):
        """ Init method. """
        Exception.__init__(self, error)

class BasePlugin(threading.Thread):
    """ Base class for job implementation in spvd. """

    name = ''

    require = {
    }

    optional = {
        'debug': bool,
        'max_parallel_checks' : int,
        'max_checks_queue' : int,
        'check_poll' : int,
        'check_timeout' : int,
        'result_threshold' : int,
        'limit_group' : str,
        'limit_check' : str,
        'limit_commit' : int,
    }

    def __init__(self, options, event, params=None):
        """ Init method.

        @params is a dictionary of optional parameters among:
        max_parallel_checks:    maximum number of threads for this plugin.
        max_checks_queue:       maximum number of checks to get from
                                the DB and queue for execution.
        check_poll:             interval between two get_checks call.
        check_timeout:          maximum wait time for get_checks calls.
        debug:                  enable debugging information.
        result_threshold:       number of results waiting for a commit that
                                will trigger a main-loop wake up.
        """

        threading.Thread.__init__(self)
        self.setDaemon(True)
        self.dismiss    = event
        self.resqueue   = {}
        self.checks     = {}
        self.rescommit  = threading.Event()

        self.params = {
            'max_parallel_checks': 3,
            'max_checks_queue': 9,
            'check_poll': 60,
            'check_timeout' : None,
            'debug': False,
            'result_threshold': 5,
            'limit_group': None,
            'limit_check': None,
            'limit_commit': 40,
        }

        if params:
            self.params.update(params)

        # Limiting groups
        self.limit_group = None
        if self.params['limit_group']:
            self.limit_group = [group.strip() for group in self.params['limit_group'].split(",") if group.strip()]
            if len(self.limit_group) == 1:
                self.limit_group = self.limit_group[0]

        # Limiting checks
        self.limit_check = None
        if self.params['limit_check']:
            self.limit_check = [check.strip() for check in self.params['limit_check'].split(",") if check.strip()]
            if len(self.limit_check) == 1:
                self.limit_check = self.limit_check[0]

        self.options = options

        self.log = logging.getLogger("spvd.plugins." + self.name)

        # Set up logging
        if not self.options.nodaemon:
            log_dir = options.logdir + '/' + self.name
            if not os.path.exists(log_dir):
                os.mkdir(log_dir)
            log_handler = logging.FileHandler(log_dir + '/' + self.name + '.log')

            log_format = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
            log_handler.setFormatter(log_format)
            self.log.addHandler(log_handler)

            if self.params.get('debug', False):
                self.log.setLevel(logging.DEBUG)
            else:
                self.log.setLevel(logging.INFO)

            self.log.propagate = False

        # Finalize init
        self.job_pool = threadpool.ThreadPool(int(self.params['max_parallel_checks']))

        for widx, worker in enumerate(self.job_pool.workers):
            worker.setName('%s-#%d' % (self.name, widx))

        # Plugins or Subclasses must start Thread by themselves
        #self.start()
        #self.log.info(self)

    def __str__(self):
        return "<BasePlugin>"

    @staticmethod
    def __prepare_status_update(check):
        """ Prepare a structure for status update. """
        status = {
            'status_id'     : check['status']['status_id'],
            'sequence_id'   : check['status']['seq_id'],
            'status'        : check['status']['check_status'],
            'message'       : check['status']['check_message'],
            'status_infos'  : check['status']['status_infos'],
        }

        if 'status_infos' in check:
            status['status_infos'] = check['status_infos']

        return status

    def job_start(self, check):
        """ Starts a job. """

        job = self.create_new_job(check)
        job.log.debug('check started')
        self.log.debug('Work request #%s started.' % check['status']['status_id'])
        self.checks[check['status']['status_id']] = job
        return job.run()

    def job_stop(self, request, result):
        """ Stops a job. """

        self.checks[request.request_id].log.info('check result is %s : (%s)' % (result['status']['check_status'], result['status']['check_message']))
        self.log.debug('Work request #%s finished.' % request.request_id)

        update = self.__prepare_status_update(result)
        self.resqueue.update({result['status']['status_id']: update})

        if len(self.resqueue) > self.params['result_threshold']:
            self.rescommit.set()

        del self.checks[request.request_id]

    def handle_exception(self, request, exc_info):
        """ Handle exception in a job. """

        if not isinstance(exc_info, tuple):
            # Something is seriously wrong...
            self.log.critical('*** Worker thread raised an exception ***')
            self.log.critical(request)
            self.log.critical(exc_info)
            raise SystemExit

        self.log.error("Exception occured in request #%s: %s" % (request.request_id, exc_info))
        for line in traceback.format_exception(exc_info[0], exc_info[1], exc_info[2]):
            self.log.error(line)

    def run(self):
        """ Run method. """

        self.log.info("plugin started")
        first = True

        while not self.dismiss.isSet():

            try:
                if not first:
                    self.rescommit.wait(self.params['check_poll'])

                first = False

                self.log.debug('number of threads alive %d/%d' % (len([thread for thread in self.job_pool.workers if thread.isAlive()]), int(self.params['max_parallel_checks'])))
                self.log.debug('jobs waiting to be reported: %d' % len(self.resqueue))
                self.log.debug('jobs waiting to be executed: %d (approx)' % self.job_pool._requests_queue.qsize())

                try:
                    self.job_pool.poll()
                except threadpool.NoResultsPending:
                    self.log.debug('there was no result to poll')

                # Commit pending results
                if self.resqueue:
                    self.log.debug('%d results to commit' % len(self.resqueue))
                    self.commit_checks()

                # Determine maximum number of checks to get
                # Queue.qsize is unreliable, try to mitigate its weirdness
                limit_fetch = self.params['max_checks_queue'] - self.job_pool._requests_queue.qsize()
                limit_fetch = min(abs(limit_fetch), self.params['max_checks_queue'])

                # Determine if we need to fetch more work
                if self.job_pool._requests_queue.full() or limit_fetch == 0:
                    self.log.info('queue estimated full')
                    continue

                # Non sensical value or no check to fetch
                if limit_fetch > self.params['max_checks_queue'] \
                    or limit_fetch < 0:
                    self.log.info('*** Runtime inconsistency, trying to fetch %d checks ***' % limit_fetch)
                    continue

                # Get checks for the current plugin
                self.log.debug('*** fetching %s checks' % limit_fetch)
                checks = self.fetch_checks(limit_fetch)

                if not checks:
                    continue

                if checks.get('status', None) is None:
                    self.log.error('remote module did not return any work')
                    continue

                if len(checks['status']) > 0:
                    self.log.debug('got %s checks' % len(checks['status']))

                # Queue checks
                try:
                    for status in checks['status']:

                        req = threadpool.WorkRequest(
                            self.job_start,
                            [{
                                'check' : checks['checks'][status['chk_id']],
                                'group' : checks['groups'][status['grp_id']],
                                'object' : checks['objects'][str(status['obj_id'])],
                                'status' : status}],
                            None,
                            request_id=status['status_id'],
                            callback=self.job_stop,
                            exc_callback=self.handle_exception
                        )
                        self.job_pool.queue_request(req, self.params['check_poll'])
                        self.log.debug('Work request #%s added.' % req.request_id)
                except Queue.Full:
                    self.log.error("queue is full")
                    continue

            except Exception, error:
                self.log.error('caught unknown exception:')
                self.log.exception(error)
                continue

        self.log.info('dismissing workers')
        self.job_pool.dismiss_workers(int(self.params['max_parallel_checks']))

        # Do not join, takes time and results will not be written to database anyway
        self.log.info("plugin stopped")

    def create_new_job(self, _job):
        """ Dummy method. To be overridden in plugins. """

        raise BasePluginError('Plugin %s does not implement <create_new_job>' % self.name)

    def fetch_checks(self, _limit_fetch):
        """ Dummy method. To be overridden in plugins. """

        raise BasePluginError('Plugin %s does not implement <fetch_checks>' % self.name)

    def commit_checks(self):
        """ Dummy method. To be overridden in plugins. """

        raise BasePluginError('Plugin %s does not implement <commit_checks>' % self.name)

