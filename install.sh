#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# Constants
AWS_REGION="ap-south-1"  # Replace with your AWS region
ECR_URL="public.ecr.aws/t9w7u8l8/incerto"
IMAGE_NAME="collector"
IMAGE_TAG="latest"
BACKEND_URL="https://your-backend-url.com/hostid"
CONTAINER_NAME="incerto-collector"
COLLECTOR_CONFIG_URL="https://raw.githubusercontent.com/Incerto-Technologies/collector/refs/heads/main/config.yaml"  # URL to download the config file
COLLECTOR_CONFIG_FILE="config.yaml"
COLLECTOR_CONFIG_BACKUP_FILE="config.yaml.bak"

# Function to install Docker on Ubuntu
install_docker_ubuntu() {
    echo "[INFO] Installing Docker on Ubuntu..."
    sudo apt-get update -y
    sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common

    # Remove existing keyring file if it exists to avoid prompts
    if [ -f /usr/share/keyrings/docker-archive-keyring.gpg ]; then
        echo "[INFO] Removing existing Docker GPG keyring file..."
        sudo rm -f /usr/share/keyrings/docker-archive-keyring.gpg
        echo "[SUCCESS] Removed existing Docker GPG keyring file."
    fi

    # Download and save the GPG key
    echo "[INFO] Downloading Docker GPG key..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "[SUCCESS] Docker GPG key downloaded and saved."

    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update -y
    sudo apt-get install -y docker-ce
    sudo systemctl enable docker
    sudo systemctl start docker
}

# Function to install Docker on RHEL
install_docker_rhel() {
    echo "[INFO] Installing Docker on RHEL..."
    sudo yum update -y
    sudo yum install -y yum-utils
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo yum install -y docker-ce docker-ce-cli containerd.io
    sudo systemctl enable docker
    sudo systemctl start docker
}

# After installation: Set up Docker group and permissions
configure_docker_post_install() {
    echo "[INFO] Configuring Docker group and permissions..."
    sudo groupadd docker || true  # Create the Docker group if it doesn't exist
    sudo usermod -aG docker $USER  # Add the current user to the Docker group
    newgrp docker  # Apply group changes immediately
    echo "[SUCCESS] Docker group configured. You can now run Docker commands without sudo."
}

# Check and install Docker
if ! command -v docker &> /dev/null
then
    echo "[INFO] Docker not found. Starting installation process..."
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu) install_docker_ubuntu ;;
            rhel | centos | amzn) install_docker_rhel ;;
            *)
                echo "[ERROR] Unsupported operating system. Only Ubuntu and RHEL are supported."
                exit 1
                ;;
        esac
    else
        echo "[ERROR] OS detection failed. Unable to proceed."
        exit 1
    fi

    # Perform post-installation steps
    configure_docker_post_install
else
    echo "[INFO] Docker is already installed. Skipping installation."
fi

# Pull the latest image from public ECR
echo "[INFO] Pulling the latest Docker image from Public ECR..."
docker pull $ECR_URL/$IMAGE_NAME:$IMAGE_TAG

# Stop and remove the existing container if it exists
if [ "$(docker ps -aq -f name=$CONTAINER_NAME)" ]; then
    echo "[INFO] A container with the name $CONTAINER_NAME already exists. Removing it..."
    docker rm -f $CONTAINER_NAME
    echo "[SUCCESS] Existing container removed."
else
    echo "[INFO] No existing container with the name $CONTAINER_NAME found."
fi

# Download config file and handle backup if it already exists
echo "[INFO] Checking for an existing configuration file..."
if [ -f "$COLLECTOR_CONFIG_FILE" ]; then
    echo "[INFO] Configuration file found. Creating a backup..."
    mv "$COLLECTOR_CONFIG_FILE" "$COLLECTOR_CONFIG_BACKUP_FILE"
    echo "[SUCCESS] Backup created as $COLLECTOR_CONFIG_BACKUP_FILE."
fi

echo "[INFO] Downloading the latest configuration file..."
curl -fsSL -o "$COLLECTOR_CONFIG_FILE" "$COLLECTOR_CONFIG_URL"
if [ $? -ne 0 ]; then
    echo "[ERROR] Failed to download the configuration file. Exiting."
    exit 1
fi
echo "[SUCCESS] Configuration file downloaded successfully."

# Start the new container
echo "[INFO] Starting a new container with the latest image..."
docker run -d --name $CONTAINER_NAME -e HOST_ID="$HOST_ID" $ECR_URL/$IMAGE_NAME:$IMAGE_TAG

echo "[SUCCESS] Container is up and running."
