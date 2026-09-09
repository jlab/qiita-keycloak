#!/bin/bash

# proper listening and reacting to SIGTERM
cleanup() {
    echo "Received SIGTERM, stopping..."
    kill "$PY_PID" 2>/dev/null
    wait "$PY_PID"
    exit 0
}
trap cleanup SIGTERM SIGINT

STARTSCRIPT=
if [ -z "$PLUGIN" ]; then
    echo "Environment variable PLUGIN is empty. It should habe been set during the docker build process. Double check your dockerfile!"
    exit 1
fi
case "$PLUGIN" in
    qp-deblur)
        STARTSCRIPT=start_$PLUGIN
        ;;
    qp-qiime2)
        STARTSCRIPT=start_$PLUGIN
        ;;
    qp-target-gene)
        STARTSCRIPT=start_$PLUGIN
        ;;
    qtp-biom)
        STARTSCRIPT=start_$PLUGIN
        ;;
    qtp-diversity)
        STARTSCRIPT=start_$PLUGIN
        ;;
    qtp-job-output-folder)
        STARTSCRIPT=start_$PLUGIN
        ;;
    qtp-sequencing)
        STARTSCRIPT=start_$PLUGIN
        ;;
    qtp-visualization)
        STARTSCRIPT=start_$PLUGIN
        ;;
    qp-woltka)
        STARTSCRIPT=start_$PLUGIN
        ;;
    *)
        echo "unknown qiita plugin $PLUGIN"
        exit 1
        ;;
esac
    
# start tornado server and safe PID in variable
cd /
if [ "$PLUGIN" = "qp-qiime2" ] || [ "$PLUGIN" = "qp-woltka" ]; then
    # as this plugin still uses a conda environment
    python trigger.py $PLUGIN $STARTSCRIPT /$PLUGIN &
elif [ "$PLUGIN" = "qp-target-gene" ]; then
    # as this plugin uses old py27
    python3 trigger.py $STARTSCRIPT &
else
    python trigger.py $STARTSCRIPT &
fi
PY_PID=$!

# wait till trigger.py process is terminated
wait "$PY_PID"
