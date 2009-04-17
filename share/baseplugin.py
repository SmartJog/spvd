""" BasePlugin definitions. """

import sys
import time
import threading
import traceback
from importer import Importer

def print_traceback(log):
    traceback.print_exc(file=log._file)
    #traceback.print_exc(file=sys.stdout)

class BasePlugin(threading.Thread):
    """ Base class for job implementation in spvd. """

    class InitError(Exception):
        def __init__(self, error):
            """ Init method. """
            Exception.__init__(self, error)

    def __init__(self, name, logger, url=None):
        """ Init method.

        @url: url pass to Importer.
        """

        threading.Thread.__init__(self)
        self.name       = name
        self.logger     = logger

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
    def __prepare_status_update(check, status, message):
        """ Prepare a structure for status update. """
        status = {'status_id': check['status_id'],
            'sequence_id': check['seq_id'],
            'status': status,
            'message': message,
        }

        return status


    def run(self):
        """ Run method. """
        try:
            self.log("thread started")

            while not self.stop:
                # Get an arbitrary number of checks for the current plugin
                # FIXME: make limit configurable
                checks = self.importer.call('spv', 'get_checks', limit=10, plugin=[self.name])

                for check in checks:
                    self.log('status_id=%s New check found' % (check['status_id']))
                    try:
                        # Add the check to the list of jobs
                        self.jobs[check['status_id']] = self.createNewJob(check)
                    except BasePlugin.InitError, error:
                        self.log('Error while creating job: ' + traceback.format_exc())
                        update = self.__prepare_status_update(check, 'ERROR', str(error))
                        self.importer.call('spv', 'set_checks_status', update)
                        continue

                # Verify status of currently running check jobs
                for running in self.running.keys():

                    if self.running[running].finished:
                        self.running.pop(running)
                        job = self.jobs.pop(running)
                        job.infos['status'] = 'FINISHED'
                        update = self.__prepare_status_update(job.infos, 'GOOD', 'Finished')
                        self.importer.call('spv', 'set_checks_status', update)

                    elif self.running[running].error:
                        self.running.pop(running)
                        job = self.jobs.pop(running)
                        job.infos['status'] = 'ERROR'
                        update = self.__prepare_status_update(job.infos, 'ERROR', 'Error')
                        self.importer.call('spv', 'set_checks_status', update)

                # No more jobs running but some pending
                if not len(self.running) and len(self.pending):
                    job_ids = self.pending.keys()
                    job_ids.sort()
                    to_run = job_ids[0]
                    self.jobs[to_run].infos['status'] = 'RUNNING'
                    self.jobs[to_run].infos['description'] = 'Job started'
                    self.jobs[to_run].start()
                    self.pending.pop(to_run)
                    self.running[to_run] = self.jobs[to_run]

                #for job in self.jobs:
                #    sjtools.update_job(self.jobs[job].infos, self.jobs[job].infos['settings'])

                time.sleep(1)

            # Loop stopped
            self.log("thread stopped")

        except ImporterError, error:
            self.log('Fatal error: plugin stopped')
            self.log('Remote module error <' + str(error) + '>')

        except Exception:
            self.log('Fatal error: plugin stopped')
            print_traceback(self.logger)

