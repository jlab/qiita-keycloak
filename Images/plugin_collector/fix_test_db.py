import os
from glob import glob
import configparser
import psycopg2


qiita_config = configparser.ConfigParser()
qiita_config.read('/qiita_configurations/qiita_server.cfg')
is_test = qiita_config['main']['TEST_ENVIRONMENT'].upper() == 'TRUE'
print("qiita is in %s mode." % ('TEST' if is_test else 'PRODUCTIVE'))

if is_test:
    conn = psycopg2.connect(database=qiita_config['postgres']['DATABASE'],
                            host=qiita_config['postgres']['HOST'],
                            user=qiita_config['postgres']['ADMIN_USER'],
                            password=qiita_config['postgres']['ADMIN_PASSWORD'],
                            port=qiita_config['postgres']['PORT'])
    cursor = conn.cursor()

    fps_plugin_configs = glob('/qiita_plugins/*.conf')
    print("Updating plugin credentials in dummy test DB with actual values from %i plugins." % len(fps_plugin_configs))
    for i, fp_plugin_config in enumerate(fps_plugin_configs):
        config = configparser.ConfigParser()
        config.read(fp_plugin_config)

        print("  (%i/%i) %s: " % (i+1, len(fps_plugin_configs), config['main']['name']), end="")

        SQL_get_softwareID_clientID = "SELECT software.software_id, oauth_software.client_id FROM qiita.software JOIN qiita.oauth_software ON qiita.software.software_id=qiita.oauth_software.software_id WHERE name='%s' AND version='%s';" % (
            config['main']['name'], config['main']['version']
        )
        cursor.execute(SQL_get_softwareID_clientID)
        old_software_id, old_client_id = cursor.fetchone()

        if config['oauth2']['client_id'] != old_client_id:
            SQL_update = "BEGIN; "
            # add in the new client secret
            SQL_update += "INSERT INTO qiita.oauth_identifiers VALUES ('%s', '%s');" % (config['oauth2']['client_id'], config['oauth2']['client_secret'])
            # add in a new software_id to client_id row
            SQL_update += "INSERT INTO qiita.oauth_software VALUES (%s, '%s');" % (old_software_id, config['oauth2']['client_id'])
            # remove old client_id
            SQL_update += "DELETE FROM qiita.oauth_software WHERE software_id=%s AND client_id='%s';" % (old_software_id, old_client_id)
            # delete old client_id client_secret relation
            SQL_update += "DELETE FROM qiita.oauth_identifiers WHERE client_id='%s';" % old_client_id
            # replace ENVIRONMENT_SCRIPT with the one given in config file
            SQL_update += "UPDATE qiita.software SET environment_script='%s' WHERE software_id='%s';" % (config['main']['ENVIRONMENT_SCRIPT'], old_software_id)
            # replace START_SCRIPT with the one given in config file
            SQL_update += "UPDATE qiita.software SET start_script='%s' WHERE software_id='%s';" % (config['main']['START_SCRIPT'], old_software_id)
            SQL_update += " COMMIT;"
            cursor.execute(SQL_update)
            print(" credentials replaced.")
        else:
            print(" credentials already up to date.")

    conn.close()
