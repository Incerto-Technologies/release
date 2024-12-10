#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# Constants
AWS_REGION="ap-south-1"  # Replace with your AWS region
ECR_URL="public.ecr.aws/t9w7u8l8/incerto"
IMAGE_NAME="collector"
IMAGE_TAG="latest"
BACKEND_URL="https://your-backend-url.com/hostid"
CONTAINER_NAME="incerto-collector"

# Function to install Docker on Ubuntu
install_docker_ubuntu() {
    echo "Installing Docker on Ubuntu..."
    sudo apt-get update -y
    sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update -y
    sudo apt-get install -y docker-ce
    sudo systemctl enable docker
    sudo systemctl start docker
}

# Function to install Docker on RHEL
install_docker_rhel() {
    echo "Installing Docker on RHEL..."
    sudo yum update -y
    sudo yum install -y yum-utils
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo yum install -y docker-ce docker-ce-cli containerd.io
    sudo systemctl enable docker
    sudo systemctl start docker
}

# After installation: Set up Docker group and permissions
configure_docker_post_install() {
    echo "Configuring Docker group and permissions..."
    sudo groupadd docker || true  # Create the Docker group if it doesn't exist
    sudo usermod -aG docker $USER  # Add the current user to the Docker group
    newgrp docker  # Apply group changes immediately
    echo "Docker group configured. You can now run Docker commands without sudo."
}

# Check and install Docker
if ! command -v docker &> /dev/null
then
    echo "Docker not found. Installing Docker..."
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu) install_docker_ubuntu ;;
            rhel | centos | amzn) install_docker_rhel ;;
            *)
                echo "Unsupported OS. Only Ubuntu and RHEL are supported."
                exit 1
                ;;
        esac
    else
        echo "OS detection failed. Exiting."
        exit 1
    fi

    # Perform post-installation steps
    configure_docker_post_install
else
    echo "Docker is already installed. Skipping installation."
fi

# Pull the latest image from public ECR
echo "Pulling the latest Docker image from Public ECR..."
docker pull $ECR_URL/$IMAGE_NAME:$IMAGE_TAG

# Stop and remove the older container if it exists
if [ "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
    echo "Stopping existing container..."
    docker stop $CONTAINER_NAME
    docker rm $CONTAINER_NAME
fi

# Fetch hostID from backend
# echo "Fetching hostID from backend..."
# HOST_ID=$(curl -sf $BACKEND_URL)
# if [ -z "$HOST_ID" ]; then
#     echo "Failed to fetch hostID. Exiting."
#     exit 1
# fi
HOST_ID="0000000000"
echo "Fetched hostID: $HOST_ID"

# Run the new container
echo "Starting a new container with the latest image..."
docker run -d --name $CONTAINER_NAME -e HOST_ID="$HOST_ID" $ECR_URL/$IMAGE_NAME:$IMAGE_TAG

echo "Container is up and running."
