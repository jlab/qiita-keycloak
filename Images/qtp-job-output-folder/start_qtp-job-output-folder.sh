#!/bin/bash

cd / && python trigger.py start_qtp_job_output_folder

tail -f /dev/null
