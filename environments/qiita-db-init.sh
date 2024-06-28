#!/bin/bash

set -e
set -u

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" "$POSTGRES_DB" <<-EOSQL
      ALTER DATABASE "$POSTGRES_DB" OWNER TO "$POSTGRES_USER"
EOSQL
