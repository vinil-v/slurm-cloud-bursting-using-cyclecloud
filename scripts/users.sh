#!/bin/bash
# Create a shared home directory for Test user
# Make sure to replace the username, gid, and uid with the desired values
# In Cyclecloud, user is created with the username 'vinil' and uid and gid are 20001
# We need to make sure that we create the proper uid and gid for the user in scheduler.
# Author : Vinil Vadakkepurakkal
# Date : 13/5/2024


username="vinil"
gid=20001
uid=20001

mkdir -p /shared/home/
chmod 755 /shared/home/

# Create group if not exists
if ! getent group $gid >/dev/null; then
    groupadd -g $gid $username
fi

# Create user with specified uid, gid, home directory, and shell
useradd -g $gid -u $uid -d /shared/home/$username -s /bin/bash $username

# Switch to user to perform directory and file operations
su - $username -c "mkdir -p /shared/home/$username/.ssh"
su - $username -c "ssh-keygen -t rsa -N '' -f /shared/home/$username/.ssh/id_rsa"
su - $username -c "cat /shared/home/$username/.ssh/id_rsa.pub >> /shared/home/$username/.ssh/authorized_keys"
su - $username -c "chmod 600 /shared/home/$username/.ssh/authorized_keys"
su - $username -c "chmod 700 /shared/home/$username/.ssh"