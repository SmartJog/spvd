""" Builds the check list with the waiting status """

from baseplugin import BasePlugin
from basejob import BaseJob, BaseJobRuntimeError
from importer import Importer
import psycopg2

PLUGIN_NAME = "delivery"

class DeliveryRuntimeError(BaseJobRuntimeError):
    """ BaseJob Exceptions. """

    def __init__(self, error):
        """ Init method. """
        Exception.__init__(self, error)

class Job(BaseJob):

    def __init__(self, logger, infos, params):
        BaseJob.__init__(self, logger, infos)
        self.importer = Importer()
        self.importer['distant_url'] = 'https://%s/exporter/' % (self.infos["address"])
        self.server_address = self.infos["address"]
        self.params = params


    def connect(self):
        """
        Connection to the database.
        """
        try:
            connector = "host=%s port=%s user=%s password=%s dbname=%s" % \
                    ( self.params['host'], \
                      self.params['port'], \
                      self.params['user'], \
                      self.params['password'],\
                      self.params['database'])
            self.conn = psycopg2.connect(connector)
            self.cursor = self.conn.cursor();
        except Exception:
            raise DeliveryRuntimeError("Could not connect to the server")


    def set_metadata(self, entries):
        """
        Set metadata for a set of files for an receiver given.
        """
        entries = self.importer.call('webengine.delivery.metadata', 'deliver_files', entries)
        error_messages = ()
        ret_status = "OK"
        for entry in entries:
            set = ()
            dic = {"det_id" : entry["DET_ID"]}
            self.cursor.execute("SAVEPOINT save_no_resend_%(DET_ID)s" % (entry))
            try:
                if  entry["status"] == "KO" or entry["status"] == "Warning":
                    raise Exception(entry["DET_ID"])

                set = ("det_transfer_status='Complete'", )
                if entry["STATUS"] == "Processing":
                    set += ("det_status='Complete'",)

                self.cursor.execute("UPDATE sjg_delivery_transfer SET %s WHERE det_id = '%s'" % (",".join(set), dic['det_id']))

            except Exception, e:
                ret_status='ERROR'
                error_messages += ("%(DET_ID)s " % entry,)
                entry['HOSTNAME'] = self.server_address
                self.cursor.execute("ROLLBACK TO SAVEPOINT save_no_resend_%(DET_ID)s" % entry)
                if entry["STATUS"] == "Processing":
                    self.log('Failed to process NO-RESEND for delivery (DET_ID=%(DET_ID)s of file %(MD5)s (%(FILENAME)s) sent to %(HOSTNAME)s. Putting delivery transfer status back to "Processing"' % (entry))
                    self.cursor.execute("UPDATE sjg_delivery_transfer SET det_transfer_status='Processing' WHERE det_id = %(DET_ID)s" % (entry))
                else:
                    self.log('Failed to set metadata for delivery (DET_ID=%(DET_ID)s of file %(MD5)s (%(FILENAME)s) sent to %(HOSTNAME)s. Will retry later' % (entry))
        return ret_status, error_messages

    def get_files_to_set_metadata(self):
        """
        Select and set metadata for files are in waiting status for a
        specific receiver
        """
        self.log('Get the check with waiting status')
        self.connect()
        fields = ("DET_ID", "STATUS", "MD5", "FILENAME", "CPY_ID", "CPY_NAME", "STREAM_ID")
        query = "SELECT det.det_id, det.det_status, det.det_md5, det.det_target_filename, cpy.cpy_id, cpy.cpy_name, upu.upu_private_id " \
                "FROM sjg_delivery_transfer det LEFT OUTER JOIN sjg_uplink_use upu ON upu.det_id = det.det_id " \
                "JOIN sjg.sjg_company cpy ON det.cpy_initiator_id=cpy.cpy_id " \
                "JOIN sjg_machine mac ON mac.mac_id = det.mac_dest_id AND mac.mac_hostname=%(mac_hostname)s" \
                "WHERE det.det_transfer_status = 'Waiting'"
        self.cursor.execute(query.encode('ISO 8859-15'), {'mac_hostname': self.server_address.encode('ISO 8859-15')})
        files = self.cursor.fetchall()
        # If some files are in waiting status
        entries = reduce(lambda infos, row: infos + [dict(zip(fields, row))], files, [])
        if (len(entries)):
            self.log('entries found on server : ' + self.server_address)
            status, error_messages =  self.set_metadata(entries)
            self.conn.commit()
            if (len(error_messages)):
                self.infos['message'] = "Fail for delivery with det_id: " + ",".join(error_messages)
            if status == "OK":
                self.infos['status'] = "FINISHED"
            else:
                self.infos['status'] = "ERROR"
        else:
            self.infos['message'] = "No file to set metadata"
            self.infos['status'] = "FINISHED"



class Plugin(BasePlugin):

    def __init__(self, log, event, url=None, params=None):
        """ Init method of the streams plugin.

        @params is a dictionary of optional parameters among:
        host: address where the database is hosting
        user: user used to database connection
        password: password used to database connection
        database: database using to select delivery
        port: port using for datbase connection

        @see BasePlugin documentation
        """

        delivery_params = {'host': 'dbpsql-1.lab', 'user': 'sjg', 'password': 'sjg', 'database': 'smartjog', 'port': '5432'}
        delivery_params.update(params)
        BasePlugin.__init__(self, PLUGIN_NAME, log, event, url, delivery_params)

    def create_new_job(self, job):
        return Job(self.logger, job, self.params)
