#!/bin/sh

# Script to integrate external Slurm Scheduler with CycleCloud application
# This script is used to install the CycleCloud Slurm integration package and configure the autoscaler
# This script is intended to be run on the external Slurm scheduler
# Author : Vinil Vadakkepurakkal
# Date : 13/5/2024
set -e
if [ $(whoami) != root ]; then
  echo "Please run as root"
  exit 1
fi

# CycleCloud variables
#!/bin/bash

# Prompt user to enter CycleCloud details for Slurm scheduler integration
echo " "
echo "Please enter the CycleCloud details to integrate with the Slurm scheduler"
echo " "

# Prompt for Cluster Name
echo "Enter the Cluster Name (Cluster used when importing the template in CycleCloud):"
read cluster_name

# Prompt for CycleCloud Username
echo "Enter the CycleCloud Username:"
read username

# Prompt for CycleCloud Password (masked input)
echo "Enter the CycleCloud Password:"
read -s password

# Prompt for CycleCloud URL
echo "Enter the CycleCloud URL (e.g., https://10.222.1.19):"
read url

# Display summary of entered details
echo " "
echo "Summary of entered details:"
echo "Cluster Name: $cluster_name"
echo "CycleCloud Username: $username"
echo "CycleCloud URL: $url"



# Directory paths
slurm_script_dir="/opt/azurehpc/slurm"
config_dir="/sched/$cluster_name"

# Create necessary directories
mkdir -p "$slurm_script_dir"

# Activate Python virtual environment for Slurm integration
echo "Configuring virtual enviornment and Activating Python virtual environment"
python3 -m venv "$slurm_script_dir/venv"
source "$slurm_script_dir/venv/bin/activate"

# Download and install CycleCloud Slurm integration package
echo "Downloading and installing CycleCloud Slurm integration package"
wget https://github.com/Azure/cyclecloud-slurm/releases/download/3.0.6/azure-slurm-pkg-3.0.6.tar.gz -P "$slurm_script_dir"
tar -xvf "$slurm_script_dir/azure-slurm-pkg-3.0.6.tar.gz" -C "$slurm_script_dir"
cd "$slurm_script_dir/azure-slurm"
./install.sh

# Initialize autoscaler configuration
echo "Initializing autoscaler configuration"
azslurm initconfig --username "$username" --password "$password" --url "$url" --cluster-name "$cluster_name" --config-dir "$config_dir" --default-resource '{"select": {}, "name": "slurm_gpus", "value": "node.gpu_count"}' > "$slurm_script_dir/autoscale.json"

# Connect and scale


echo "Connecting to CycleCloud and scaling resources"
azslurm connect
azslurm scale
