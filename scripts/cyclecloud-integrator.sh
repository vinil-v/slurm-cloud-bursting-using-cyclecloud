#!/bin/sh
# Author : Vinil Vadakkepurakkal
# Date : 13/5/2024
# Script to integrate external Slurm Scheduler with CycleCloud application
# This script is used to install the CycleCloud Slurm integration package and configure the autoscaler
# This script is intended to be run on the external Slurm scheduler

# CycleCloud variables
cluster_name="hb2"
username="vinil"
password='P@55w0rd@123'
url="https://10.222.1.19"

# Directory paths
slurm_script_dir="/opt/azurehpc/slurm"
config_dir="/sched/$cluster_name"

# Create necessary directories
mkdir -p "$slurm_script_dir"

# Activate Python virtual environment for Slurm integration
python3 -m venv "$slurm_script_dir/venv"
source "$slurm_script_dir/venv/bin/activate"

# Download and install CycleCloud Slurm integration package
wget https://github.com/Azure/cyclecloud-slurm/releases/download/3.0.6/azure-slurm-pkg-3.0.6.tar.gz -P "$slurm_script_dir"
tar -xvf "$slurm_script_dir/azure-slurm-pkg-3.0.6.tar.gz" -C "$slurm_script_dir"
cd "$slurm_script_dir/azure-slurm"
./install.sh

# Initialize autoscaler configuration
azslurm initconfig --username "$username" --password "$password" --url "$url" --cluster-name "$cluster_name" --config-dir "$config_dir" --default-resource '{"select": {}, "name": "slurm_gpus", "value": "node.gpu_count"}' > "$slurm_script_dir/autoscale.json"

# Connect and scale
azslurm connect
azslurm scale
