#!/bin/bash

cd / && python trigger.py qiime2 start_diversity_types /qtp-diversity

tail -f /dev/null
