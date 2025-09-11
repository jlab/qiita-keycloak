#!/bin/bash

cd / && python trigger.py start_deblur

tail -f /dev/null
