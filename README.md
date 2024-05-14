# Slurm Cloud Bursting Using CycleCloud
This repository contains guidelines and resources for setting up Slurm bursting using CycleCloud, enabling you to dynamically scale your Slurm cluster on Microsoft Azurecloud resources.

# Overview
Slurm bursting allows you to extend your on-premises Slurm cluster into the cloud for additional compute resources when needed. CycleCloud facilitates the management and provisioning of cloud resources for your cluster, providing a seamless integration between your local infrastructure and cloud environments.

# Requirements
Before you begin, ensure you have the following:

OS version: AlmaLinux release 8.7 ( almalinux:almalinux-hpc:8_7-hpc-gen2:latest )
CycleCloud version: 8.6.0-3223
Slurm version: 23.02.7-1
cyclecloud-slurm project : 3.0.6

# Setup Instructions
1. On CycleCloud  VM:

CycleCloud 8.6 VM should be up and running and you should be able to use cyclecloud cli.
Clone the slurm-cloud-bursting-using-cyclecloud git repo and import a cluster using cyclecloud import_cluster command. In the below example the cluster name is hpc1.

git clone https://github.com/vinil-v/slurm-cloud-bursting-using-cyclecloud.git
cyclecloud import_cluster hpc1 -c Slurm-HL -f slurm-cloud-bursting-using-cyclecloud/cyclecloud-template/slurm-headless.txt

Once the Import is successful. DO NOT start the cluster now as we have few configuration is required to configure the external scheduler.

[vinil@cc86 ~]$ cyclecloud import_cluster hpc1 -c Slurm-HL -f slurm-cloud-bursting-using-cyclecloud/cyclecloud-template/slurm-headless.txt
Importing cluster Slurm-HL and creating cluster hpc1....
----------
hpc1 : off
----------
Resource group:
Cluster nodes:
Total nodes: 0


2. On Scheduler VM : 
Switch root user and run the following command to start the Slurm scheduler installation and configuration. You will be prompted to enter the Cluster Name used in the previous step. in this example it is hpc1.

git clone https://github.com/vinil-v/slurm-cloud-bursting-using-cyclecloud.git
cd slurm-cloud-bursting-using-cyclecloud/scripts
sh slurm-scheduler-builder.sh

[root@masternode2 scripts]# sh slurm-scheduler-builder.sh
Building Slurm scheduler for cloud bursting with Azure CycleCloud

Enter Cluster Name: hpc1

Summary of entered details:
Cluster Name: hpc1

It will automatically configure the slurm scheduler. 
