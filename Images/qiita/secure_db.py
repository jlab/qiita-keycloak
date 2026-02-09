# Since qiita is set up in test mode and db is populated with some default user,
# arbitrary people can a) login to qiita and b) even reset the DB via API call!
# This script shall protect against this situation in non-test environments by:
#   a) replace the default password "password" with an arbitrary string
#   b) set isTest to False

import qiita_db as qdb
import sys
import os

if os.environ.get('SECURE_QIITA_DB', "True") == 'True':
    default_pwd = os.environ.get('QIITA_USER_DEFAULT_PWD', None)
    if (default_pwd is None) or (default_pwd == ""):
        raise ValueError("Default password is '%s'. Please set a proper password via QIITA_USER_DEFAULT_PWD environment variable!" % default_pwd)

    with qdb.sql_connection.TRN:
        sql = """CREATE EXTENSION IF NOT EXISTS pgcrypto;
                UPDATE qiita.qiita_user
                SET password = crypt(%s, gen_salt('bf', 12))
                WHERE password = '$2a$12$gnUi8Qg.0tvW243v889BhOBhWLIHyIJjjgaG6dxuRJkUM8nXG9Efe';"""
        qdb.sql_connection.TRN.add(sql, [default_pwd])
        qdb.sql_connection.TRN.execute()

        print("secure qiita's postgres DB: overwrite default user password. Look up password in file Configuration/qiita_db.env!", file=sys.stderr)
else:
    print("skip securing qiita's postgres DB. Useful for testing, otherwise this is a serious security thread!!")
