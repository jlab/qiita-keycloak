#!/bin/bash

cd / && python trigger.py platemapper start_platemapper /qp-platemapper

tail -f /dev/null
