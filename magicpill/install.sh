#!/bin/bash

set -e  # exit immediately if a command exits with a non-zero status

# AWS credentials
AWS_ACCOUNT_ID="434499855633"
AWS_REGION="ap-south-1"
AWS_ACCESS_KEY_ID="none"
AWS_SECRET_ACCESS_KEY="none"

# frontend service
ECR_URL_FRONTEND="434499855633.dkr.ecr.ap-south-1.amazonaws.com/incerto"
IMAGE_NAME_FRONTEND="frontend"
IMAGE_TAG_FRONTEND="latest"
CONTAINER_NAME_FRONTEND="incerto-frontend"

# backend service
ECR_URL_BACKEND="434499855633.dkr.ecr.ap-south-1.amazonaws.com/incerto"
IMAGE_NAME_BACKEND="backend"
IMAGE_TAG_BACKEND="latest"
CONTAINER_NAME_BACKEND="incerto-backend"

# ai service
ECR_URL_AI="434499855633.dkr.ecr.ap-south-1.amazonaws.com/incerto"
IMAGE_NAME_AI="ai"
IMAGE_TAG_AI="latest"
CONTAINER_NAME_AI="incerto-ai"

# customer information
DOMAIN="example.com"

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
        --domain)
            DOMAIN="$2"
            if [ -z "$DOMAIN" ]; then
                printf "[ERROR] Missing value for --domain. Please provide a valid domain value like utility.incerto.in.\n"
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

printf "\n[INFO] Proceeding with using \n\n    aws-access-key-id: $AWS_ACCESS_KEY_ID \n    aws-secret-access-key: $AWS_SECRET_ACCESS_KEY \n    aws-region: $AWS_REGION \n    domain: $DOMAIN\n\n"

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
install_aws_cli() {
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
    FILE="$1"  # The file to be updated (e.g., .env)
    KEY="$2"   # The key to update or add (e.g., "HOST_ID")
    VALUE="$3" # The value to set for the key

    printf "[INFO] Updating $FILE with $KEY=$VALUE\n"
    
    # Check if the file exists
    if [ ! -f "$FILE" ]; then
        printf "[INFO] $FILE does not exist. Creating a new one.\n"
        echo "$KEY=$VALUE" > "$FILE"
        printf "[SUCCESS] $KEY added to $FILE.\n"
    else
        # Check if the key already exists
        if grep -q "^$KEY=" "$FILE"; then
            printf "[INFO] $KEY already exists in $FILE. Updating it.\n"
            sed -i "s/^$KEY=.*/$KEY=$VALUE/" "$FILE"  # Update the existing value
            printf "[SUCCESS] $KEY updated in $FILE.\n"
        else
            printf "[INFO] $KEY not found in $FILE. Adding it.\n"
            echo "$KEY=$VALUE" >> "$FILE"  # Append the new key-value pair with a preceeding newline
            printf "[SUCCESS] $KEY added to $FILE.\n"
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

# force Docker cleanup
docker_cleanup () {
    docker system prune -f
}

# setup AWS ECR
setup_ecr() {
    # configure AWS credentials
    aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
    aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
    aws configure set region $AWS_REGION
    # authenticate Docker with ECR
    if aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"; then
        printf "[INFO] Successfully authenticated with AWS ECR.\n\n"
    else
        printf "[ERROR] Failed to authenticate with AWS ECR. Exiting.\n\n"
        exit 1
    fi
}

# setup base directories
setup_base_dir() {
    cd "$HOME" || { printf "[ERROR] Failed to cd to home directory"; exit 1; }
    mkdir -p "$HOME/incerto" && cd "$HOME/incerto" || { printf "[ERROR] Failed to cd into ~/incerto"; exit 1; }
}

# install certbot
install_certbot() {
    if command -v /usr/bin/certbot &> /dev/null; then
        printf "[INFO] Certbot is already installed on this machine.\n\n"
        return 0
    fi
    printf "[INFO] Installing Certbot using pip ...\n"
    sudo python3 -m venv /opt/certbot/
    sudo /opt/certbot/bin/pip install --upgrade pip
    sudo /opt/certbot/bin/pip install certbot
    sudo ln -sf /opt/certbot/bin/certbot /usr/bin/certbot
    printf "[INFO] Certbot installation complete.\n\n"
}

# setup certificates
setup_certs() {
    EMAIL="shiva@incerto.in"  # Provide a valid email for Let's Encrypt notifications
    
    # Install certbot
    install_certbot

    # Run certbot certificates command and check if the certificate exists
    if sudo certbot certificates | grep -q "$DOMAIN"; then
        echo "[INFO] Certificate already exists for $DIR. Skipping certificate creation."
    else
        printf "[INFO] Requesting SSL certificate for %s using Let's Encrypt ...\n" "$DOMAIN"
    sudo certbot certonly --standalone -d "$DOMAIN" --email "$EMAIL" --agree-tos --non-interactive --rsa-key-size 2048
    fi

    # Copy certs to CERT_DIR
    CERTBOT_DIR="/etc/letsencrypt/live/$DOMAIN"
    printf "[INFO] Copying certificates to /etc/letsencrypt/ssl/ ...\n"
    sudo mkdir -p /etc/letsencrypt/ssl/
    sudo cp -r -L $CERTBOT_DIR/fullchain.pem /etc/letsencrypt/ssl/
    sudo cp -r -L $CERTBOT_DIR/privkey.pem /etc/letsencrypt/ssl/
    printf "[INFO] Setup complete. SSL certificates are stored in /etc/letsencrypt/ssl/ .\n"

    # Setup certificate renewal every 60 days if not already set
    printf "[INFO] Setting up automatic certificate renewal ...\n"
    CRON_ENTRY="0 0 */60 * * root /opt/certbot/bin/python -c 'import random; import time; time.sleep(random.random() * 3600)' && sudo certbot renew -q"
    if ! grep -Fxq "$CRON_ENTRY" /etc/crontab; then
        echo "$CRON_ENTRY" | sudo tee -a /etc/crontab > /dev/null
        printf "[INFO] Certificate renewal cron job added.\n"
    else
        printf "[INFO] Certificate renewal cron job already exists, skipping.\n"
    fi
}

# setup and run Frontend service
run_frontend() {
    REQUIRED_DIRS=(
        "$(pwd)/frontend"
    )
    REQUIRED_FILES=(
        "$(pwd)/frontend/config.json"
    )
    # ensure required directories exist
    for dir in "${REQUIRED_DIRS[@]}"; do
        if [ ! -d "$dir" ]; then
            printf "[INFO] Creating missing directory: $dir\n"
            mkdir -p "$dir"
        fi
    done
    # ensure required files exist
    for file in "${REQUIRED_FILES[@]}"; do
        if [ ! -f "$file" ]; then
            printf "[ERROR] Required file missing: $file\n"
            exit 1
        fi
    done
    # force creation of custom.conf file
    CUSTOM_CONF_FILE="$(pwd)/frontend/.env"
    if [ ! -f "$CUSTOM_CONF_FILE" ]; then
        touch "$CUSTOM_CONF_FILE"
        chmod 644 "$CUSTOM_CONF_FILE"
        printf "File created: $CUSTOM_CONF_FILE\n"
    else
        printf "File already exists: $CUSTOM_CONF_FILE\n"
    fi
    # update env variables
    update_env_file "$CUSTOM_CONF_FILE" "DOMAIN" "$DOMAIN"
    # stop and remove the existing container if it exists
    if [ "$(docker ps -aq -f name=$CONTAINER_NAME_FRONTEND)" ]; then
        printf "[INFO] A container with the name $CONTAINER_NAME_FRONTEND already exists. Removing it ...\n"
        docker rm -f $CONTAINER_NAME_FRONTEND
        printf "[SUCCESS] Existing container removed.\n"
    else
        printf "[INFO] No existing container with the name $CONTAINER_NAME_FRONTEND found.\n"
    fi
    # run the new container
    printf "[INFO] Starting a new container with the latest image ...\n"
    docker run -d \
        --name $CONTAINER_NAME_FRONTEND \
        --pull=always \
        --restart=always \
        --network host \
        --env-file $(pwd)/frontend/.env \
        -v $(pwd)/frontend/config.json:/usr/share/nginx/html/config.json:rw \
        -v /etc/letsencrypt/ssl/fullchain.pem:/etc/nginx/ssl/fullchain.pem:ro \
        -v /etc/letsencrypt/ssl/privkey.pem:/etc/nginx/ssl/privkey.pem:ro \
        $ECR_URL_FRONTEND/$IMAGE_NAME_FRONTEND:$IMAGE_TAG_FRONTEND
    printf "\n                      Frontend service is up and running.                      \n\n"
}

# setup and run Backend service
run_backend() {
    REQUIRED_DIRS=(
        "$(pwd)/backend"
        "$(pwd)/backend/logs"
    )
    REQUIRED_FILES=(
        "$(pwd)/backend/.env"
    )
    # ensure required directories exist
    for dir in "${REQUIRED_DIRS[@]}"; do
        if [ ! -d "$dir" ]; then
            printf "[INFO] Creating missing directory: $dir\n"
            mkdir -p "$dir"
        fi
    done
    # ensure required files exist
    for file in "${REQUIRED_FILES[@]}"; do
        if [ ! -f "$file" ]; then
            printf "[ERROR] Required file missing: $file\n"
            exit 1
        fi
    done
    # stop and remove the existing container if it exists
    if [ "$(docker ps -aq -f name=$CONTAINER_NAME_BACKEND)" ]; then
        printf "[INFO] A container with the name $CONTAINER_NAME_BACKEND already exists. Removing it ...\n"
        docker rm -f $CONTAINER_NAME_BACKEND
        printf "[SUCCESS] Existing container removed.\n"
    else
        printf "[INFO] No existing container with the name $CONTAINER_NAME_BACKEND found.\n"
    fi
    # change permissions
    printf "[INFO] Change permissions for $(pwd)/backend/logs as it is read-write\n"
    sudo chmod -R 777 $(pwd)/backend/logs
    # run the new container
    printf "[INFO] Starting a new container with the latest image ...\n"
    docker run -d \
        --name $CONTAINER_NAME_BACKEND \
        --pull=always \
        --restart=always \
        --network host \
        --env-file $(pwd)/backend/.env \
        -v backend_resource_scripts_all:/app/src/resource/scripts/all:rw \
        -v backend_resource_pem:/app/src/resource/pem:rw \
        -v backend_resource_source:/app/src/resource/source:rw \
        -v backend_config_rbac:/app/src/config/rbac:rw \
        -v $(pwd)/backend/logs:/app/src/logs:rw \
        $ECR_URL_BACKEND/$IMAGE_NAME_BACKEND:$IMAGE_TAG_BACKEND
    printf "\n                      Backend service is up and running.                      \n\n"
}

# setup and run AI service
run_ai() {
    REQUIRED_DIRS=(
        "$(pwd)/ai"
        "$(pwd)/ai/logs"
    )
    REQUIRED_FILES=(
        "$(pwd)/ai/.env"
    )
    # ensure required directories exist
    for dir in "${REQUIRED_DIRS[@]}"; do
        if [ ! -d "$dir" ]; then
            printf "[INFO] Creating missing directory: $dir\n"
            mkdir -p "$dir"
        fi
    done
    # ensure required files exist
    for file in "${REQUIRED_FILES[@]}"; do
        if [ ! -f "$file" ]; then
            printf "[ERROR] Required file missing: $file\n"
            exit 1
        fi
    done
    # stop and remove the existing container if it exists
    if [ "$(docker ps -aq -f name=$CONTAINER_NAME_AI)" ]; then
        printf "[INFO] A container with the name $CONTAINER_NAME_AI already exists. Removing it ...\n"
        docker rm -f $CONTAINER_NAME_AI
        printf "[SUCCESS] Existing container removed.\n"
    else
        printf "[INFO] No existing container with the name $CONTAINER_NAME_AI found.\n"
    fi
    # change permissions
    printf "[INFO] Change permissions for $(pwd)/ai/logs as it is read-write\n"
    sudo chmod -R 777 $(pwd)/ai/logs
    # run the new container
    printf "[INFO] Starting a new container with the latest image...\n"
    docker run -d \
        --name $CONTAINER_NAME_AI \
        --pull=always \
        --restart=always \
        --network host \
        --env-file $(pwd)/ai/.env \
        -v $(pwd)/ai/logs:/app/logs:rw \
        $ECR_URL_AI/$IMAGE_NAME_AI:$IMAGE_TAG_AI
    printf "\n                      AI service is up and running.                      \n\n"
}

install_aws_cli

install_docker
 
check_docker_permissions

setup_ecr

setup_base_dir

setup_certs

run_frontend

run_backend

run_ai

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
