#!/bin/bash

set -e  # exit immediately if a command exits with a non-zero status

# fetch private and public IPs
PRIVATE_IP=$(hostname -I | awk '{print $1}')
PUBLIC_IP=$(curl -sf http://checkip.amazonaws.com)

# registry details
ECR_URL="public.ecr.aws/t9w7u8l8/incerto"
IMAGE_NAME="collector"
IMAGE_TAG="latest"
CONTAINER_NAME="incerto-collector"

COLLECTOR_CONFIG_URL="none"
COLLECTOR_CONFIG_FILE="config.yaml"
COLLECTOR_CONFIG_BACKUP_FILE="config.yaml.bak"

# `.env`
COLLECTOR_ENV_URL="https://raw.githubusercontent.com/Incerto-Technologies/release/refs/heads/main/collector/.env"
COLLECTOR_ENV_FILE=".env"
COLLECTOR_ENV_BACKUP_FILE=".env.bak"

# get url for 
SERVICE_URL="none"
# run collector for `worker` or `keeper`
TYPE="none"

while [[ $# -gt 0 ]]; do
    case $1 in
        --service-url)
            SERVICE_URL="$2"
            shift 2
            ;;
        --type)
            TYPE="$2"
            if [[ "$TYPE" != "worker" && "$TYPE" != "keeper" ]]; then
                echo -e "[ERROR] Invalid value for --type. Allowed values are 'worker' or 'keeper'."
                exit 1
            fi
            shift 2
            ;;
        *)
            echo -e "[ERROR] Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check if the `service-url` argument is provided
if [ -z "$SERVICE_URL" ]; then
    echo -e "[ERROR] The --service-url argument is required."
    exit 1
fi

# Check if the `type` argument is provided and valid
if [ -z "$TYPE" ]; then
    echo -e "[ERROR] The --type argument is required. Allowed values are 'worker' or 'keeper'."
    exit 1
fi

echo -e "\n[INFO] Using SERVICE_URL: $SERVICE_URL\n\n"

# Determine the correct config.yaml URL based on the type
if [ "$TYPE" == "worker" ]; then
    COLLECTOR_CONFIG_URL="https://raw.githubusercontent.com/Incerto-Technologies/release/refs/heads/main/collector/worker/config.yaml"
elif [ "$TYPE" == "keeper" ]; then
    COLLECTOR_CONFIG_URL="https://raw.githubusercontent.com/Incerto-Technologies/release/refs/heads/main/collector/keeper/config.yaml"
else
    echo -e "[ERROR] Invalid type provided. Allowed values are 'worker' or 'keeper'."
    exit 1
fi

# function to install Docker on Ubuntu
install_docker_ubuntu() {
    echo -e "[INFO] Installing Docker on Ubuntu ..."
    sudo apt-get update -y
    sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
    if [ -f /usr/share/keyrings/docker-archive-keyring.gpg ]; then
        sudo rm -f /usr/share/keyrings/docker-archive-keyring.gpg
    fi
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo -e "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update -y
    sudo apt-get install -y docker-ce
    sudo systemctl enable docker
    sudo systemctl start docker
    echo -e "[SUCCESS] Docker installed successfully on UBUNTU."
}

# function to install Docker on RHEL
install_docker_rhel() {
    echo -e "[INFO] Installing Docker on RHEL ..."
    # Check for Amazon Linux version
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" == "amzn" && "$VERSION_ID" == "2" ]]; then
            echo -e "[INFO] Detected Amazon Linux 2. Installing Docker for Amazon Linux 2 ..."
            sudo yum update -y
            sudo amazon-linux-extras enable docker
            sudo yum install -y docker
            sudo systemctl start docker
            sudo systemctl enable docker
            echo -e "[SUCCESS] Docker installed on Amazon Linux 2."
            return
        elif [[ "$ID" == "amzn" && "$VERSION_ID" == "2023" ]]; then
            echo -e "[INFO] Detected Amazon Linux 2023. Installing Docker for Amazon Linux 2023 ..."
            sudo yum update -y
            sudo dnf install -y docker
            sudo systemctl start docker
            sudo systemctl enable docker
            echo -e "[SUCCESS] Docker installed on Amazon Linux 2023."
            return
        else
            echo -e "[INFO] Detected RHEL. Installing Docker for RHEL ..."
            sudo dnf remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine podman runc
            sudo dnf -y install dnf-plugins-core
            sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
            sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            sudo systemctl enable --now docker
            echo -e "[SUCCESS] Docker installed on RHEL."
            return
        fi
    fi
}

# after installation: set up Docker group and permissions
configure_docker_post_install() {
    echo -e "[INFO] Configuring Docker group and permissions ..."
    sudo groupadd docker || true  # Create the Docker group if it doesn't exist
    sudo usermod -aG docker $USER  # Add the current user to the Docker group
    echo -e "[SUCCESS] Docker group configured. Please logout and log back in. \n[INFO] Run the same command: curl -sfL https://raw.githubusercontent.com/Incerto-Technologies/release/refs/heads/main/collector/install.sh | sh -s -- --service-url $SERVICE_URL --type $TYPE"
}

# check and install Docker
install_docker() {
    if [ -x /usr/bin/docker ] || [ -x /usr/local/bin/docker ]; then
        echo -e "[INFO] Docker is already installed on this machine.\n\n"
        return 0
    fi
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu) install_docker_ubuntu ;;
            rhel | centos | amzn) install_docker_rhel ;;
            *)
                echo -e "[ERROR] Unsupported operating system. Only Ubuntu and RHEL are supported."
                exit 1
                ;;
        esac
        # Perform post-installation steps
        configure_docker_post_install
        exit 0
    else
        echo -e "[ERROR] OS detection failed. Unable to proceed."
        exit 1
    fi
}

# check and install jq
install_jq() {
    if [ -x /usr/bin/jq ] || [ -x /usr/local/bin/jq ]; then
        echo -e "[INFO] jq is already installed on this machine.\n\n"
        return 0
    fi
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu) sudo apt-get install -y jq ;;
            rhel | centos | amzn) sudo yum install -y jq  ;;
            *)
                echo -e "[ERROR] Unsupported operating system. Only Ubuntu and RHEL are supported."
                exit 1
                ;;
        esac
    else
        echo -e "[ERROR] OS detection failed. Unable to proceed."
        exit 1
    fi
}

update_env_file() {
    KEY="$1"   # The key to update or add (e.g., "HOST_ID")
    VALUE="$2" # The value to set for the key

    echo -e "[INFO] Updating $COLLECTOR_ENV_FILE with $KEY=$VALUE"

    # Check if the .env file exists
    if [ ! -f "$COLLECTOR_ENV_FILE" ]; then
        echo -e "[INFO] $COLLECTOR_ENV_FILE does not exist. Creating a new one."
        echo -e "$KEY=$VALUE" > "$COLLECTOR_ENV_FILE"
        echo -e "[SUCCESS] $KEY added to $COLLECTOR_ENV_FILE.\n\n"
    else
        # Check if the key already exists
        if grep -q "^$KEY=" "$COLLECTOR_ENV_FILE"; then
            echo -e "[INFO] $KEY already exists in $COLLECTOR_ENV_FILE. Updating it."
            sed -i "s/^$KEY=.*/$KEY=$VALUE/" "$COLLECTOR_ENV_FILE"  # Update the existing value
            echo -e "[SUCCESS] $KEY updated in $COLLECTOR_ENV_FILE.\n\n"
        else
            echo -e "[INFO] $KEY not found in $COLLECTOR_ENV_FILE. Adding it."
            echo -e "$KEY=$VALUE" >> "$COLLECTOR_ENV_FILE"  # Append the new key-value pair
            echo -e "[SUCCESS] $KEY added to $COLLECTOR_ENV_FILE.\n\n"
        fi
    fi
}

check_docker_permissions() {
    echo -e "[INFO] Checking Docker permissions for the current user ..."
    if groups $USER | grep -q '\bdocker\b'; then
        echo -e "[INFO] User \`$USER\` already has access to Docker without sudo.\n"
    else
        echo -e "[INFO] User \`$USER\` does not have access to Docker without sudo."
        echo -e "[INFO] Adding user \`$USER\` to the \`docker\` group ..."
        sudo usermod -aG docker $USER
        echo -e "[INFO] User \`$USER\` added to the \`docker\` group."
        echo -e "[SUCCESS] User added to Docker group. Please logout and log back in. \n[INFO] Run the same command: curl -sfL https://raw.githubusercontent.com/Incerto-Technologies/release/refs/heads/main/collector/install.sh | sh -s -- --service-url $SERVICE_URL --type $TYPE"
        exit 0
    fi
}


install_docker

check_docker_permissions

install_jq

# pull the latest image from public ECR
echo -e "[INFO] Pulling the latest Docker image from Public ECR ..."
docker pull $ECR_URL/$IMAGE_NAME:$IMAGE_TAG

# stop and remove the existing container if it exists
if [ "$(docker ps -aq -f name=$CONTAINER_NAME)" ]; then
    echo -e "[INFO] A container with the name $CONTAINER_NAME already exists. Removing it ..."
    docker rm -f $CONTAINER_NAME
    echo -e "[SUCCESS] Existing container removed.\n\n"
else
    echo -e "[INFO] No existing container with the name $CONTAINER_NAME found.\n\n"
fi

# download `config.yaml` file and handle backup if it already exists
# the `config.yaml` changes depending on the type (worker vs keeper) 
echo -e "[INFO] Checking for an existing \`config.yaml\` file ..."
if [ -f "$COLLECTOR_CONFIG_FILE" ]; then
    echo -e "[INFO] \`config.yaml\` file found. Creating a backup ..."
    mv "$COLLECTOR_CONFIG_FILE" "$COLLECTOR_CONFIG_BACKUP_FILE"
    echo -e "[SUCCESS] Backup created as $COLLECTOR_CONFIG_BACKUP_FILE."
fi

echo -e "[INFO] Downloading the latest \`config.yaml\` file ..."
curl -fsSL -o "$COLLECTOR_CONFIG_FILE" "$COLLECTOR_CONFIG_URL"
if [ $? -ne 0 ]; then
    echo -e "[ERROR] Failed to download the \`config.yaml\` file. Exiting.\n\n"
    exit 1
fi
echo -e "[SUCCESS] \`config.yaml\` file downloaded successfully.\n\n"

# download `.env`` file and handle backup if it already exists
echo -e "[INFO] Checking for an existing \`.env\` file ..."
if [ -f "$COLLECTOR_ENV_FILE" ]; then
    echo -e "[INFO] \`.env\` file found. Creating a backup ..."
    mv "$COLLECTOR_ENV_FILE" "$COLLECTOR_ENV_BACKUP_FILE"
    echo -e "[SUCCESS] Backup created as $COLLECTOR_ENV_BACKUP_FILE."
fi

echo -e "[INFO] Downloading the latest \`.env\` file ..."
curl -fsSL -o "$COLLECTOR_ENV_FILE" "$COLLECTOR_ENV_URL"
if [ $? -ne 0 ]; then
    echo -e "[ERROR] Failed to download the \`.env\` file. Exiting.\n\n"
    exit 1
fi
echo -e "[SUCCESS] \`.env\` file downloaded successfully.\n\n"

# check private and public IPs
if [ -z "$PRIVATE_IP" ] || [ -z "$PUBLIC_IP" ]; then
    echo -e "[ERROR] Failed to retrieve private or public IPs. Exiting.\n"
    exit 1
fi
echo -e "[INFO] Private IP: $PRIVATE_IP"
echo -e "[INFO] Public IP: $PUBLIC_IP"

# Fetch hostID from backend using POST
echo -e "[INFO] Fetching hostID from the backend ..."
HOST_ID_RESPONSE=$(curl -sf -X POST \
  "$SERVICE_URL/api/v1/open-host-detail" \
  -H "accept: application/json" \
  -H "Content-Type: application/json" \
  -d "{
        \"privateIP\": \"$PRIVATE_IP\",
        \"publicIP\": \"$PUBLIC_IP\"
      }")

if [ $? -ne 0 ]; then
    echo -e "[ERROR] Failed to fetch hostID from the backend. Exiting."
    exit 1
fi

HOST_ID=$(echo "$HOST_ID_RESPONSE" | jq -r '.hostId')
if [ -z "$HOST_ID" ]; then
    echo -e "[ERROR] Failed to extract hostId from the backend response. Exiting.\n"
    exit 1
fi
echo -e "[INFO] hostID fetched: $HOST_ID"

update_env_file "HOST_ID" "$HOST_ID"
update_env_file "SERVICE_URL" "$SERVICE_URL"

# Run the new container
echo -e "[INFO] Starting a new container with the latest image..."
docker run -d --name incerto-collector --env-file $(pwd)/.env --network host -v $(pwd)/config.yaml:/config.yaml $ECR_URL/$IMAGE_NAME:$IMAGE_TAG

echo -e "                      Container is up and running.                      "

echo -e "\n************************************************************************"
echo -e "                                                                        "
echo -e "d888888b   d8b   db    .o88b.   d88888b   d8888b.   d888888b    .d88b.  "
echo -e "   88      888o  88   d8P  Y8   88        88   8D    ~~88~~    .8P  Y8. "
echo -e "   88      88V8o 88   8P        88ooooo   88oobY       88      88    88 "
echo -e "   88      88 V8o88   8b        88~~~~~   88 8b        88      88    88 "
echo -e "  .88.     88  V888   Y8b  d8   88.       88  88.      88       8b  d8  "
echo -e "Y888888P   VP   V8P     Y88P    Y88888P   88   YD      YP        Y88P   "
echo -e "                                                                        "
echo -e "                      Incerto Technologies Pvt Ltd                      "
echo -e "                           https://incerto.in                           "
echo -e "                                                                        "
echo -e "************************************************************************"
