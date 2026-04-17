#!/bin/bash

cd / && python trigger.py multiqc_report start_qtp_multiqc_report /qtp-multiqc-report

tail -f /dev/null
