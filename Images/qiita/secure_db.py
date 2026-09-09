# Since qiita is set up in test mode and db is populated with some default user,
# arbitrary people can a) login to qiita and b) even reset the DB via API call!
# This script shall protect against this situation in non-test environments by:
#   a) replace the default password "password" with an arbitrary string
#   b) set isTest to False

import sys
from random import choice
from string import ascii_uppercase

import qiita_db as qdb
from qiita_core.util import is_test_environment

if is_test_environment():
    # although user authentication should be handled through keycloak, we
    # better be safe than sorry and set the password value in the postgres
    # DB to something other than "password"
    random_pwd = ''.join(choice(ascii_uppercase) for i in range(12))
    with qdb.sql_connection.TRN:
        sql = """CREATE EXTENSION IF NOT EXISTS pgcrypto;
                UPDATE qiita.qiita_user
                SET password = crypt(%s, gen_salt('bf', 12))
                WHERE password = '$2a$12$gnUi8Qg.0tvW243v889BhOBhWLIHyIJjjgaG6dxuRJkUM8nXG9Efe';"""
        qdb.sql_connection.TRN.add(sql, [random_pwd])
        qdb.sql_connection.TRN.execute()
        print("Secure qiita's postgres DB: overwrite default user password.", file=sys.stderr)

    with qdb.sql_connection.TRN:
        qdb.sql_connection.TRN.add("UPDATE settings SET test = False", [])
        qdb.sql_connection.TRN.execute()
        print("Put qiita into productive mode, i.e. prohibit API reset.")
else:
    print("Good: Qiita postgres DB already in test=False mode.")
