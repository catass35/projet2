#!/bin/sh

# store key in file
terraform output ssh_private_key_pem > key.txt

# create infra display ssh banner
# Define the file you want to write to
output_file="ssh_banner"

# Locally create the banner file
touch $output_file

# Define some variables
jumphost_ips="jumphost ip $(terraform output jumphost_ip | tr -d '"')"
nat_gateway_ips="nat gateway ip $(terraform output nat_gateway_ip | tr -d '"')"
ansible_ips="ansible ip $(terraform output ansible_ips | tr -d '"')"
master_ips="master ip $(terraform output master_ips | tr -d '"')"
worker_ips="worker ip $(terraform output worker_ips | tr -d '"')"

# Use a here document to write multiple lines to the file, including variables
cat <<EOF > "$output_file"
******************************************************
** $jumphost_ips **
**                                                  **
** $nat_gateway_ips **
**                                                  **
** $ansible_ips **
**                                                  **
** $master_ips **
**                                                  **
** $worker_ips **
******************************************************
EOF

# Copy file to jumphost
# Define variables
remote_user="ubuntu"
remote_host=$(terraform output jumphost_ip | tr -d '"')"
remote_file="/etc/ssh/ssh_banner"
local_destination="ssh_banner"

# Use scp with StrictHostKeyChecking=no to copy the file
scp -o StrictHostKeyChecking=no -i key.txt "${remote_user}@${remote_host}:${remote_file}" "${local_destination}"

# Update ssh banner
ssh -o StrictHostKeyChecking=no -i key.txt "${remote_user}@${remote_host} "old_banner_line=$(/etc/ssh/sshd_config | grep Banner) | sudo sed -i "s|$old_banner_line|Banner $remote_file|g" "/etc/ssh/sshd_config" | sudo systemctl restart sshd"

# Echo command to connect to jumphost
echo "To connect to jumphost 'ssh -i key.txt ubuntu@$(terraform output jumphost_ip | tr -d '"')'"

