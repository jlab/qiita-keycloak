#!/bin/bash

cd / && python trigger.py qp-target-gene start_target_gene /qp-target-gene

tail -f /dev/null
