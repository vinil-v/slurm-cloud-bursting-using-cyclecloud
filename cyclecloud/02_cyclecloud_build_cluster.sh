#!/bin/sh
# This script need to run on cyclecloud VM.
# This script will import the cluster to cyclecloud
# Author : Vinil Vadakkepurakkal
# Date : 10/02/2025
set -e
read -p "Enter Cluster Name: " CLUSTER_NAME
echo "Cluster Name: $CLUSTER_NAME"
output=$(sudo /opt/cycle_server/cycle_server execute -format json 'SELECT * FROM Cloud.Project WHERE Name=="slurm"')

# Extract versions using grep and awk
versions=$(echo "$output" | grep '"Version"' | awk -F'"' '{print $4}')

if [ -z "$versions" ]; then
  echo "No versions found."
    exit 1
    fi

    # Find the latest version
    RELEASE_VERSION=$(echo "$versions" | sort -V | tail -n 1)

SLURM_VERSION=$(grep -A8 "parameter configuration_slurm_version" slurm-${RELEASE_VERSION}/templates/slurm-headless.txt | grep DefaultValue | cut -d"=" -f2)
echo "Importing Cluster"
cyclecloud import_cluster $CLUSTER_NAME -c Slurm -f slurm-${RELEASE_VERSION}/templates/slurm-headless.txt

echo "Please make a note of the following details:"
echo "-------------------------------------------"
echo "Cluster Name: $CLUSTER_NAME"
echo "Project version: $RELEASE_VERSION"
echo "Slurm version: $SLURM_VERSION"