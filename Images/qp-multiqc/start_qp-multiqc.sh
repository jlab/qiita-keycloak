#!/bin/bash

cd / && python trigger.py multiqc start_qp_multiqc /qp-multiqc

tail -f /dev/null
