# Slurm Cloud Bursting Using CycleCloud

This repository provides detailed instructions and scripts for setting up Slurm bursting using CycleCloud on Microsoft Azure, allowing you to seamlessly scale your Slurm cluster into the cloud for additional compute resources.

## Overview

Slurm bursting enables the extension of your on-premises Slurm cluster into Azure for flexible and scalable compute capacity. CycleCloud simplifies the management and provisioning of cloud resources, bridging your local infrastructure with cloud environments.

## Requirements

Ensure you have the following prerequisites in place:

- **OS Version**: AlmaLinux release 8.7 (`almalinux:almalinux-hpc:8_7-hpc-gen2:latest`)
- **CycleCloud Version**: 8.6.0-3223
- **Slurm Version**: 23.02.7-1
- **cyclecloud-slurm Project**: 3.0.6

## Setup Instructions

### 1. On CycleCloud VM:

- Ensure CycleCloud 8.6 VM is running and accessible via `cyclecloud` CLI.
- Clone this repository and import a cluster using the provided CycleCloud template (`slurm-headless.txt`).

```bash
git clone https://github.com/vinil-v/slurm-cloud-bursting-using-cyclecloud.git
cyclecloud import_cluster hpc1 -c Slurm-HL -f slurm-cloud-bursting-using-cyclecloud/templates/slurm-headless.txt
```

Output :

```bash
[vinil@cc86 ~]$ cyclecloud import_cluster hpc1 -c Slurm-HL -f slurm-cloud-bursting-using-cyclecloud/cyclecloud-template/slurm-headless.txt
Importing cluster Slurm-HL and creating cluster hpc1....
----------
hpc1 : off
----------
Resource group:
Cluster nodes:
Total nodes: 0
```

### 2. Preparing Scheduler VM:

- Deploy a VM using the specified AlmaLinux image (If you have an existing Slurm Scheduler, you can skip this).
- Run the Slurm scheduler installation script (`slurm-scheduler-builder.sh`) and provide the cluster name (`hpc1`) when prompted.
- This script will install and configure Slurm Scheduler.

```bash
git clone https://github.com/vinil-v/slurm-cloud-bursting-using-cyclecloud.git
cd slurm-cloud-bursting-using-cyclecloud/scripts
sh slurm-scheduler-builder.sh
```
Output 

```bash
------------------------------------------------------------------------------------------------------------------------------
Building Slurm scheduler for cloud bursting with Azure CycleCloud
------------------------------------------------------------------------------------------------------------------------------

Enter Cluster Name: hpc1
------------------------------------------------------------------------------------------------------------------------------

Summary of entered details:
Cluster Name: hpc1
Scheduler Hostname: masternode2
NFSServer IP Address: 10.222.1.26
```

### 3. CycleCloud UI:

- Access the CycleCloud UI, edit the `hpc1` cluster settings, and configure VM SKUs and networking settings.
- Enter the NFS server IP address for `/sched` and `/shared` mounts in the Network Attached Storage section.
- Save & Start `hpc1` cluster

![NFS settings](images/NFSSettings.png)

### 4. On Slurm Scheduler Node:

- Integrate Slurm with CycleCloud using the `cyclecloud-integrator.sh` script.
- Provide CycleCloud details (username, password, and URL) when prompted.

```bash
cd slurm-cloud-bursting-using-cyclecloud/scripts
sh cyclecloud-integrator.sh
```
Output:

```bash
[root@masternode2 scripts]# sh cyclecloud-integrator.sh
Please enter the CycleCloud details to integrate with the Slurm scheduler

Enter Cluster Name: hpc1
Enter CycleCloud Username: vinil
Enter CycleCloud Password:
Enter CycleCloud URL (e.g., https://10.222.1.19): https://10.222.1.19
------------------------------------------------------------------------------------------------------------------------------

Summary of entered details:
Cluster Name: hpc1
CycleCloud Username: vinil
CycleCloud URL: https://10.222.1.19

------------------------------------------------------------------------------------------------------------------------------
```

### 5. User and Group Setup:

- Ensure consistent user and group IDs across all nodes.
- Better to use a centralized User Management system like LDAP to ensure the UID and GID are consistent across all the nodes.
- In this example we are using the `users.sh` script to create a test user `vinil` and group for job submission. (User `vinil` is exist in CycleCloud)

```bash
cd slurm-cloud-bursting-using-cyclecloud/scripts
sh users.sh
```

### 6. Testing & Job Submission:

- Log in as a test user (`vinil` in this example) on the Scheduler node.
- Submit a test job to verify the setup.

```bash
su - vinil
srun hostname &
```
Output:
```bash
[root@masternode2 scripts]# su - vinil
Last login: Tue May 14 04:54:51 UTC 2024 on pts/0
[vinil@masternode2 ~]$ srun hostname &
[1] 43448
[vinil@masternode2 ~]$ squeue
             JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST(REASON)
                 1       hpc hostname    vinil CF       0:04      1 hpc1-hpc-1
[vinil@masternode2 ~]$ hpc1-hpc-1
```
![Node Creation](images/nodecreation.png)

You should see the job running successfully, indicating a successful integration with CycleCloud.

For further details and advanced configurations, refer to the scripts and documentation within this repository.

---

These instructions provide a comprehensive guide for setting up Slurm bursting with CycleCloud on Azure. If you encounter any issues or have questions, please refer to the provided scripts and documentation for troubleshooting steps. Happy bursting!