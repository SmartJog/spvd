""" BasePlugin definitions. """

import threading
import traceback
import Queue
from importer import Importer, ImporterError
from sjutils import threadpool

class BasePluginError(Exception):
    """ Raised by BasePlugin. """

    def __init__(self, error):
        """ Init method. """
        Exception.__init__(self, error)

class BasePlugin(threading.Thread):
    """ Base class for job implementation in spvd. """


    def __init__(self, name, logger, event, url=None, params=None):
        """ Init method.

        @url: url pass to Importer.

        @params is a dictionnary of optional parameters among:
        importer_retry_timeout: interval between successive importer calls if
                                importer failed.
        max_parallel_checks:    maximum number of threads for this plugin.
        max_checks_queue:       maximum number of checks to get from
                                the DB and queue for execution.
        check_poll:             interval between two get_checks call.
        debug:                  enable debugging information.
        ssl_cert:               client X.509 public key.
        ssl_key:                client X.509 secret key.
        result_threshold:       number of results waiting for a commit that
                                will trigger a main-loop wake up.
        """

        threading.Thread.__init__(self)
        self.setDaemon(True)
        self.name       = name
        self.logger     = logger
        self.dismiss    = event
        self.resqueue   = {}
        self.rescommit  = threading.Event()

        self.params     = { 'importer_retry_timeout': 10,
                            'max_parallel_checks': 3,
                            'max_checks_queue': 9,
                            'check_poll': 1,
                            'debug': False,
                            'ssl_cert': None,
                            'ssl_key': None,
                            'result_threshold': 5,
                        }

        if params:
            self.params.update(params)

        self.importer   = Importer()
        if url:
            self.importer['distant_url'] = url

        if self.params['ssl_cert'] and self.params['ssl_key']:
            self.importer['ssl_cert'] = self.params['ssl_cert']
            self.importer['ssl_key'] = self.params['ssl_key']

        self.job_pool = threadpool.ThreadPool(int(self.params['max_parallel_checks']))

        self.start()
        self.log('%BASIC%', self)

    def __str__(self):
        return "<BasePlugin name=%s ssl=%s url=%s>" % (self.name, \
            (self.params['ssl_cert'] and self.params['ssl_key']) and \
            "on" or "off", self.importer['distant_url'] or "localhost")

    def log(self, target, message):
        """ Custom logging method. """
        self.logger.log(target, message)

    @staticmethod
    def __prepare_status_update(check):
        """ Prepare a structure for status update. """
        status = {'status_id': check['status_id'],
            'sequence_id': check['seq_id'],
            'status': check['status'],
            'message': check['message'],
        }

        return status

    def job_start(self, check):
        """ Starts a job. """

        check['plugin'] = self.name
        job = self.create_new_job(check)

        if self.params['debug']:
            self.log(check['plugin_check'], 'check %s started' % check['status_id'])

        return job.run()

    def job_stop(self, request, result):
        """ Stops a job. """

        if self.params['debug']:
            self.log(result['plugin_check'], 'request #%s: check result is %s' % (request.request_id, result['check_message']))

        if 'message' not in result:
            result['message'] = 'No message'

        update = self.__prepare_status_update(result)
        self.resqueue.update({result['status_id']: update})

        if self.params['debug']:
            self.log(result['plugin_check'], 'request #%s: check terminated' % request.request_id)

        if len(self.resqueue) > self.params['result_threshold']:
            self.rescommit.set()

    def handle_exception(self, request, exc_info):
        """ Handle exception in a job. """

        if not isinstance(exc_info, tuple):
            # Something is seriously wrong...
            self.log('%BASIC%', '*** Worker thread raised an exception ***')
            self.log('%BASIC%', request)
            self.log('%BASIC%', exc_info)
            raise SystemExit

        self.log(request.args[0]['plugin_check'], "*** Exception occured in request #%s: %s" % \
            (request.request_id, exc_info))
        for line in traceback.format_exception(exc_info[0], exc_info[1], exc_info[2]):
            self.log(request.args[0]['plugin_check'], line)

    def run(self):
        """ Run method. """

        try:
            self.log('%BASIC%', "plugin started")

            while not self.dismiss.isSet():

                self.rescommit.wait(self.params['check_poll'])

                self.log('%BASIC%', 'number of threads alive %d' % threading.activeCount())
                self.log('%BASIC%', 'approximate number of jobs in queue %d' % self.job_pool._requests_queue.qsize())

                try:
                    self.job_pool.poll()
                except threadpool.NoResultsPending:
                    self.log('%BASIC%', 'there was no result to poll')

                # Queue.qsize is unreliable, try to mitigate its weirdness
                limit_fetch = self.params['max_checks_queue'] - self.job_pool._requests_queue.qsize()
                limit_fetch = min(abs(limit_fetch), self.params['max_checks_queue'])

                if self.job_pool._requests_queue.full() \
                    or limit_fetch > self.params['max_checks_queue'] \
                    or limit_fetch == 0:
                    # Non sensical value or no check to fetch
                    self.log('%BASIC%', 'queue estimated full')
                    continue

                if self.resqueue:
                    self.log('%BASIC%', '%d results to commit' % len(self.resqueue))
                    # Try to commit results in queue
                    try:
                        self.importer.call('spv', 'set_checks_status', self.resqueue.values())
                        self.resqueue = {}
                        self.rescommit.clear()
                    except ImporterError, error:
                        self.log('%BASIC%', 'remote module error while commiting updates <' + str(error) + '>')

                # Get checks for the current plugin
                checks = {}
                self.log('%BASIC%', '*** fetching %s checks' % limit_fetch)

                try:
                    checks = self.importer.call('spv', 'get_checks',
                        limit=limit_fetch,
                        plugins=[self.name])
                except ImporterError, error:
                    self.log('%BASIC%', 'remote module error while retrieving checks <' + str(error) + '>')
                    self.dismiss.wait(self.params['importer_retry_timeout'])

                self.log('%BASIC%', 'got %s checks' % len(checks))

                try:
                    for status_id, check in checks.iteritems():
                        req = threadpool.WorkRequest(
                            self.job_start,
                            [check],
                            None,
                            request_id=status_id,
                            callback=self.job_stop,
                            exc_callback=self.handle_exception
                        )
                        self.job_pool.queue_request(req, self.params['check_poll'])
                        if self.params['debug']:
                            self.log(check['plugin_check'], 'Work request #%s added.' % req.request_id)
                except Queue.Full:
                    self.log('%BASIC%', "queue is full")
                    continue

        except Exception:
            self.log('%BASIC%', 'fatal error: plugin stopped')
            self.log('%BASIC%', traceback.print_exc())

        self.log('%BASIC%', 'dismissing workers')
        self.job_pool.dismiss_workers(int(self.params['max_parallel_checks']))

        # Do not join, takes time and results will not be written to database anyway
        self.log('%BASIC%', "plugin stopped")

    def create_new_job(self, job):
        """ Dummy method. To be overridden in plugins. """

        raise BasePluginError('Plugin %s does not implement <create_new_job>' % self.name)

