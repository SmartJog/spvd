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
        """

        threading.Thread.__init__(self)
        self.setDaemon(True)
        self.name       = name
        self.logger     = logger
        self.dismiss    = event

        self.params     = { 'importer_retry_timeout': 10,
                            'max_parallel_checks': 3,
                            'max_checks_queue': 9,
                            'check_poll': 1,
                            'debug': False,
                        }

        if params:
            self.params.update(params)

        self.importer   = Importer()
        if url:
            self.importer['distant_url'] = url

        self.job_pool = threadpool.ThreadPool(int(self.params['max_parallel_checks']))

        self.start()
        self.log("init complete")

    def log(self, message):
        """ Custom logging method. """
        self.logger.write("%s %s" % (self.name, message))

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

        return job.run()

    def job_stop(self, request, result):
        """ Stops a job. """

        self.log('*** Result from request #%s: %s' % (request.request_id, result['check_message']))

        if 'message' not in result:
            result['message'] = 'No message'

        saved = False
        update = self.__prepare_status_update(result)

        while not saved and not self.dismiss.isSet():
            try:
                self.importer.call('spv', 'set_checks_status', [update])
                self.log('*** Result from request #%s: saved' % request.request_id)
                saved = True
            except ImporterError, error:
                self.log('remote module error <' + str(error) + '>')
                self.dismiss.wait(self.params['importer_retry_timeout'])

    def handle_exception(self, request, exc_info):
        """ Handle exception in a job. """

        if not isinstance(exc_info, tuple):
            # Something is seriously wrong...
            self.log('*** Worker thread raised an exception ***')
            self.log(request)
            self.log(exc_info)
            raise SystemExit

        self.log("*** Exception occured in request #%s: %s" % \
            (request.request_id, exc_info))
        for line in traceback.format_exception(exc_info[0], exc_info[1], exc_info[2]):
            self.log(line)

    def run(self):
        """ Run method. """

        try:
            self.log("plugin started")

            while not self.dismiss.isSet():
                self.dismiss.wait(self.params['check_poll'])

                self.log('number of threads alive %d' % threading.activeCount())
                self.log('approximate number of jobs in queue %d' % self.job_pool._requests_queue.qsize())

                try:
                    self.job_pool.poll()
                except threadpool.NoResultsPending:
                    self.log('there was no result to poll')

                if self.job_pool._requests_queue.full():
                    self.log('queue estimated full')
                    continue

                # Get checks for the current plugin
                checks = {}

                try:
                    checks = self.importer.call('spv', 'get_checks',
                        limit=(self.params['max_checks_queue'] - self.job_pool._requests_queue.qsize()),
                        plugins=[self.name])
                except ImporterError, error:
                    self.log('remote module error <' + str(error) + '>')
                    self.dismiss.wait(self.params['importer_retry_timeout'])

                self.log('got %s checks' % len(checks))

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
                        self.log('Work request #%s added.' % req.request_id)
                except Queue.Full:
                    self.log("queue is full")
                    continue

        except Exception:
            self.log('fatal error: plugin stopped')
            self.log(traceback.print_exc())

        self.log('dismissing workers')
        self.job_pool.dismiss_workers(int(self.params['max_parallel_checks']))

        # Do not join, takes time and results will not be written to database anyway
        self.log("plugin stopped")

    def create_new_job(self, job):
        """ Dummy method. To be overridden in plugins. """

        raise BasePluginError('Plugin %s does not implement <create_new_job>' % self.name)

