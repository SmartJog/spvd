""" BasePlugin definitions. """

import sys
import time
import threading
import traceback
from importer import Importer, ImporterError

def print_traceback(log):
    traceback.print_exc(file=log._file)
    #traceback.print_exc(file=sys.stdout)

class BasePluginError(Exception):
    """ Raised by BasePlugin. """

    def __init__(self, error):
        """ Init method. """
        Exception.__init__(self, error)

class BasePlugin(threading.Thread):
    """ Base class for job implementation in spvd. """

    def __init__(self, name, logger, url=None, params=None):
        """ Init method.

        @url: url pass to Importer.

        @params is a dictionnary of optional parameters among:
        max_parallel_checks: maximum number of threads for this plugin
        max_checks_queue:    maximum number of checks to get from
                             the DB and queue for execution
        debug:               enable debugging information
        """

        threading.Thread.__init__(self)
        self.name       = name
        self.logger     = logger

        self.params     = { 'max_parallel_checks': 3,
                            'max_checks_queue': 9,
                            'debug': False,
                        }
        if params:
            self.params.update(params)

        self.importer   = Importer()
        if url:
            self.importer['distant_url'] = url

        self.jobs       = {}
        self.running    = {}
        self.pending    = {}

        self.stop = False
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

    def __debug_scheduling(self):
        """ Helper function to print scheduling informations. """

        if not self.params['debug']:
            return

        print "running:", len(self.running), "pending:", len(self.pending), "queued:", len(self.jobs)
        print "running keys:", self.running.keys()
        print "pending keys:", self.pending.keys()
        print "jobs keys   :", self.jobs.keys()

    def run(self):
        """ Run method. """
        try:
            self.log("thread started")

            while not self.stop:
                self.__debug_scheduling()

                # Get an arbitrary number of checks for the current plugin
                if len(self.jobs) < self.params['max_checks_queue'] + 1:
                    checks = self.importer.call('spv', 'get_checks', limit=self.params['max_checks_queue'], plugins=[self.name])

                # Push jobs to the job queue
                for status_id, check in checks.iteritems():
                    check['plugin'] = self.name
                    self.log('status_id=%d New check found' % status_id)

                    try:
                        # Add the check to the list of jobs

                        # Not useful since not syncing status to the DB
                        #check['status'] = 'PENDING'
                        #check['message'] = 'Check queued'

                        # Skip this job, it is already running
                        if check['status_id'] in self.running.keys():
                            self.running[check['status_id']].infos['status'] = 'TIME_SLOT_EXPIRED'
                            print "This job %s is already running" % check['status_id']
                            continue

                        self.jobs[check['status_id']] = self.create_new_job(check)

                    except BasePluginError, error:
                        self.log('Error while creating job: ' + traceback.format_exc())
                        check['status'] = 'ERROR'
                        check['message'] = str(error)
                        update = self.__prepare_status_update(check)
                        self.importer.call('spv', 'set_checks_status', [update])
                        continue

                    # Adding the check to the pending queue
                    self.pending[check['status_id']] = self.jobs[check['status_id']]

                # Verify status of currently running check jobs
                for running in self.running.keys():

                    if self.running[running].finished:
                        self.log('status_id=%d check finished' % running)
                        self.__debug_scheduling()

                        self.running.pop(running)
                        job = self.jobs.pop(running)
                        if not 'status' in job.infos:
                            job.infos['status'] = 'FINISHED'
                        job.infos['message'] = 'Check finished'
                        update = self.__prepare_status_update(job.infos)
                        self.importer.call('spv', 'set_checks_status', [update])

                        self.__debug_scheduling()

                    elif self.running[running].error:
                        self.log('status_id=%d check in error' % running)

                        self.running.pop(running)
                        job = self.jobs.pop(running)
                        job.infos['status'] = 'ERROR'
                        if job.infos['message'] is None:
                            job.infos['message'] = 'Check reported an error but no message'
                        update = self.__prepare_status_update(job.infos)
                        self.importer.call('spv', 'set_checks_status', [update])

                # Not enough jobs running but some pending
                while len(self.running) < self.params['max_parallel_checks'] and len(self.pending) > 0:
                    job_ids = self.pending.keys()
                    job_ids.sort()
                    to_run = job_ids[0]
                    self.log('status_id=%d Popped from the pending queue' % to_run)

                    # Not useful since not syncing status to the DB
                    #self.jobs[to_run].infos['status'] = 'RUNNING'
                    #self.jobs[to_run].infos['message'] = 'Job started'
                    self.jobs[to_run].start()
                    self.pending.pop(to_run)
                    self.running[to_run] = self.jobs[to_run]

                # FIXME: make this configurable to avoid storming the DB
                time.sleep(1)

            # Loop stopped
            self.log("thread stopped")

        except ImporterError, error:
            self.log('Fatal error: plugin stopped')
            self.log('Remote module error <' + str(error) + '>')

        except Exception:
            self.log('Fatal error: plugin stopped')
            print_traceback(self.logger)

    def create_new_job(self, job):
        """ Dummy method. To be overridden in plugins. """

        raise BasePluginError('Plugin %s does not implement <create_new_job>' % self.name)

