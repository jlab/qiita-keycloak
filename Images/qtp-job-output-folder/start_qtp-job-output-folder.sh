#!/bin/bash

cd / && python trigger.py qtp-job-output-folder start_qtp_job_output_folder /qtp-job-output-folder

tail -f /dev/null
