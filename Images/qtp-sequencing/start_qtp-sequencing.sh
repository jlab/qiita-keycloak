#!/bin/bash

cd / && python trigger.py qtp-sequencing start_qtp_sequencing /qtp-sequencing

tail -f /dev/null
