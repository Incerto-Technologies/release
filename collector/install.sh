#!/bin/bash

set -e  # exit immediately if a command exits with a non-zero status

# colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NO_COLOR='\033[0m'

# Logging functions
print_info() {
    printf "${BLUE}[INFO]${NO_COLOR} %b\n" "$1"
}

print_success() {
    printf "${GREEN}[SUCCESS]${NO_COLOR} %b\n" "$1"
}

print_error() {
    printf "${RED}[ERROR]${NO_COLOR} %b\n" "$1"
}

# fetch private and public IPs
PRIVATE_IP=$(hostname -I | awk '{print $1}')
PUBLIC_IP=$(curl -sf http://checkip.amazonaws.com)

# registry details
ECR_URL="public.ecr.aws/t9w7u8l8/incerto"
IMAGE_NAME="collector"
IMAGE_TAG="prod"
CONTAINER_NAME="incerto-collector"

COLLECTOR_CONFIG_URL="none"
COLLECTOR_CONFIG_DIR="$(pwd)/config"
COLLECTOR_CONFIG_FILE="config.yaml"
COLLECTOR_CONFIG_BACKUP_FILE="config.yaml.bak"

# `.env`
COLLECTOR_ENV_URL="https://raw.githubusercontent.com/Incerto-Technologies/release/refs/heads/main/collector/.env"
COLLECTOR_ENV_FILE="$(pwd)/.env"
COLLECTOR_ENV_BACKUP_FILE=".env.bak"

# get url for 
SERVICE_URL="none"
# run collector for `worker` or `keeper`
DATABASE="none"
TYPE="none"
ENDPOINT="none"
USERNAME=""
PASSWORD=""

# env
ENV="prod"

while [ $# -gt 0 ]; do
    case $1 in
        --env)
            ENV="$2"
            if [ -z "$ENV" ]; then
                print_info "[INFO] Missing value for --env. Defaulting to 'prod'. Accepted values: 'dev' or 'prod'. "
            fi
            shift 2
            ;;
        --service-url)
            SERVICE_URL="$2"
            if [ -z "$SERVICE_URL" ]; then
                print_info "[ERROR] Missing value for --service-url. Please provide a valid URL."
                exit 1
            fi
            shift 2
            ;;
        --database)
            DATABASE="$2"
            if [ -z "$DATABASE" ]; then
                print_info "[ERROR] Missing value for --database. Please provide a valid database."
                exit 1
            fi
            shift 2
            ;;
        --type)
            TYPE="$2"
            if [ -z "$TYPE" ]; then
                print_info "[ERROR] Missing value for --type. Please provide a valid type for the given database."
                exit 1
            fi
            shift 2
            ;;
        --endpoint)
            ENDPOINT="$2"
            if [ "$DATABASE" = "clickhouse" ]; then
                ENDPOINT="localhost:9000"
            elif [ "$DATABASE" = "postgres" ]; then
                ENDPOINT="localhost:5432"
            else
                :
            fi
            shift 2
            ;;
        --username)
            USERNAME="$2"
            if [ "$DATABASE" = "clickhouse" ]; then
                USERNAME="default"
            elif [ "$DATABASE" = "postgres" ]; then
                USERNAME="postgres"
            else
                :
            fi
            shift 2
            ;;
        --password)
            PASSWORD="$2"
            shift 2
            ;;
        *)
            print_error "Unknown option: $1\n"
            exit 1
            ;;
    esac
done

print_info "Proceeding with using"
printf "\n    env: $ENV \n    service-url: $SERVICE_URL \n    database: $DATABASE \n    type: $TYPE \n    endpoint: $ENDPOINT \n    username: $USERNAME \n    password: $PASSWORD\n\n"


# Update image tags based on the ENV value
if [ "$ENV" = "dev" ]; then
    IMAGE_TAG="dev"
else
    IMAGE_TAG="prod"
fi

# Validate database and type combinations  
# Determine the correct config.yaml URL based on the type
if [ "$DATABASE" = "clickhouse" ]; then
    if [ "$TYPE" != "worker" ] && [ "$TYPE" != "keeper" ]; then
        print_error "Invalid type for clickhouse. Allowed values are 'worker' or 'keeper'.\n"
        exit 1
    fi
    COLLECTOR_CONFIG_URL="https://raw.githubusercontent.com/Incerto-Technologies/release/refs/heads/main/collector/$DATABASE/$TYPE/config.yaml"
elif [ "$DATABASE" = "postgres" ]; then
    if [ "$TYPE" != "master" ] && [ "$TYPE" != "replica" ]; then
        print_error "Invalid type for postgres. Allowed values are 'master' or 'replica'.\n"
        exit 1
    fi
    COLLECTOR_CONFIG_URL="https://raw.githubusercontent.com/Incerto-Technologies/release/refs/heads/main/collector/$DATABASE/$TYPE/config.yaml"
else
    print_error "Unsupported database type. Allowed values are 'clickhouse' or 'postgres'.\n"
    exit 1
fi

# function to install Docker on Ubuntu/Debian
install_docker_ubuntu() {
    print_info "Installing Docker on Ubuntu ..."
    sudo apt update -y
    sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
    if [ -f /usr/share/keyrings/docker-archive-keyring.gpg ]; then
        sudo rm -f /usr/share/keyrings/docker-archive-keyring.gpg
    fi
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update -y
    sudo apt install -y docker-ce docker-ce-cli containerd.io
    sudo systemctl enable docker
    sudo systemctl start docker
    print_success "Docker installed successfully on Ubuntu.\n"
}

# function to install Docker on RHEL
install_docker_rhel() {
    print_info "Installing Docker on RHEL ..."
    # Check for Amazon Linux version
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [ "$ID" = "amzn" ] && [ "$VERSION_ID" = "2" ]; then
            print_info "Detected Amazon Linux 2. Installing Docker for Amazon Linux 2 ..."
            sudo yum update -y
            sudo amazon-linux-extras enable docker
            sudo yum install -y docker
            sudo systemctl start docker
            sudo systemctl enable docker
            print_success "Docker installed on Amazon Linux 2."
            return
        elif [ "$ID" = "amzn" ] && [ "$VERSION_ID" = "2023" ]; then
            print_info "Detected Amazon Linux 2023. Installing Docker for Amazon Linux 2023 ..."
            sudo dnf update -y
            sudo dnf install -y docker
            sudo systemctl start docker
            sudo systemctl enable docker
            print_success "Docker installed on Amazon Linux 2023."
            return
        elif [ "$ID" = "rhel" ]; then
            print_info "Detected Red Hat. Installing Docker for RedHat ..."
            sudo dnf update -y
            sudo dnf install -y dnf-plugins-core yum-utils device-mapper-persistent-data lvm2
            sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
            sudo dnf install -y docker-ce docker-ce-cli containerd.io
            sudo systemctl start docker
            sudo systemctl enable docker
            print_success "Docker installed on RedHat."
            return
        else
            print_error "Unsupported Linux distribution: $ID"
            return 1
        fi
    fi
}

# after installation: set up Docker group and permissions
configure_docker_post_install() {
    print_info "Configuring Docker group and permissions ..."
    sudo groupadd docker || true  # Create the Docker group if it doesn't exist
    sudo usermod -aG docker $USER  # Add the current user to the Docker group
    print_success "Docker group configured. Please logout and log back in.\nAnd run the same command."
}

# check and install Docker
install_docker() {
    if [ -x /usr/bin/docker ] || [ -x /usr/local/bin/docker ]; then
        print_info "Docker is already installed on this machine.\n"
        return 0
    fi
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian) install_docker_ubuntu ;;
            centos|rhel|fedora|amazon|amzn) install_docker_rhel ;;
            *)
                print_error "Unsupported operating system. Only Ubuntu and RHEL are supported."
                exit 1
                ;;
        esac
        # Perform post-installation steps
        configure_docker_post_install
        exit 0
    else
        print_error "OS detection failed. Unable to proceed."
        exit 1
    fi
}

# check Docker permission
check_docker_permissions() {
    print_info "Checking Docker permissions for the current user ..."
    if groups $USER | grep -q '\bdocker\b'; then
        print_info "User \`$USER\` already has access to Docker without sudo.\n"
    else
        print_info "User \`$USER\` does not have access to Docker without sudo."
        print_info "Adding user \`$USER\` to the \`docker\` group ..."
        sudo usermod -aG docker $USER
        print_info "User \`$USER\` added to the \`docker\` group."
        print_success "User added to Docker group. Please logout and log back in. \nAnd run the same command."
        exit 0
    fi
}

# force Docker cleanup
docker_cleanup () {
    docker system prune -f
}

# check and install jq
install_jq() {
    if [ -x /usr/bin/jq ] || [ -x /usr/local/bin/jq ]; then
        print_info "jq is already installed on this machine.\n"
        return 0
    fi
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu) sudo apt-get install -y jq ;;
            rhel | centos | amzn) sudo yum install -y jq  ;;
            *)
                print_error "Unsupported operating system. Only Ubuntu and RHEL are supported.\n"
                exit 1
                ;;
        esac
    else
        print_error "OS detection failed. Unable to proceed.\n"
        exit 1
    fi
}

# update env file
update_env_file() {
    KEY="$1"   # The key to update or add (e.g., "HOST_ID")
    VALUE="$2" # The value to set for the key

    print_info "Updating $COLLECTOR_ENV_FILE with $KEY=$VALUE"

    # Check if the .env file exists
    if [ ! -f "$COLLECTOR_ENV_FILE" ]; then
        print_info "$COLLECTOR_ENV_FILE does not exist. Creating a new one."
        echo "$KEY=$VALUE" > "$COLLECTOR_ENV_FILE"
        print_success "$KEY added to $COLLECTOR_ENV_FILE.\n"
    else
        # Check if the key already exists
        if grep -q "^$KEY=" "$COLLECTOR_ENV_FILE"; then
            print_info "$KEY already exists in $COLLECTOR_ENV_FILE. Updating it."
            sed -i "s|^$KEY=.*|$KEY=$VALUE|" "$COLLECTOR_ENV_FILE"  # Use | as delimiter instead of /
            print_success "$KEY updated in $COLLECTOR_ENV_FILE.\n"
        else
            print_info "$KEY not found in $COLLECTOR_ENV_FILE. Adding it."
            echo "$KEY=$VALUE" >> "$COLLECTOR_ENV_FILE"  # Append the new key-value pair with a preceeding newline
            print_success "$KEY added to $COLLECTOR_ENV_FILE.\n"
        fi
    fi
}


install_docker

check_docker_permissions

install_jq

# pull the latest image from public ECR
print_info "Pulling the latest Docker image from Public ECR ..."
docker pull $ECR_URL/$IMAGE_NAME:$IMAGE_TAG

# stop and remove the existing container if it exists
if [ "$(docker ps -aq -f name=$CONTAINER_NAME)" ]; then
    print_info "A container with the name $CONTAINER_NAME already exists. Removing it ..."
    docker rm -f $CONTAINER_NAME
    print_success "Existing container removed.\n"
else
    print_info "No existing container with the name $CONTAINER_NAME found.\n"
fi

# download `config.yaml` file and handle backup if it already exists
# the `config.yaml` changes depending on the type (worker vs keeper) 
print_info "Checking for an existing $COLLECTOR_CONFIG_DIR dir ..."
if [ ! -d "$COLLECTOR_CONFIG_DIR" ]; then
    print_info "$COLLECTOR_CONFIG_DIR dir not found. Creating it ..."
    mkdir -p "$COLLECTOR_CONFIG_DIR"
    print_success "Created $COLLECTOR_CONFIG_DIR dir."
fi

print_info "Downloading the latest \`config.yaml\` file ..."
curl -fsSL -o "$COLLECTOR_CONFIG_DIR/$COLLECTOR_CONFIG_FILE" "$COLLECTOR_CONFIG_URL"
if [ $? -ne 0 ]; then
    print_error "Failed to download the \`config.yaml\` file. Exiting.\n"
    exit 1
fi
print_success "\`config.yaml\` file downloaded successfully.\n"

# download `.env`` file and handle backup if it already exists
# print_info "Checking for an existing \`.env\` file ...\n"
# if [ -f "$COLLECTOR_ENV_FILE" ]; then
#     print_info "\`.env\` file found. Creating a backup ...\n"
#     mv "$COLLECTOR_ENV_FILE" "$COLLECTOR_ENV_BACKUP_FILE"
#     print_success "Backup created as $COLLECTOR_ENV_BACKUP_FILE.\n"
# fi

# print_info "Downloading the latest \`.env\` file ...\n"
# curl -fsSL -o "$COLLECTOR_ENV_FILE" "$COLLECTOR_ENV_URL"
# if [ $? -ne 0 ]; then
#     print_error "Failed to download the \`.env\` file. Exiting.\n\n"
#     exit 1
# fi
# print_success "\`.env\` file downloaded successfully.\n\n"

if [ ! -f "$COLLECTOR_ENV_FILE" ]; then
    # create an empty .env
    touch "$COLLECTOR_ENV_FILE"
fi

# check private and public IPs
if [ -z "$PRIVATE_IP" ] && [ -z "$PUBLIC_IP" ]; then
    print_error "Failed to retrieve private or public IPs. Exiting."
    exit 1
fi
print_info "Private IP: $PRIVATE_IP"
print_info "Public IP: $PUBLIC_IP"

# Fetch hostID from backend using POST
print_info "Fetching hostID from the backend ..."
HOST_ID_RESPONSE=$(curl -sf --max-time 5 -X POST \
  "$SERVICE_URL/api/v1/open-host-detail" \
  -H "accept: application/json" \
  -H "Content-Type: application/json" \
  -d "{
        \"privateIP\": \"$PRIVATE_IP\",
        \"publicIP\": \"$PUBLIC_IP\"
      }")

if [ $? -ne 0 ]; then
    print_error "Failed to fetch hostID from the backend. Exiting."
    exit 1
fi

HOST_ID=$(echo "$HOST_ID_RESPONSE" | jq -r '.hostId')
if [ -z "$HOST_ID" ]; then
    print_error "Failed to extract hostId from the backend response. Exiting."
    exit 1
fi
print_info "hostID fetched: $HOST_ID"

# update env variables
update_env_file "HOST_ID" "$HOST_ID"
update_env_file "SERVICE_URL" "$SERVICE_URL"
if [ "$DATABASE" = "clickhouse" ]; then
    update_env_file "CLICKHOUSE_ENDPOINT" "$ENDPOINT"
    update_env_file "CLICKHOUSE_USERNAME" "$USERNAME"
    update_env_file "CLICKHOUSE_PASSWORD" "$PASSWORD"
elif [ "$DATABASE" = "postgres" ]; then
    update_env_file "POSTGRES_ENDPOINT" "$ENDPOINT"
    update_env_file "POSTGRES_USERNAME" "$USERNAME"
    update_env_file "POSTGRES_PASSWORD" "$PASSWORD"
else
    print_info "Nothing to update\n"
fi

# Run the new container
print_info "Starting a new container with the latest image..."
docker run -d --name incerto-collector \
    --restart=always \
    --memory=500m \
    --env-file $(pwd)/incerto/.env \
    --network host \
    -v $(pwd)/config:/tmp/config \
    -v /proc:/hostfs/proc \
    -v /:/hostfs \
    -v /var/run/docker.sock:/var/run/docker.sock:rw \
    $ECR_URL/$IMAGE_NAME:$IMAGE_TAG
printf "\n                      Container is up and running.                      \n"

docker_cleanup

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
