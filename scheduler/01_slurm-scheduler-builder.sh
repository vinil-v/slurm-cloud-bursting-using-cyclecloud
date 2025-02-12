#!/bin/sh
# This script builds a External Slurm scheduler for cloud bursting with Azure CycleCloud
# Author : Vinil Vadakkepurakkal
# Date : 10/02/2025

set -e
if [ $(whoami) != root ]; then
  echo "Please run as root"
  exit 1
fi
echo "------------------------------------------------------------------------------------------------------------------------------"
echo "Building Slurm scheduler for cloud bursting with Azure CycleCloud"
echo "------------------------------------------------------------------------------------------------------------------------------"
echo " "
# Prompt for Cluster Name
read -p "Enter Cluster Name: " cluster_name
read -p "Enter the Slurm version to install (You get this from the cyclecloud_build_cluster.sh): " SLURM_VERSION

ip_address=$(hostname -I | awk '{print $1}')
echo "------------------------------------------------------------------------------------------------------------------------------"
echo " "
echo "Summary of entered details:"
echo "--------------------------"
echo "Cluster Name: $cluster_name"
echo "Scheduler Hostname: $(hostname)"
echo "NFSServer IP Address: $ip_address"
echo " "
echo " Please Note down the above details for configuring cyclecloud UI"
echo "------------------------------------------------------------------------------------------------------------------------------"

sched_dir="/sched/$cluster_name"
slurm_conf="$sched_dir/slurm.conf"
munge_key="/etc/munge/munge.key"
slurm_script_dir="/opt/azurehpc/slurm"
OS_VERSION=$(cat /etc/os-release  | grep VERSION_ID | cut -d= -f2 | cut -d\" -f2 | cut -d. -f1)
OS_ID=$(cat /etc/os-release  | grep ^ID= | cut -d= -f2 | cut -d\" -f2 | cut -d. -f1)


# Create Munge and Slurm users
echo "------------------------------------------------------------------------------------------------------------------------------"
echo "Creating Munge and Slurm users"
echo "------------------------------------------------------------------------------------------------------------------------------"


# Function to create a group if it does not exist
create_group() {
    if ! getent group "$1" >/dev/null; then
        groupadd -g "$2" "$1"
        echo "Group $1 created."
    else
        echo "Group $1 already exists."
    fi
}

# Function to create a user if it does not exist
create_user() {
    if ! id "$1" >/dev/null 2>&1; then
        useradd -u "$2" -g "$3" -s /bin/false -M "$1"
        echo "User $1 created."
    else
        echo "User $1 already exists."
    fi
}

# Create groups and users
create_group "munge" 11101
create_user "munge" 11101 11101

create_group "slurm" 11100
create_user "slurm" 11100 11100

echo "Munge and Slurm user setup complete."
echo "------------------------------------------------------------------------------------------------------------------------------"

# Set up NFS server
echo "------------------------------------------------------------------------------------------------------------------------------"
echo "Setting up NFS server"
echo "------------------------------------------------------------------------------------------------------------------------------"
case "$OS_ID" in
    almalinux)
        dnf install -y nfs-utils
        ;;
    ubuntu)
        apt-get update && apt-get install -y nfs-kernel-server
        ;;
    *)
        echo "Unsupported OS: $OS_ID"
        exit 1
        ;;
esac
mkdir -p /sched /shared
# Function to add an NFS entry if it doesn't exist
add_entry() {
    local entry=$1
    local file="/etc/exports"

    if ! grep -qF "$entry" "$file"; then
        echo "$entry" >> "$file"
        echo "Added: $entry"
    else
        echo "Already exists: $entry"
    fi
}
# Add the required entries
add_entry "/sched *(rw,sync,no_root_squash)"
add_entry "/shared *(rw,sync,no_root_squash)"

echo "NFS exports setup complete."

systemctl start nfs-server.service
systemctl enable nfs-server.service
exportfs -rv
echo "NFS server setup complete"
showmount -e localhost

# setting up Microsoft repo and installing Packages
echo "------------------------------------------------------------------------------------------------------------------------------"
echo "Setting up Microsoft repo and installing Slurm packages"
echo "------------------------------------------------------------------------------------------------------------------------------"
case "$OS_ID" in
    almalinux)
        # Setup Microsoft repository if not already present
        if [ ! -e /etc/yum.repos.d/microsoft-prod.repo ]; then
            echo "Setting up Microsoft repository..."
            curl -sSL -O https://packages.microsoft.com/config/rhel/$OS_VERSION/packages-microsoft-prod.rpm        
            rpm -i packages-microsoft-prod.rpm
            rm -f packages-microsoft-prod.rpm
            echo "Microsoft repo setup complete."
        fi

        # Setup Slurm repository
        echo "Setting up Slurm repository..."
        cat <<EOF > /etc/yum.repos.d/slurm.repo
[slurm]
name=Slurm Workload Manager
baseurl=https://packages.microsoft.com/yumrepos/slurm-el8-insiders
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
priority=10
EOF
        echo "Slurm repo setup complete."
        echo "Installing munge packages..."
        dnf install -y epel-release
        dnf install -y munge munge-libs
        echo "Munge installed"
        echo "Installing Slurm packages..."
        slurm_packages="slurm slurm-slurmrestd slurm-libpmi slurm-devel slurm-pam_slurm slurm-perlapi slurm-torque slurm-openlava slurm-example-configs"
        sched_packages="slurm-slurmctld slurm-slurmdbd"
        for pkg in $slurm_packages; do
                yum -y install $pkg-${SLURM_VERSION}.el${OS_VERSION} --disableexcludes slurm
        done
        for pkg in $sched_packages; do
                yum -y install $pkg-${SLURM_VERSION}.el${OS_VERSION} --disableexcludes slurm
        done
        echo "Slurm installed"
        ;;

    ubuntu)
        echo "Updating package lists..."
        apt update

        # Extract Ubuntu version
        UBUNTU_VERSION=$(grep -oP '(?<=VERSION_ID=")[0-9.]+' /etc/os-release)

        # Install python3-venv if Ubuntu version is greater than 19
        if [ "$(echo "$UBUNTU_VERSION > 19" | bc)" -eq 1 ]; then
        echo "Installing Python3 virtual environment..."
        DEBIAN_FRONTEND=noninteractive apt -y install python3-venv
        fi

        # Install required dependencies
        echo "Installing required packages and munge..."
        DEBIAN_FRONTEND=noninteractive apt -y install munge libmysqlclient-dev libssl-dev jq

        # Determine Slurm repository based on Ubuntu version
        case "$UBUNTU_VERSION" in
        "22.04") 
        REPO="slurm-ubuntu-jammy"
        ln -sf /lib/x86_64-linux-gnu/libtinfo.so.6.3 /usr/lib/x86_64-linux-gnu/libtinfo.so.6
         ;;
        "20.04") 
        REPO="slurm-ubuntu-focal" 
        ln -sf /lib/x86_64-linux-gnu/libtinfo.so.6.2 /usr/lib/x86_64-linux-gnu/libtinfo.so.6
        ;;
        esac

        echo "Using Slurm repository: $REPO"

        # Add Slurm repository
        echo "Configuring Slurm repository..."
        echo "deb [arch=amd64] https://packages.microsoft.com/repos/$REPO/ insiders main" > /etc/apt/sources.list.d/slurm.list

        # Set repository priorities
        cat <<EOF > /etc/apt/preferences.d/slurm-repository-pin-990
Package: slurm, slurm-*
Pin: origin "packages.microsoft.com"
Pin-Priority: 990

Package: slurm, slurm-*
Pin: origin *ubuntu.com*
Pin-Priority: -1
EOF
        echo "Slurm repository setup complete."

        # Setup Microsoft repository if not already present
        if [ ! -e /etc/apt/sources.list.d/microsoft-prod.list ]; then
            echo "Setting up Microsoft repository..."
            curl -sSL -O https://packages.microsoft.com/config/ubuntu/$UBUNTU_VERSION/packages-microsoft-prod.deb
            dpkg -i packages-microsoft-prod.deb
            rm -f packages-microsoft-prod.deb
            echo "Microsoft repo setup complete."
        fi
        apt update
        slurm_packages="slurm-smd slurm-smd-client slurm-smd-dev slurm-smd-libnss-slurm slurm-smd-libpam-slurm-adopt slurm-smd-slurmrestd slurm-smd-sview"
        for pkg in $slurm_packages; do
                DEBIAN_FRONTEND=noninteractive apt install -y $pkg=$SLURM_VERSION
                apt-mark hold $pkg
        done

        DEBIAN_FRONTEND=noninteractive apt install -y slurm-smd-slurmctld=$SLURM_VERSION slurm-smd-slurmdbd=$SLURM_VERSION
        apt-mark hold slurm-smd-slurmctld slurm-smd-slurmdbd
	DEBIAN_FRONTEND=noninteractive apt install -y libhwloc15
	ln -sf /lib/x86_64-linux-gnu/libreadline.so.8 /usr/lib/x86_64-linux-gnu/libreadline.so.7
        ln -sf /lib/x86_64-linux-gnu/libhistory.so.8 /usr/lib/x86_64-linux-gnu/libhistory.so.7
        ln -sf /lib/x86_64-linux-gnu/libncurses.so.6 /usr/lib/x86_64-linux-gnu/libncurses.so.6
        ln -sf /usr/lib64/libslurm.so.38 /usr/lib/x86_64-linux-gnu/
        ;;
    *)
        echo "Unsupported OS: $OS_ID"
        exit 1
        ;;
esac
echo "------------------------------------------------------------------------------------------------------------------------------"


# Install and configure Munge
echo "------------------------------------------------------------------------------------------------------------------------------"
echo "configuring Munge"
echo "------------------------------------------------------------------------------------------------------------------------------"
dd if=/dev/urandom bs=1 count=1024 > "$munge_key"
chown munge:munge "$munge_key"
chmod 400 "$munge_key"
systemctl start munge
systemctl enable munge
mkdir -p "$sched_dir"
cp "$munge_key" "$sched_dir/munge.key"
chown munge: "$sched_dir/munge.key"
chmod 400 "$sched_dir/munge.key"
echo "------------------------------------------------------------------------------------------------------------------------------"
echo "Munge configured"
echo "------------------------------------------------------------------------------------------------------------------------------"


# Configure Slurm
echo "------------------------------------------------------------------------------------------------------------------------------"
echo "Configuring Slurm"
echo "------------------------------------------------------------------------------------------------------------------------------"

cat <<EOF > "$slurm_conf"
MpiDefault=none
ProctrackType=proctrack/cgroup
ReturnToService=2
PropagateResourceLimits=ALL
SlurmctldPidFile=/var/run/slurmctld.pid
SlurmdPidFile=/var/run/slurmd.pid
SlurmdSpoolDir=/var/spool/slurmd
SlurmUser=slurm
StateSaveLocation=/var/spool/slurmctld
SwitchType=switch/none
TaskPlugin=task/affinity,task/cgroup
SchedulerType=sched/backfill
SelectType=select/cons_tres
GresTypes=gpu
SelectTypeParameters=CR_Core_Memory
# We use a "safe" form of the CycleCloud cluster_name throughout slurm.
# First we lowercase the cluster name, then replace anything
# that is not letters, digits and '-' with a '-'
# eg My Cluster == my-cluster
ClusterName=$cluster_name
JobAcctGatherType=jobacct_gather/none
SlurmctldDebug=debug
SlurmctldLogFile=/var/log/slurmctld/slurmctld.log
SlurmctldParameters=idle_on_node_suspend
SlurmdDebug=debug
SlurmdLogFile=/var/log/slurmd/slurmd.log
# TopologyPlugin=topology/tree
# If you use the TopologyPlugin you likely also want to use our
# job submit plugin so that your jobs run on a single switch
# or just add --switches 1 to your submission scripts
# JobSubmitPlugins=lua
PrivateData=cloud
PrologSlurmctld=/opt/azurehpc/slurm/prolog.sh
TreeWidth=65533
ResumeTimeout=1800
SuspendTimeout=600
SuspendTime=300
ResumeProgram=/opt/azurehpc/slurm/resume_program.sh
ResumeFailProgram=/opt/azurehpc/slurm/resume_fail_program.sh
SuspendProgram=/opt/azurehpc/slurm/suspend_program.sh
SchedulerParameters=max_switch_wait=24:00:00
# Only used with dynamic node partitions.
MaxNodeCount=10000
# This as the partition definitions managed by azslurm partitions > /sched/azure.conf
Include azure.conf
# If slurm.accounting.enabled=true this will setup slurmdbd
# otherwise it will just define accounting_storage/none as the plugin
Include accounting.conf
# SuspendExcNodes is managed in /etc/slurm/keep_alive.conf
# see azslurm keep_alive for more information.
# you can also remove this import to remove support for azslurm keep_alive
Include keep_alive.conf
EOF

# Configure Hostname in slurmd.conf
echo "SlurmctldHost=$(hostname -s)" >> "$slurm_conf"

# Create cgroup.conf
cat <<EOF > "$sched_dir/cgroup.conf"
CgroupAutomount=no
ConstrainCores=yes
ConstrainRamSpace=yes
ConstrainDevices=yes
EOF

echo "# Do not edit this file. It is managed by azslurm" >> "$sched_dir/keep_alive.conf"

# Set limits for Slurm
cat <<EOF > /etc/security/limits.d/slurm-limits.conf
* soft memlock unlimited
* hard memlock unlimited
EOF

# Add accounting configuration
echo "AccountingStorageType=accounting_storage/none" >> "$sched_dir/accounting.conf"

# Set permissions and create symlinks

ln -s "$slurm_conf" /etc/slurm/slurm.conf
ln -s "$sched_dir/keep_alive.conf" /etc/slurm/keep_alive.conf
ln -s "$sched_dir/cgroup.conf" /etc/slurm/cgroup.conf
ln -s "$sched_dir/accounting.conf" /etc/slurm/accounting.conf
ln -s "$sched_dir/azure.conf" /etc/slurm/azure.conf
ln -s "$sched_dir/gres.conf" /etc/slurm/gres.conf 
touch "$sched_dir"/gres.conf "$sched_dir"/azure.conf
chown  slurm:slurm "$sched_dir"/*.conf
chmod 644 "$sched_dir"/*.conf
chown slurm:slurm /etc/slurm/*.conf

# Set up log and spool directories
mkdir -p /var/spool/slurmd /var/spool/slurmctld /var/log/slurmd /var/log/slurmctld
chown slurm:slurm /var/spool/slurmd /var/spool/slurmctld /var/log/slurmd /var/log/slurmctld
echo " "
echo "------------------------------------------------------------------------------------------------------------------------------"
echo "Slurm configured"
echo "------------------------------------------------------------------------------------------------------------------------------"
echo " "
echo "------------------------------------------------------------------------------------------------------------------------------"
echo " Go to CycleCloud Portal and edit the $cluster_name cluster configuration to use the external scheduler and start the cluster."
echo " Use $ip_address IP Address for File-system Mount for /sched and /shared in Network Attached Storage section in CycleCloud GUI "
echo " Once the cluster is started, proceed to run  cyclecloud-integrator.sh script to complete the integration with CycleCloud."
echo "------------------------------------------------------------------------------------------------------------------------------"
echo " "