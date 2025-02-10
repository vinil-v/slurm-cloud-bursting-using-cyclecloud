#!/bin/sh
# This script need to run on cyclecloud VM.
# This script will check the slurm version and project version and create a headless template
# Author : Vinil Vadakkepurakkal
# Date : 10/02/2025
# Command to execute

output=$(sudo /opt/cycle_server/cycle_server execute -format json 'SELECT * FROM Cloud.Project WHERE Name=="slurm"')

# Extract versions using grep and awk
versions=$(echo "$output" | grep '"Version"' | awk -F'"' '{print $4}')

if [ -z "$versions" ]; then
  echo "No versions found."
    exit 1
    fi

    # Find the latest version
    RELEASE_VERSION=$(echo "$versions" | sort -V | tail -n 1)


    RELEASE_URL="https://github.com/Azure/cyclecloud-slurm/releases/$RELEASE_VERSION"
    cyclecloud project fetch "${RELEASE_URL}" slurm-${RELEASE_VERSION}
    cp slurm-${RELEASE_VERSION}/templates/slurm.txt slurm-${RELEASE_VERSION}/templates/slurm-headless.txt

    SLURM_VERSION=$(grep -A8 "parameter configuration_slurm_version" slurm-${RELEASE_VERSION}/templates/slurm-headless.txt | grep DefaultValue | cut -d"=" -f2)
    echo "Project version: $RELEASE_VERSION"
    echo "Slurm version: $SLURM_VERSION"
    echo "Template location" : slurm-${RELEASE_VERSION}/templates/slurm-headless.txt
    echo "Please refer README for customizing the template for Headless Slurm cluster"