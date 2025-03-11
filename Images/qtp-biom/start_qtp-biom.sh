#!/bin/bash

cd / && python trigger.py qtp-biom start_biom /qtp-biom

tail -f /dev/null
