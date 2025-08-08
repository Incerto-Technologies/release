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

# AWS credentials
AWS_ACCOUNT_ID="434499855633"
AWS_REGION="ap-south-1"
AWS_ACCESS_KEY_ID="none"
AWS_SECRET_ACCESS_KEY="none"

# frontend service
ECR_URL_FRONTEND="434499855633.dkr.ecr.ap-south-1.amazonaws.com"
IMAGE_NAME_FRONTEND="incerto/frontend"
IMAGE_TAG_FRONTEND="prod"
CONTAINER_NAME_FRONTEND="incerto-frontend"
INCERTO_FRONTEND="true"

# backend service
ECR_URL_BACKEND="434499855633.dkr.ecr.ap-south-1.amazonaws.com"
IMAGE_NAME_BACKEND="incerto/backend"
IMAGE_TAG_BACKEND="prod"
CONTAINER_NAME_BACKEND="incerto-backend"
INCERTO_BACKEND="true"

# ai service
ECR_URL_AI="434499855633.dkr.ecr.ap-south-1.amazonaws.com"
IMAGE_NAME_AI="incerto/ai"
IMAGE_TAG_AI="prod"
CONTAINER_NAME_AI="incerto-ai"
INCERTO_AI="true"

INCERTO_AUTOUPDATE_CRON="false"

# env
ENV="prod"

while [ $# -gt 0 ]; do
    case $1 in
        --env)
            ENV="$2"
            if [ -z "$ENV" ]; then
                print_info "Missing value for --env. Defaulting to 'prod'. Accepted values: 'dev' or 'prod'. "
            fi
            shift 2
            ;;
        --aws-access-key-id)
            AWS_ACCESS_KEY_ID="$2"
            if [ -z "$AWS_ACCESS_KEY_ID" ]; then
                print_error "Missing value for --aws-access-key-id. Please provide a valid AWS key ID."
                exit 1
            fi
            shift 2
            ;;
        --aws-secret-access-key)
            AWS_SECRET_ACCESS_KEY="$2"
            if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
                print_error "Missing value for --aws-secret-access-key. Please provide a valid AWS access key."
                exit 1
            fi
            shift 2
            ;;
        --aws-region)
            AWS_REGION="$2"
            if [ -z "$AWS_REGION" ]; then
                print_error "Missing value for --aws-region. Please provide a valid AWS region value."
                exit 1
            fi
            shift 2
            ;;
        --frontend)
            INCERTO_FRONTEND="$2"
            if [ -z "$INCERTO_FRONTEND" ]; then
                print_error "Missing value for --frontend. Please provide a true or false."
                exit 1
            fi
            shift 2
            ;;
        --backend)
            INCERTO_BACKEND="$2"
            if [ -z "$INCERTO_BACKEND" ]; then
                print_error "Missing value for --backend. Please provide a true or false."
                exit 1
            fi
            shift 2
            ;;
        --ai)
            INCERTO_AI="$2"
            if [ -z "$INCERTO_AI" ]; then
                print_error "Missing value for --ai. Please provide a true or false."
                exit 1
            fi
            shift 2
            ;;
        --auto-update-cron)
            INCERTO_AUTOUPDATE_CRON="$2"
            if [ -z "$INCERTO_AUTOUPDATE_CRON" ]; then
                INCERTO_AUTOUPDATE_CRON="false"
            fi
            shift 2
            ;;
        --domain)
            DOMAIN="$2"
            if [ -z "$DOMAIN" ]; then
                print_error "Missing value for --domain. Please provide a valid domain value like utility.incerto.in."
                exit 1
            fi
            shift 2
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

print_info "Proceeding with using"
printf "\n    env: $ENV \n    aws-access-key-id: $AWS_ACCESS_KEY_ID \n    aws-secret-access-key: $AWS_SECRET_ACCESS_KEY \n    aws-region: $AWS_REGION \n    frontend: $INCERTO_FRONTEND \n    backend: $INCERTO_BACKEND \n    ai: $INCERTO_AI \n    domain: $DOMAIN\n\n"

# Update image tags based on the ENV value
if [ "$ENV" = "dev" ]; then
    IMAGE_TAG_FRONTEND="dev"
    IMAGE_TAG_BACKEND="dev"
    IMAGE_TAG_AI="dev"
else
    IMAGE_TAG_FRONTEND="prod"
    IMAGE_TAG_BACKEND="prod"
    IMAGE_TAG_AI="prod"
fi

# install helper tools
install_helper_tools() {
    # need zip unzip
    if command -v zip &> /dev/null && command -v unzip &> /dev/null; then
        print_info "zip and unzip are already installed on this machine.\n"
        return 0
    fi
    print_info "Installing helper tools ... "
    # detect OS and install accordingly
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian) 
                print_info "Detected Ubuntu/Debian. Installing via apt ..."
                sudo apt update -y
                sudo apt install -y zip unzip
                ;;
            centos|rhel|fedora|amazon|amzn)
                print_info "Detected RHEL-based system. Installing via direct download ..."
                if command -v dnf &> /dev/null; then
                    # Use dnf for newer RHEL/Fedora systems
                    sudo dnf install -y zip unzip
                elif command -v yum &> /dev/null; then
                    # Use yum for older RHEL/CentOS systems
                    sudo yum install -y zip unzip
                else
                    print_error "No package manager (dnf/yum) found."
                    return 1
                fi
                ;;
            *) 
                print_error "Unsupported Linux distribution: $ID"
                return 1
                ;;
        esac
    else
        print_error "OS detection failed. Unable to proceed."
        exit 1
    fi
    # Verify installation was successful
    if command -v zip &> /dev/null && command -v unzip &> /dev/null; then
        print_success "AWS CLI successfully installed!"
        return 0
    else
        print_error "AWS CLI installation failed. Command not found after installation."
        return 1
    fi
}

# function to check and install AWS CLI
install_aws_cli() {
    if command -v aws &> /dev/null; then
        print_info "AWS CLI is already installed on this machine.\n"
        return 0
    fi
    # install aws-cli directly via binary
    install_aws_cli_direct() {
        if curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"; then
            print_info "Download completed. Extracting ... "
            if unzip -q awscliv2.zip; then
                print_info "Installing AWS CLI ... "
                if sudo ./aws/install; then
                    print_info "Installation completed."
                    return 0
                else
                    print_error "Installation failed."
                    return 1
                fi
            else
                print_error "Failed to extract awscliv2.zip"
                return 1
            fi
        else
            print_error "Failed to download AWS CLI."
            return 1
        fi
    }
    # detect OS and install accordingly
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian) 
                print_info "Detected Ubuntu/Debian. Installing via direct download ..."
                install_aws_cli_direct
                ;;
            centos|rhel|fedora|amazon|amzn)
                print_info "Detected RHEL-based system. Installing via direct download ..."
                install_aws_cli_direct
                return $?
                ;;
            *) 
                print_info "Detected other Linux distribution. Installing via direct download ..."
                install_aws_cli_direct
                return $?
                ;;
        esac
    else
        print_error "OS detection failed. Unable to proceed."
        exit 1
    fi
    # Verify installation was successful
    if command -v aws &> /dev/null; then
        print_success "AWS CLI successfully installed!\n"
        return 0
    else
        print_error "AWS CLI installation failed. Command not found after installation."
        return 1
    fi
}

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

# setup AWS ECR
setup_ecr() {
    # configure AWS credentials
    aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
    aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
    aws configure set region $AWS_REGION
    print_info "Authenticating with AWS ECR."
    # authenticate Docker with ECR
    if aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"; then
        print_success "Successfully authenticated with AWS ECR.\n"
    else
        print_error "Failed to authenticate with AWS ECR. Exiting.\n"
        exit 1
    fi
}

# setup base directories
setup_base_dir() {
    cd "$HOME" || { print_error "Failed to cd to home directory"; exit 1; }
    mkdir -p "$HOME/incerto" && cd "$HOME/incerto" || { print_error "Failed to cd into ~/incerto"; exit 1; }
}

# setup and run frontend service
run_frontend() {
    REQUIRED_DIRS=(
        "$(pwd)/frontend"
    )
    REQUIRED_FILES=(
        "$(pwd)/frontend/.env"
        "$(pwd)/frontend/config.json"
    )
    # ensure required directories exist
    for dir in "${REQUIRED_DIRS[@]}"; do
        if [ ! -d "$dir" ]; then
            print_info "Creating missing directory: $dir"
            mkdir -p "$dir"
        fi
    done
    # ensure required files exist
    for file in "${REQUIRED_FILES[@]}"; do
        if [ ! -f "$file" ]; then
            print_info "Required file missing: $file"
            touch "$file"
            print_info "Created the missing file: $file"
        fi
    done
    # stop and remove the existing container if it exists
    if [ "$(docker ps -aq -f name=$CONTAINER_NAME_FRONTEND)" ]; then
        print_info "A container with the name $CONTAINER_NAME_FRONTEND already exists. Removing it ..."
        docker rm -f $CONTAINER_NAME_FRONTEND
        print_success "Existing container removed."
    else
        print_info "No existing container with the name $CONTAINER_NAME_FRONTEND found."
    fi

    # set up memory limits
    MEMORY_LIMIT_PERCENTAGE=40
    MEMORY_TOTAL_MB=$(( $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 ))
    MEMORY_LIMIT_MB=$((($MEMORY_TOTAL_MB * $MEMORY_LIMIT_PERCENTAGE) / 100))
    printf "[INFO] Allocating %d%% (%dMB out of %dMB) for the service\n" $MEMORY_LIMIT_PERCENTAGE $MEMORY_LIMIT_MB $MEMORY_TOTAL_MB
    
    # run the new container
    print_info "Starting a new container with the latest image ..."
    docker run -d \
        --name $CONTAINER_NAME_FRONTEND \
        --pull=always \
        --restart=always \
        --memory=${MEMORY_LIMIT_MB}m \
        --network host \
        --env-file $(pwd)/frontend/.env \
        -v $(pwd)/frontend/config.json:/app/dist/config.json:rw \
        $ECR_URL_FRONTEND/$IMAGE_NAME_FRONTEND:$IMAGE_TAG_FRONTEND
    printf "\n                      Frontend service is up and running.                      \n\n"
}

# setup and run backend service
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
            print_info "Creating missing directory: $dir"
            mkdir -p "$dir"
        fi
    done
    # ensure required files exist
    for file in "${REQUIRED_FILES[@]}"; do
        if [ ! -f "$file" ]; then
            print_info "Required file missing: $file"
            touch "$file"
            print_info "Created the missing file: $file"
        fi
    done
    # stop and remove the existing container if it exists
    if [ "$(docker ps -aq -f name=$CONTAINER_NAME_BACKEND)" ]; then
        print_info "A container with the name $CONTAINER_NAME_BACKEND already exists. Removing it ..."
        docker stop $CONTAINER_NAME_BACKEND && docker rm $CONTAINER_NAME_BACKEND
        print_success "Existing container removed."
    else
        print_info "No existing container with the name $CONTAINER_NAME_BACKEND found."
    fi
    # change permissions
    print_info "Change permissions for $(pwd)/backend/logs as it is read-write"
    sudo chmod -R 777 $(pwd)/backend/logs
    
    # set up memory limits
    MEMORY_LIMIT_PERCENTAGE=50
    MEMORY_TOTAL_MB=$(( $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 ))
    MEMORY_LIMIT_MB=$((($MEMORY_TOTAL_MB * $MEMORY_LIMIT_PERCENTAGE) / 100))
    printf "[INFO] Allocating %d%% (%dMB out of %dMB) for the service\n" $MEMORY_LIMIT_PERCENTAGE $MEMORY_LIMIT_MB $MEMORY_TOTAL_MB
    
    # run the new container
    print_info "Starting a new container with the latest image ..."
    docker run -d \
        --name $CONTAINER_NAME_BACKEND \
        --pull=always \
        --restart=always \
        --memory=${MEMORY_LIMIT_MB}m \
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
            print_info "Creating missing directory: $dir"
            mkdir -p "$dir"
        fi
    done
    # ensure required files exist
    for file in "${REQUIRED_FILES[@]}"; do
        if [ ! -f "$file" ]; then
            print_info "Required file missing: $file"
            touch "$file"
            print_info "Created the missing file: $file"
        fi
    done
    # stop and remove the existing container if it exists
    if [ "$(docker ps -aq -f name=$CONTAINER_NAME_AI)" ]; then
        print_info "A container with the name $CONTAINER_NAME_AI already exists. Removing it ..."
        docker rm -f $CONTAINER_NAME_AI
        print_success "Existing container removed."
    else
        print_info "No existing container with the name $CONTAINER_NAME_AI found."
    fi
    # change permissions
    print_info "Change permissions for $(pwd)/ai/logs as it is read-write"
    sudo chmod -R 777 $(pwd)/ai/logs
    
    # set up memory limits
    MEMORY_LIMIT_PERCENTAGE=50
    MEMORY_TOTAL_MB=$(( $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 ))
    MEMORY_LIMIT_MB=$((($MEMORY_TOTAL_MB * $MEMORY_LIMIT_PERCENTAGE) / 100))
    printf "[INFO] Allocating %d%% (%dMB out of %dMB) for the service\n" $MEMORY_LIMIT_PERCENTAGE $MEMORY_LIMIT_MB $MEMORY_TOTAL_MB
    
    # run the new container
    print_info "Starting a new container with the latest image..."
    docker run -d \
        --name $CONTAINER_NAME_AI \
        --pull=always \
        --restart=always \
        --memory=${MEMORY_LIMIT_MB}m \
        --network host \
        --env-file $(pwd)/ai/.env \
        -v ai_database:/app/database:rw \
        -v ~/.kube/config:/app/config \
        -v $(pwd)/ai/logs:/app/logs:rw \
        $ECR_URL_AI/$IMAGE_NAME_AI:$IMAGE_TAG_AI
    printf "\n                      AI service is up and running.                      \n\n"
}

# setup auto-update cronjob
setup_auto_update_cron() {
    # download auto-update script
    curl -sfL https://raw.githubusercontent.com/Incerto-Technologies/release/refs/heads/feature/auto-update/tool/online/auto-update.sh -o $(pwd)/auto-update.sh
    
    # setup cron-job
    TAG="# INCERTO_AUTO_UPDATE_CRON" # this is used as unique identifier for cron job, replace existing cronjobs
    CRON_JOB="0 23 * * * $(pwd)/auto-update.sh --env $ENV --aws-access-key-id $AWS_ACCESS_KEY_ID --aws-secret-access-key $AWS_SECRET_ACCESS_KEY --aws-region $AWS_REGION --frontend $UPDATE_FE --backend $UPDATE_BE --ai $UPDATE_AI --auto-update-cron true --domain $DOMAIN $TAG"

    ( crontab -l 2>/dev/null | grep -vF "$TAG" ; echo "$CRON_JOB" ) | crontab -  || { print_error "Failed to create cron tab"; exit 1; }
}

# function to show container status
show_status() {
    printf "\n"
    print_info "Container Status "
    docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Command}}\t{{.Status}}\t{{.RunningFor}}\t{{.Ports}}\t{{.Size}}"
    printf ""
}

main() {
    install_helper_tools

    install_aws_cli

    install_docker
    
    check_docker_permissions

    setup_ecr

    setup_base_dir

    print_info "Pulling and saving Docker images ... \n"

    if [ "$INCERTO_FRONTEND" = "true" ]; then
        run_frontend
    fi

    if [ "$INCERTO_BACKEND" = "true" ]; then
        run_backend
    fi

    if [ "$INCERTO_AI" = "true" ]; then
        run_ai
    fi

    if [ "$INCERTO_AUTOUPDATE_CRON" = "true" ]; then
        setup_auto_update_cron
    fi


    docker_cleanup

    show_status
}

main "$@"

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
