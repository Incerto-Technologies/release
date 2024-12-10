#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

ECR_URL="public.ecr.aws/t9w7u8l8/incerto"
IMAGE_NAME="collector"
IMAGE_TAG="latest"
CONTAINER_NAME="incerto-collector"

# To get `HOST_ID` for a unique host
BACKEND_ENDPOINT="http://localhost:8080"

# `config.yaml`
COLLECTOR_CONFIG_URL="https://raw.githubusercontent.com/Incerto-Technologies/collector/refs/heads/main/config.yaml"  
COLLECTOR_CONFIG_FILE="config.yaml"
COLLECTOR_CONFIG_BACKUP_FILE="config.yaml.bak"

# `.env`
COLLECTOR_ENV_URL="https://raw.githubusercontent.com/Incerto-Technologies/collector/refs/heads/main/.env"
COLLECTOR_ENV_FILE=".env"
COLLECTOR_ENV_BACKUP_FILE=".env.bak"

# Function to install Docker on Ubuntu
install_docker_ubuntu() {
    echo "[INFO] Installing Docker on Ubuntu..."
    sudo apt-get update -y
    sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
    if [ -f /usr/share/keyrings/docker-archive-keyring.gpg ]; then
        sudo rm -f /usr/share/keyrings/docker-archive-keyring.gpg
    fi
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update -y
    sudo apt-get install -y docker-ce
    sudo systemctl enable docker
    sudo systemctl start docker
    echo "[SUCCESS] Docker installed successfully on UBUNTU."
}

# Function to install Docker on RHEL
install_docker_rhel() {
    echo "[INFO] Installing Docker on RHEL..."
    # Check for Amazon Linux version
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" == "amzn" && "$VERSION_ID" == "2" ]]; then
            echo "[INFO] Detected Amazon Linux 2. Installing Docker for Amazon Linux 2..."
            sudo yum update -y
            sudo amazon-linux-extras enable docker
            sudo yum install -y docker
            sudo systemctl start docker
            sudo systemctl enable docker
            echo "[SUCCESS] Docker installed on Amazon Linux 2."
            return
        elif [[ "$ID" == "amzn" && "$VERSION_ID" == "2023" ]]; then
            echo "[INFO] Detected Amazon Linux 2023. Installing Docker for Amazon Linux 2023..."
            sudo yum update -y
            sudo dnf install -y docker
            sudo systemctl start docker
            sudo systemctl enable docker
            echo "[SUCCESS] Docker installed on Amazon Linux 2023."
            return
        else
            echo "[INFO] Detected RHEL. Installing Docker for RHEL..."
            sudo dnf remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine podman runc
            sudo dnf -y install dnf-plugins-core
            sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
            sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            sudo systemctl enable --now docker
            return
        fi
    fi
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
if command -v docker &> /dev/null && docker --version &> /dev/null; then
    echo "[INFO] Docker is already installed. Version: $(docker --version)"
else
    echo "[INFO] Docker is not installed. Proceeding with installation..."
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

# Download .env file and handle backup if it already exists
echo "[INFO] Checking for an existing configuration file..."
if [ -f "$COLLECTOR_ENV_FILE" ]; then
    echo "[INFO] Configuration file found. Creating a backup..."
    mv "$COLLECTOR_ENV_FILE" "$COLLECTOR_ENV_BACKUP_FILE"
    echo "[SUCCESS] Backup created as $COLLECTOR_ENV_BACKUP_FILE."
fi

echo "[INFO] Downloading the latest configuration file..."
curl -fsSL -o "$COLLECTOR_ENV_FILE" "$COLLECTOR_ENV_URL"
if [ $? -ne 0 ]; then
    echo "[ERROR] Failed to download the configuration file. Exiting."
    exit 1
fi
echo "[SUCCESS] Configuration file downloaded successfully."

# Fetch hostID from backend
# echo "[INFO] Fetching hostID from the backend..."
# HOST_ID=$(curl -sf $BACKEND_ENDPOINT)
# if [ -z "$HOST_ID" ]; then
#     echo "[ERROR] Failed to fetch hostID. Exiting."
#     exit 1
# fi
HOST_ID="00000000000000000000000000"
echo "[INFO] HostID fetched: $HOST_ID"

# Run the new container
echo "[INFO] Starting a new container with the latest image..."
docker run -d --name incerto-collector --env-file ./.env -v $(pwd)/config.yaml:/config.yaml -e HOST_ID="$HOST_ID" $ECR_URL/$IMAGE_NAME:$IMAGE_TAG 

echo "[SUCCESS] Container is up and running."
