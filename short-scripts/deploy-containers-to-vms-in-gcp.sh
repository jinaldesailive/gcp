########## Deploying Containers to Virtual Machines ##########
# Create VM with container image
gcloud compute instances create-with-container busybox-vm \
--container-image docker.io/busybox:1.27 \
--container-restart-policy on-failure --container-privileged
# Update containers inside VM
gcloud compute instances update-container busybox-amv \
--container-command "/bin/ash" --container-arg="-c" \
--container-arg="ls -l"
# Enable TTY and Stdin
gcloud compute instances update-container busybox-vm \ 
--container-tty \ 
--container-stdin
# Provide env variables for container
gcloud compute instances create-with-container busybox-vm \ 
--container-image docker.io/busybox:1.27 \ 
--container-env HOME=/home,MODE=test,OWNER=admin
# Provide env variables using file
gcloud compute instances create-with-container busybox-vm \ 
--container-image docker.io/busybox:1.27 \ 
--container-env-file ./env.txt
# env.txt file content looks like following
# This is an env.text file content 
HOME=/home 
MODE=test 
OWNER=admin
# Remove env variables
gcloud compute instances update-container busybox-vm \ 
--remove-container-env MODE,OWNER
# Mouning a host directory as a data volume
gcloud compute instances create-with-container busybox-vm \ 
--container-image docker.io/busybox:1.27 \ 
--container-mount-host-path mount-path=/logs,host-path=/tmp,mode=rw
# Removing volume mounts
gcloud compute instances update-container busybox-vm \ 
--remove-container-mounts /logs
# Mounting tempfs file system as a data volume
gcloud compute instances create-with-container busybox-vm \ 
--container-image docker.io/busybox:1.27 \ 
--container-mount-tmpfs mount-path=/cache
# Removing tempfs volume
gcloud compute instances update-container busybox-vm \ 
--remove-container-mounts /cache
# Creating and mounting persistent disks
gcloud compute instances create-with-container busybox-vm \ 
--disk name=my-data-disk \ 
--create-disk name=my-scratch-disk,auto-delete=yes,image=ubuntu-1710-artful-v20180315,image-project=ubuntu-os-cloud \ 
--container-image docker.io/busybox:1.27 \ 
--container-mount-disk mount-path="/disks/data-disk",name=my-data-disk,mode=ro \ 
--container-mount-disk mount-path="/disks/scratch-disk",name=my-scratch-disk
# Removing/Updating mounts
gcloud compute instances update-container busybox-vm \ 
--container-mount-disk mount-path="/disks/data-disk",name=my-data-disk,mode=rw \ 
--remove-container-mounts "/disks/scratch-disk"
# Allow traffic to VM containers
# Step 1: Create VM with NGINX container
gcloud compute instances create-with-container nginx-vm \ 
--container-image gcr.io/cloud-marketplace/google/nginx1:1.15 \ 
--tags http-server
# Step 2: Create a firewall
gcloud compute firewall-rules create allow-http \ 
--allow tcp:80 --target-tags http-server
# Debug VM Containers
gcloud beta compute ssh nginx-vm \ 
--zone=us-central1-a \
--container={CONTAINER-ID OR CONTAINER-NAME}
########## Deploying Containers to MIG (Managed Instance Group) ##########
# Create an instance template
gcloud compute instance-templates create-with-container nginx-instance-template \ 
--container-image=gcr.io/cloud-marketplace/google/nginx:1.20 \ 
--container-restart-policy on-failure \ 
--container-privileged
# Create an MIG with the Instance Template
gcloud compute instance-groups managed create nginx-group \ 
--base-instance-name nginx-vm \ 
--size 2 \ 
--template nginx-instance-template
# SSH your container image
gcloud beta compute ssh nginx-vm-{$$$$} \ 
--container nginx-instance-template
########## Create Autoscaling and Multi-zone MIG ##########
# Create MIG in multi-zone
gcloud compute instance-groups managed create nginx-group \ 
--base-instance-name nginx-vm \ 
--size 8 \ 
--template nginx-instance-template \ 
--zones us-east1-b,us-east1-c 
# Set autoscaling
gcloud compute instance-groups managed set-autoscaling nginx-group \ 
--max-num-replicas 20 \ 
--target-cpu-utilization 0.60 \ 
--cool-down-period 90