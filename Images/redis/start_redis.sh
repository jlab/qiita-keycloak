#!/bin/sh

# proper listening and reacting to SIGTERM
cleanup() {
    kill $PY_PID1 2>/dev/null
    kill $PY_PID2 2>/dev/null
    wait $PY_PID1
    wait $PY_PID2
    exit 0
}
trap cleanup TERM INT

# start two redis server and safe PID in variable
# for user and stats
redis-server --requirepass $(REDISPWD) --port 7777 &
PY_PID1=$!

# for redbiom
redis-server --requirepass $(REDISPWD) --port 6379 &
PY_PID2=$!

# wait till both redis processes are terminated
wait $PY_PID1
wait $PY_PID2