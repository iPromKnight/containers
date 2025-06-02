#!/usr/bin/env bash

# Execute any scripts found in /extra-scripts
for SCRIPT in $(ls /extra_scripts); do
    bash -c $SCRIPT
done
