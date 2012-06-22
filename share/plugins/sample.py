# -*- coding: utf-8 -*-

""" Sample module """

from importerplugin import ImporterPlugin
from basejob import BaseJob
import time


class Job(BaseJob):
    """ Sample job. """

    def __init__(self, options, infos, params):
        """ Init method of sample job. """
        BaseJob.__init__(self, options, infos, params)

    # This method isn't called directly by a check but by another method inside
    # the plugin : its name MUST start with '_'.
    def _do_nothing(self):
        """ Do nothing. """
        time.sleep(4)

    # This method is called by a check.
    # It is important to document tests with a docstring as this is what will be
    # used by current scripts to load check's description into the database.
    def nothing(self):
        """ The nothing check. """
        self.log.info('This check is doing nothing.')
        self._do_nothing()
        return 'FINISHED', 'I really did nothing'

    # This method is called by a check.
    def pierrot(self):
        """ The song check. """
        self.log.info('Au clair de la lune.')
        return 'FINISHED', 'Nothing to say'


class Plugin(ImporterPlugin):
    """ Sample plugin. """

    # Name of the plugin. Mandatory
    name = "sample"

    # This dict defines the mandatory options to be configured to use this plugin.
    # Its form is : require = { 'option1_name' : option1_type, ... }
    require = { }

    # This dict defines the optional options of this plugin.
    # Its form is : optional = {'option1_name' : option1_type, ... }
    optional = { }

    def __init__(self, options, event, params=None):
        """ Init method of sample plugin. """
        ImporterPlugin.__init__(self, options, event, params)

    def create_new_job(self, job):
        """ Create a new sample job. """
        return Job(self.options, job, self.params)
