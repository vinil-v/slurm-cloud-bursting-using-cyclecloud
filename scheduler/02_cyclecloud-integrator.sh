#!/bin/sh

# Script to integrate external Slurm Scheduler with CycleCloud application
# This script is used to install the CycleCloud Slurm integration package and configure the autoscaler
# This script is intended to be run on the external Slurm scheduler
# Author : Vinil Vadakkepurakkal
# Date : 10/02/2025
set -e
if [ $(whoami) != root ]; then
  echo "Please run as root"
  exit 1
fi


# Prompt user to enter CycleCloud details for Slurm scheduler integration
echo "Please enter the CycleCloud details to integrate with the Slurm scheduler"
echo " "
# Prompt for Cluster Name
read -p "Enter Cluster Name: " cluster_name

# Prompt for Username
read -p "Enter CycleCloud Username: " username

# Prompt for Password (masked input)
echo "Enter CycleCloud Password: "
stty -echo
read password
stty echo
echo ""  # Move to a new line after password input

read -p "Enter the Project version: " slurm_autoscale_pkg_version


# Prompt for URL
read -p "Enter CycleCloud URL (e.g., https://10.222.1.19): " url

# Display summary of entered details
echo "------------------------------------------------------------------------------------------------------------------------------"
echo " "
echo "Summary of entered details:"
echo "Cluster Name: $cluster_name"
echo "CycleCloud Username: $username"
echo "CycleCloud URL: $url"
echo " "
echo "------------------------------------------------------------------------------------------------------------------------------"

# Define variables

slurm_autoscale_pkg="azure-slurm-pkg-$slurm_autoscale_pkg_version.tar.gz"
slurm_script_dir="/opt/azurehpc/slurm"
config_dir="/sched/$cluster_name"

# Create necessary directories
mkdir -p "$slurm_script_dir"

# Activate Python virtual environment for Slurm integration
echo "------------------------------------------------------------------------------------------------------------------------------"
echo "Configuring virtual enviornment and Activating Python virtual environment"
echo "------------------------------------------------------------------------------------------------------------------------------"
python3 -m venv "$slurm_script_dir/venv"
. "$slurm_script_dir/venv/bin/activate"

# Download and install CycleCloud Slurm integration package
echo "------------------------------------------------------------------------------------------------------------------------------"
echo "Downloading and installing CycleCloud Slurm integration package"
echo "------------------------------------------------------------------------------------------------------------------------------"

wget https://github.com/Azure/cyclecloud-slurm/releases/download/$slurm_autoscale_pkg_version/$slurm_autoscale_pkg -P "$slurm_script_dir"
tar -xvf "$slurm_script_dir/$slurm_autoscale_pkg" -C "$slurm_script_dir"
cd "$slurm_script_dir/azure-slurm"
head -n -30 install.sh > integrate-cc.sh
chmod +x integrate-cc.sh
./integrate-cc.sh
#cleanup
rm -rf azure-slurm*

# Initialize autoscaler configuration
echo "------------------------------------------------------------------------------------------------------------------------------"
echo "Initializing autoscaler configuration"
echo "------------------------------------------------------------------------------------------------------------------------------"

azslurm initconfig --username "$username" --password "$password" --url "$url" --cluster-name "$cluster_name" --config-dir "$config_dir" --default-resource '{"select": {}, "name": "slurm_gpus", "value": "node.gpu_count"}' > "$slurm_script_dir/autoscale.json"
chown slurm:slurm "$slurm_script_dir/autoscale.json"
chown -R slurm:slurm "$slurm_script_dir"
# Connect and scale
echo "------------------------------------------------------------------------------------------------------------------------------"
echo "Connecting to CycleCloud and scaling resources"
echo "------------------------------------------------------------------------------------------------------------------------------"

azslurm connect
azslurm scale --no-restart
chown -R slurm:slurm "$slurm_script_dir"/logs/*.log
systemctl restart slurmctld
echo " "
echo "------------------------------------------------------------------------------------------------------------------------------"
echo "Slurm scheduler integration with CycleCloud completed successfully"
echo " Create User and Group for job submission. Make sure that GID and UID is consistent across all nodes and home directory is shared"
echo "------------------------------------------------------------------------------------------------------------------------------"
echo " "