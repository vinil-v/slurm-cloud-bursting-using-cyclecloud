#!/bin/sh
# This script builds a External Slurm scheduler for cloud bursting with Azure CycleCloud
# Author : Vinil Vadakkepurakkal
# Date : 13/5/2024
# Modified on : 23/9/2024 
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

ip_address=$(hostname -I | awk '{print $1}')
echo "------------------------------------------------------------------------------------------------------------------------------"
echo " "
echo "Summary of entered details:"
echo "Cluster Name: $cluster_name"
echo "Scheduler Hostname: $(hostname)"
echo "NFSServer IP Address: $ip_address"
echo " "
echo "------------------------------------------------------------------------------------------------------------------------------"

sched_dir="/sched/$cluster_name"
slurm_conf="$sched_dir/slurm.conf"
munge_key="/etc/munge/munge.key"
slurm_script_dir="/opt/azurehpc/slurm"
OS_VERSION=$(cat /etc/os-release  | grep VERSION_ID | cut -d= -f2 | cut -d\" -f2 | cut -d. -f1)
OS_ID=$(cat /etc/os-release  | grep ^ID= | cut -d= -f2 | cut -d\" -f2 | cut -d. -f1)
SLURM_VERSION="23.11.9"

# Create Munge and Slurm users
echo "------------------------------------------------------------------------------------------------------------------------------"
echo "Creating Munge and Slurm users"
echo "------------------------------------------------------------------------------------------------------------------------------"

groupadd -g 11101 munge
useradd -u 11101 -g 11101 -s /bin/false -M munge
groupadd -g 11100 slurm
useradd -u 11100 -g 11100 -s /bin/false -M slurm
echo "Munge and Slurm users created"

# Set up NFS server
echo "------------------------------------------------------------------------------------------------------------------------------"
echo "Setting up NFS server"
echo "------------------------------------------------------------------------------------------------------------------------------"
yum install -y nfs-utils
mkdir -p /sched /shared
echo "/sched *(rw,sync,no_root_squash)" >> /etc/exports
echo "/shared *(rw,sync,no_root_squash)" >> /etc/exports
systemctl start nfs-server.service
systemctl enable nfs-server.service
echo "NFS server setup complete"
showmount -e localhost

# setting up Microsoft repo
echo "------------------------------------------------------------------------------------------------------------------------------"
curl -sSL -O https://packages.microsoft.com/config/rhel/$OS_VERSION/packages-microsoft-prod.rpm
rpm -i packages-microsoft-prod.rpm
rm packages-microsoft-prod.rpm
echo "Microsoft repo setup complete"

# Install and configure Munge
echo "------------------------------------------------------------------------------------------------------------------------------"
echo "Installing and configuring Munge"
echo "------------------------------------------------------------------------------------------------------------------------------"
dnf install -y epel-release
dnf install -y munge munge-libs 
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
echo "Munge installed and configured"
echo "------------------------------------------------------------------------------------------------------------------------------"

# Install and configure Slurm
echo "------------------------------------------------------------------------------------------------------------------------------"
echo " Setting up Slurm repo"
cat <<EOF > /etc/yum.repos.d/slurm.repo
[slurm]
name=Slurm Workload Manager
baseurl=https://packages.microsoft.com/yumrepos/slurm-el8-insiders
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
priority=10
EOF
echo "Slurm repo setup complete"

slurm_packages="slurm slurm-slurmrestd slurm-libpmi slurm-devel slurm-pam_slurm slurm-perlapi slurm-torque slurm-openlava slurm-example-configs"
sched_packages="slurm-slurmctld slurm-slurmdbd"
for pkg in $slurm_packages; do
        yum -y install $pkg-${SLURM_VERSION}.el${OS_VERSION} --disableexcludes slurm
done
for pkg in $sched_packages; do
        yum -y install $pkg-${SLURM_VERSION}.el${OS_VERSION} --disableexcludes slurm
done
echo "------------------------------------------------------------------------------------------------------------------------------"
echo "Slurm installed"
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