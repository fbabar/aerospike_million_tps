#!/bin/bash

. ./build_config.sh

# cleanup partial instance requests later <- bug
if [ ! -e $client_instance_file ]
then
  echo "Please launch nodes before building"
  exit 1
fi

# Load subnet and vpc id from infra file
subnet_id=$(cat $subnet_file)
security_group_id=$(cat $sg_file)

# Use the existing requests
instance_id_array=( $(cat $client_instance_file) )
instance_id_size=${#instance_id_array[@]}
for (( i=0; i<${instance_id_size}; i++ ));
do
  echo "Using ${instance_id_array[i]}"
done

test_value="failed"

# Load server IP addresses for client node setup
server_instance_id=$(cat $server_instance_file) # Only one server needed in million TPS test
server_ip_array=( $(ec2-describe-instances -region $region $server_instance_id | grep -w "^NIC" | cut -f 7) )
server_ip_count=${#server_ip_array[@]}

#all_server_ips=$(cat $server_private_ip_file)
#server_ip_array=(${all_server_ips// / })

for (( i=0; i<${instance_id_size}; i++ )); do
  client_instance_id=${instance_id_array[i]}
  echo "Waiting for instance: $client_instance_id to come up fully..."

  # Wait for the node to be in 'running' state
  while ! ec2-describe-instances -region $region $client_instance_id | grep -q 'running'; do sleep 1; done

  # Retrieve IP address
  client_instance_address=$(ec2-describe-instances -region $region $client_instance_id | grep '^INSTANCE' | awk '{print $12}')
  all_client_ips="$client_instance_address $all_client_ips"
  echo "Instance started: Host address is $client_instance_address"

  echo Performing instance setup
  while ! ssh-keyscan -t ecdsa $client_instance_address 2>/dev/null | grep -q $client_instance_address; do sleep 2; done
  ssh-keyscan -t ecdsa $client_instance_address >> ~/.ssh/known_hosts 2>/dev/null
  echo "Added $client_instance_address to known hosts"

  # Copy over client setup script and prebuilt ycsb
  scp -i $EC2_KEY_LOCATION setup_client.sh $EC2_USER@$client_instance_address:/tmp
  #scp -i $EC2_KEY_LOCATION ycsb*gz $EC2_USER@$client_instance_address:/tmp

  # Execute client setup script with correct server ip address
  let "ip_index=i%server_ip_count"
  server_ip=${server_ip_array[ip_index]}

  echo "Running client setup with $server_index: ${server_ip_array[server_index]} Records: $insert_start"
  ssh -i $EC2_KEY_LOCATION -t $EC2_USER@$client_instance_address "bash /tmp/setup_client.sh $server_ip"
  # ssh -i $EC2_KEY_LOCATION -t $EC2_USER@$client_instance_address "bash /tmp/setup_client.sh ${server_ip_array[server_index]} $insert_start $client_instance_address"
done

echo $all_client_ips > $client_ip_file
