#!/bin/bash

# # Update the package repository
# sudo apt-get update -y

# # Install required packages
# sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common

# # Add Docker's official GPG key
# curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# # Add Docker's official repository
# echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# # Update the package repository with Docker's repo
# sudo apt-get update -y

# # Install Docker
# sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# # Start Docker service
# sudo systemctl start docker
# sudo systemctl enable docker

# # Run NGINX Docker container
# sudo docker run -d -p 80:80 --name nginx nginx:latest



sudo apt-get remove docker docker-engine docker.io

sudo apt-get update

sudo apt-get upgrade -y

sudo apt install docker.io -y

sudo systemctl start docker

sudo systemctl enable docker


# Run NGINX Docker container
sudo docker run -d -p 80:80 --name nginx nginx:latest