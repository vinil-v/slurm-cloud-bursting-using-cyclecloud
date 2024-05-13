#!/bin/sh
# This script builds a External Slurm scheduler for cloud bursting with Azure CycleCloud
# Author : Vinil Vadakkepurakkal
# Date : 13/5/2024


# Define variables
clustername="hb2"
sched_dir="/sched/$clustername"
slurm_conf="$sched_dir/slurm.conf"
munge_key="/etc/munge/munge.key"


# Create Munge and Slurm users
groupadd -g 11101 munge
useradd -u 11101 -g 11101 -s /bin/false -M munge
groupadd -g 11100 slurm
useradd -u 11100 -g 11100 -s /bin/false -M slurm

# Set up NFS server
yum install -y nfs-utils
mkdir -p /sched /shared
echo "/sched *(rw,sync,no_root_squash)" >> /etc/exports
echo "/shared *(rw,sync,no_root_squash)" >> /etc/exports
systemctl start nfs-server.service
systemctl enable nfs-server.service

# Install and configure Munge
yum install -y epel-release
yum install -y munge munge-libs munge-devel
dd if=/dev/urandom bs=1 count=1024 > "$munge_key"
chown munge:munge "$munge_key"
chmod 400 "$munge_key"
systemctl start munge
systemctl enable munge
mkdir -p "$sched_dir"
cp "$munge_key" "$sched_dir/munge.key"
chown munge: "$sched_dir/munge.key"
chmod 400 "$sched_dir/munge.key"

# Install and configure Slurm
wget https://github.com/Azure/cyclecloud-slurm/releases/download/3.0.6/azure-slurm-install-pkg-3.0.6.tar.gz
tar -xvf azure-slurm-install-pkg-3.0.6.tar.gz
cd azure-slurm-install/slurm-pkgs-rhel8/RPMS/
yum localinstall slurm-*-23.02.7-1.el8.x86_64.rpm -y

# Configure Slurm
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
ClusterName=$clustername
JobAcctGatherType=jobacct_gather/none
SlurmctldDebug=debug
SlurmctldLogFile=/var/log/slurmctld/slurmctld.log
SlurmctldParameters=idle_on_node_suspend
SlurmdDebug=debug
SlurmdLogFile=/var/log/slurmd/slurmd.log
TreeWidth=65533
ResumeTimeout=1800
SuspendTimeout=600
SuspendTime=300
ResumeProgram=$slurm_script_dir/resume_program.sh
ResumeFailProgram=$slurm_script_dir/resume_fail_program.sh
SuspendProgram=$slurm_script_dir/suspend_program.sh
SchedulerParameters=max_switch_wait=24:00:00
MaxNodeCount=10000
Include azure.conf
Include accounting.conf
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
chown -R slurm:slurm "$sched_dir"
chmod 644 "$sched_dir"/*.conf
ln -s "$slurm_conf" /etc/slurm/slurm.conf
ln -s "$sched_dir/keep_alive.conf" /etc/slurm/keep_alive.conf
ln -s "$sched_dir/cgroup.conf" /etc/slurm/cgroup.conf
ln -s "$sched_dir/accounting.conf" /etc/slurm/accounting.conf
ln -s "$sched_dir/azure.conf" /etc/slurm/azure.conf
ln -s "$sched_dir/gres.conf" /etc/slurm/gres.conf 
chown slurm:slurm /etc/slurm/*.conf

# Set up log and spool directories
mkdir -p /var/spool/slurmd /var/spool/slurmctld /var/log/slurmd /var/log/slurmctld
chown slurm:slurm /var/spool/slurmd /var/spool/slurmctld /var/log/slurmd /var/log/slurmctld