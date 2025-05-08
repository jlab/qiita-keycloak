#!/bin/bash

cd / && python trigger.py qiime2 start_qiime2 /qp-qiime2

tail -f /dev/null
