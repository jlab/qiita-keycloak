#!/bin/bash

cd / && python trigger.py deblur start_deblur /qp-deblur

tail -f /dev/null
