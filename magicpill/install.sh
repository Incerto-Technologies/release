#!/bin/bash

set -e  # exit immediately if a command exits with a non-zero status

# AWS credentials
AWS_ACCESS_KEY_ID="none"
AWS_SECRET_ACCESS_KEY="none"
AWS_REGION="ap-south-1"

# registry details
ECR_URL="none"

# frontend service
IMAGE_NAME_FRONTEND="frontend"
IMAGE_TAG_FRONTEND="latest"
CONTAINER_NAME_FRONTEND="incerto-frontend"

# backend service
IMAGE_NAME_BACKEND="backend"
IMAGE_TAG_BACKEND="latest"
CONTAINER_NAME_BACKEND="incerto-backend"

# ai service
IMAGE_NAME_AI="ai"
IMAGE_TAG_AI="latest"
CONTAINER_NAME_AI="incerto-ai"

# COLLECTOR_CONFIG_URL="none"
# COLLECTOR_CONFIG_FILE="config.yaml"
# COLLECTOR_CONFIG_BACKUP_FILE="config.yaml.bak"

# `.env`
# COLLECTOR_ENV_URL="https://raw.githubusercontent.com/Incerto-Technologies/release/refs/heads/main/collector/.env"
# COLLECTOR_ENV_FILE=".env"
# COLLECTOR_ENV_BACKUP_FILE=".env.bak"

# get url for 
SERVICE_URL="none"
# run collector for `worker` or `keeper`
DATABASE="none"
TYPE="none"
ENDPOINT="none"
USERNAME=""
PASSWORD=""

while [ $# -gt 0 ]; do
    case $1 in
        --aws-access-key-id)
            AWS_ACCESS_KEY_ID="$2"
            if [ -z "$AWS_ACCESS_KEY_ID" ]; then
                printf "[ERROR] Missing value for --aws-access-key-id. Please provide a valid AWS key ID.\n"
                exit 1
            fi
            shift 2
            ;;
        --aws-secret-access-key)
            AWS_SECRET_ACCESS_KEY="$2"
            if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
                printf "[ERROR] Missing value for --aws-secret-access-key. Please provide a valid AWS access key.\n"
                exit 1
            fi
            shift 2
            ;;
        --aws-region)
            AWS_REGION="$2"
            if [ -z "$AWS_REGION" ]; then
                printf "[ERROR] Missing value for --aws-region. Please provide a valid AWS region value.\n"
                exit 1
            fi
            shift 2
            ;;
        *)
            printf "[ERROR] Unknown option: $1\n"
            exit 1
            ;;
    esac
done

printf "\n[INFO] Proceeding with using \n\n    service-url: $SERVICE_URL \n    database: $DATABASE \n    type: $TYPE \n    endpoint: $ENDPOINT \n    username: $USERNAME \n    password: $PASSWORD\n\n"

# Validate database and type combinations  
# Determine the correct config.yaml URL based on the type
if [ "$DATABASE" = "clickhouse" ]; then
    if [ "$TYPE" != "worker" ] && [ "$TYPE" != "keeper" ]; then
        printf "[ERROR] Invalid type for clickhouse. Allowed values are 'worker' or 'keeper'.\n"
        exit 1
    fi
    COLLECTOR_CONFIG_URL="https://raw.githubusercontent.com/Incerto-Technologies/release/refs/heads/main/collector/$DATABASE/$TYPE/config.yaml"
elif [ "$DATABASE" = "postgres" ]; then
    if [ "$TYPE" != "master" ] && [ "$TYPE" != "replica" ]; then
        printf "[ERROR] Invalid type for postgres. Allowed values are 'master' or 'replica'.\n"
        exit 1
    fi
    COLLECTOR_CONFIG_URL="https://raw.githubusercontent.com/Incerto-Technologies/release/refs/heads/main/collector/$DATABASE/$TYPE/config.yaml"
else
    printf "[ERROR] Unsupported database type. Allowed values are 'clickhouse' or 'postgres'.\n"
    exit 1
fi

# function to install Docker on Ubuntu
install_docker_ubuntu() {
    printf "[INFO] Installing Docker on Ubuntu ...\n"
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
    printf "[SUCCESS] Docker installed successfully on UBUNTU.\n"
}

# Function to check and install AWS CLI
install_awscli() {
    if command -v aws &> /dev/null; then
        printf "[INFO] AWS CLI is already installed on this machine.\n\n"
        return 0
    fi

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu) 
                sudo snap install aws-cli --classic
                ;;
            rhel | centos | amzn) 
                sudo yum install -y aws-cli
                ;;
            *)
                printf "[ERROR] Unsupported operating system. Only Ubuntu, RHEL, CentOS, and Amazon Linux are supported.\n"
                exit 1
                ;;
        esac
    else
        printf "[ERROR] OS detection failed. Unable to proceed.\n"
        exit 1
    fi
}

# Call the function
install_awscli

# function to install Docker on RHEL
install_docker_rhel() {
    printf "[INFO] Installing Docker on RHEL ...\n"
    # Check for Amazon Linux version
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [ "$ID" = "amzn" ] && [ "$VERSION_ID" = "2" ]; then
            printf "[INFO] Detected Amazon Linux 2. Installing Docker for Amazon Linux 2 ...\n"
            sudo yum update -y
            sudo amazon-linux-extras enable docker
            sudo yum install -y docker
            sudo systemctl start docker
            sudo systemctl enable docker
            printf "[SUCCESS] Docker installed on Amazon Linux 2.\n"
            return
        elif [ "$ID" = "amzn" ] && [ "$VERSION_ID" = "2023" ]; then
            printf "[INFO] Detected Amazon Linux 2023. Installing Docker for Amazon Linux 2023 ...\n"
            sudo yum update -y
            sudo dnf install -y docker
            sudo systemctl start docker
            sudo systemctl enable docker
            printf "[SUCCESS] Docker installed on Amazon Linux 2023.\n"
            return
        else
            printf "[INFO] Detected RHEL. Installing Docker for RHEL ...\n"
            sudo dnf remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine podman runc
            sudo dnf -y install dnf-plugins-core
            sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
            sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            sudo systemctl enable --now docker
            printf "[SUCCESS] Docker installed on RHEL.\n"
            return
        fi
    fi
}

# after installation: set up Docker group and permissions
configure_docker_post_install() {
    printf "[INFO] Configuring Docker group and permissions ...\n"
    sudo groupadd docker || true  # Create the Docker group if it doesn't exist
    sudo usermod -aG docker $USER  # Add the current user to the Docker group
    printf "[SUCCESS] Docker group configured. Please logout and log back in. \n[INFO] And run the same command."
}

# check and install Docker
install_docker() {
    if [ -x /usr/bin/docker ] || [ -x /usr/local/bin/docker ]; then
        printf "[INFO] Docker is already installed on this machine.\n\n"
        return 0
    fi
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu) install_docker_ubuntu ;;
            rhel | centos | amzn) install_docker_rhel ;;
            *)
                printf "[ERROR] Unsupported operating system. Only Ubuntu and RHEL are supported.\n"
                exit 1
                ;;
        esac
        # Perform post-installation steps
        configure_docker_post_install
        exit 0
    else
        printf "[ERROR] OS detection failed. Unable to proceed.\n"
        exit 1
    fi
}

# update env file
update_env_file() {
    KEY="$1"   # The key to update or add (e.g., "HOST_ID")
    VALUE="$2" # The value to set for the key

    printf "[INFO] Updating $COLLECTOR_ENV_FILE with $KEY=$VALUE\n"

    # Check if the .env file exists
    if [ ! -f "$COLLECTOR_ENV_FILE" ]; then
        printf "[INFO] $COLLECTOR_ENV_FILE does not exist. Creating a new one.\n"
        echo "$KEY=$VALUE" > "$COLLECTOR_ENV_FILE"
        printf "[SUCCESS] $KEY added to $COLLECTOR_ENV_FILE.\n\n"
    else
        # Check if the key already exists
        if grep -q "^$KEY=" "$COLLECTOR_ENV_FILE"; then
            printf "[INFO] $KEY already exists in $COLLECTOR_ENV_FILE. Updating it.\n"
            sed -i "s/^$KEY=.*/$KEY=$VALUE/" "$COLLECTOR_ENV_FILE"  # Update the existing value
            printf "[SUCCESS] $KEY updated in $COLLECTOR_ENV_FILE.\n\n"
        else
            printf "[INFO] $KEY not found in $COLLECTOR_ENV_FILE. Adding it.\n"
            echo "$KEY=$VALUE" >> "$COLLECTOR_ENV_FILE"  # Append the new key-value pair with a preceeding newline
            printf "[SUCCESS] $KEY added to $COLLECTOR_ENV_FILE.\n\n"
        fi
    fi
}

# check Docker permission
check_docker_permissions() {
    printf "[INFO] Checking Docker permissions for the current user ...\n"
    if groups $USER | grep -q '\bdocker\b'; then
        printf "[INFO] User \`$USER\` already has access to Docker without sudo.\n"
    else
        printf "[INFO] User \`$USER\` does not have access to Docker without sudo.\n"
        printf "[INFO] Adding user \`$USER\` to the \`docker\` group ...\n"
        sudo usermod -aG docker $USER
        printf "[INFO] User \`$USER\` added to the \`docker\` group.\n"
        printf "[SUCCESS] User added to Docker group. Please logout and log back in. \n[INFO] Run the same command: curl -sfL https://raw.githubusercontent.com/Incerto-Technologies/release/refs/heads/main/collector/install.sh | sh -s -- --service-url $SERVICE_URL --type $TYPE"
        exit 0
    fi
}

# setup AWS ECR
setup_ecr() {
    # pull the latest image from public ECR
    printf "[INFO] Pulling the latest Docker image from Public ECR ...\n"
    docker pull $ECR_URL/$IMAGE_NAME:$IMAGE_TAG

    aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
    aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
    aws configure set region $AWS_REGION

}

# setup and run Frontend service
run_frontend() {
    # Run the new container
    printf "[INFO] Starting a new container with the latest image...\n"
    docker run -d --name incerto-collector --restart=always --env-file $(pwd)/.env --network host -v $(pwd)/config.yaml:/config.yaml $ECR_URL/$IMAGE_NAME:$IMAGE_TAG
    printf "\n                      Frontend service is up and running.                      \n"
}

# setup and run Backend service
run_backend() {
    # Run the new container
    printf "[INFO] Starting a new container with the latest image...\n"
    docker run -d --name incerto-collector --restart=always --env-file $(pwd)/.env --network host -v $(pwd)/config.yaml:/config.yaml $ECR_URL/$IMAGE_NAME:$IMAGE_TAG
    printf "\n                      Backend service is up and running.                      \n"
}

# setup and run AI service
run_ai() {
    # Run the new container
    printf "[INFO] Starting a new container with the latest image...\n"
    docker run -d --name incerto-collector --restart=always --env-file $(pwd)/.env --network host -v $(pwd)/config.yaml:/config.yaml $ECR_URL/$IMAGE_NAME:$IMAGE_TAG
    printf "\n                      AI service is up and running.                      \n"
}


install_docker
 
check_docker_permissions

setup_ecr

run_frontend

run_backend

run_ai

# update env variables
# update_env_file "HOST_ID" "$HOST_ID"
# update_env_file "SERVICE_URL" "$SERVICE_URL"
# if [ "$DATABASE" = "clickhouse" ]; then
#     update_env_file "CLICKHOUSE_ENDPOINT" "$ENDPOINT"
#     update_env_file "CLICKHOUSE_USERNAME" "$USERNAME"
#     update_env_file "CLICKHOUSE_PASSWORD" "$PASSWORD"
# elif [ "$DATABASE" = "postgres" ]; then
#     update_env_file "POSTGRES_ENDPOINT" "$ENDPOINT"
#     update_env_file "POSTGRES_USERNAME" "$USERNAME"
#     update_env_file "POSTGRES_PASSWORD" "$PASSWORD"
# else
#     printf "[INFO] Nothing to update\n"
# fi

printf "\n************************************************************************\n"
printf "                                                                        \n"
printf "d888888b   d8b   db    .o88b.   d88888b   d8888b.   d888888b    .d88b.  \n"
printf "   88      888o  88   d8P  Y8   88        88   8D    ~~88~~    .8P  Y8. \n"
printf "   88      88V8o 88   8P        88ooooo   88oobY       88      88    88 \n"
printf "   88      88 V8o88   8b        88~~~~~   88 8b        88      88    88 \n"
printf "  .88.     88  V888   Y8b  d8   88.       88  88.      88       8b  d8  \n"
printf "Y888888P   VP   V8P     Y88P    Y88888P   88   YD      YP        Y88P   \n"
printf "                                                                        \n"
printf "                      Incerto Technologies Pvt Ltd                      \n"
printf "                           https://incerto.in                           \n"
printf "                                                                        \n"
printf "************************************************************************\n"
