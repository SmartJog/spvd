""" Sample module """

from baseplugin import BasePlugin
from basejob import BaseJob

class Job(BaseJob):
    """ Sample job. """

    def __init__(self, options, infos, params):
        """ Init method of sample job. """
        BaseJob.__init__(self, options, infos, params)
        self.infos = infos
        self.params = params

        self.do_nothing = self._get_info('do-nothing', 'true') == 'true'
        self.do_pierrot = self._get_info('do-pierrot', 'true') == 'true'

    def _get_info(self, info, default=None):
        """ Returns @info from the infos attached to the check. """
        if info in self.infos['check']['check_infos']:
            return self.infos['check']['check_infos'][info]
        if info in self.infos['status']['status_infos']:
            return self.infos['status']['status_infos'][info]
        return default

    def __getattr__(self, attr):
        # This will be automatically called for every check of the plugin
        return lambda: self.__check__(attr)

    def __check__(self, _check_name):
        if self.do_nothing and self.__nothing__():
            return
        if self.do_pierrot and self.__pierrot__():
            return

    def __nothing__(self):
        """ The nothing check. """
        self.log.info('This check is doing nothing.')
        self.set_check_status('FINISHED', 'I really did nothing')

    def __pierrot__(self):
        """ The song check. """
        self.log.info('Au clair de la lune.')
        self.set_check_status('FINISHED', 'Nothing to say')

class Plugin(BasePlugin):
    """ Sample plugin. """

    # Name of the plugin. Mandatory
    name = "sample2"

    # This dict defines the mandatory options to be configured to use this plugin.
    # Its form is : require = { 'option1_name' : option1_type, ... }
    require = { }

    # This dict defines the optional options of this plugin.
    # Its form is : optional = {'option1_name' : option1_type, ... }
    optional = { }

    def __init__(self, options, event, url=None, params=None):
        """ Init method of sample plugin. """
        BasePlugin.__init__(self, options, event, url, params)

    def create_new_job(self, job):
        """ Create a new sample job. """
        return Job(self.options, job, self.params)
