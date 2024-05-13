# Slurm Cloud Bursting Using CycleCloud

OS version: AlmaLinux release 8.7 ( almalinux:almalinux-hpc:8_7-hpc-gen2:latest )
CycleCloud version: 8.6.0-3223
Slurm version: 23.02.7-1
cyclecloud-slurm project : 3.0.6


On CycleCloud  VM:
I am importing a slurm headless cluster named hybridhpc for cloud bursting. 


git clone https://github.com/vinil-v/slurm-cloud-bursting-using-cyclecloud.git
cyclecloud import_cluster hybridhpc -c Slurm-HL -f slurm-cloud-bursting-using-cyclecloud/cyclecloud-template/slurm-headless.txt

On the External Scheduler run : 

git clone https://github.com/vinil-v/slurm-cloud-bursting-using-cyclecloud.git
cd slurm-cloud-bursting-using-cyclecloud/scripts
sh slurm-scheduler-builder.sh

