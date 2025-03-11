#!/bin/bash

cd / && python trigger.py qtp-visualization start_visualization_types /qtp-visualization

tail -f /dev/null
