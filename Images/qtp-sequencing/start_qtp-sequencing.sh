#!/bin/bash

cd / && python trigger.py start_qtp_sequencing

tail -f /dev/null
