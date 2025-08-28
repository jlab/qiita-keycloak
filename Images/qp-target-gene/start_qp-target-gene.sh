#!/bin/bash

cd / && python3 trigger.py start_target_gene

tail -f /dev/null
