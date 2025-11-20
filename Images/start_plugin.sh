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
        STARTSCRIPT=start_deblur
        ;;
    qp-qiime2)
        STARTSCRIPT=start_qiime2
        ;;
    qp-target-gene)
        STARTSCRIPT=start_target_gene
        ;;
    qtp-biom)
        STARTSCRIPT=start_biom
        ;;
    qtp-diversity)
        STARTSCRIPT=start_diversity_types
        ;;
    qtp-job-output-folder)
        STARTSCRIPT=start_qtp_job_output_folder
        ;;
    qtp-sequencing)
        STARTSCRIPT=start_qtp_sequencing
        ;;
    qtp-visualization)
        STARTSCRIPT=start_visualization_types
        ;;
    *)
        echo "unknown qiita plugin $PLUGIN"
        exit 1
        ;;
esac
    
# start tornado server and safe PID in variable
cd /
if [ "$PLUGIN" = "qp-qiime2" ]; then
    # as this plugin still uses a conda environment
    python trigger.py qiime2 $STARTSCRIPT /qp-qiime2 &
elif [ "$PLUGIN" = "qp-target-gene" ]; then
    # as this plugin uses old py27
    python3 trigger.py $STARTSCRIPT &
else
    python trigger.py $STARTSCRIPT &
fi
PY_PID=$!

# wait till trigger.py process is terminated
wait "$PY_PID"
