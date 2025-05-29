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
                print_info "Detected Ubuntu/Debian. Installing via snap ..."
                sudo snap install aws-cli --classic -y
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
        print_success "AWS CLI successfully installed!"
        return 0
    else
        print_error "AWS CLI installation failed. Command not found after installation."
        return 1
    fi
}

# function to install Docker on Ubuntu/Debian
install_docker_ubuntu() {
    print_info "Installing Docker on Ubuntu ..."
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
    print_success "Docker installed successfully on UBUNTU."
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
    print_success "Docker group configured. Please logout and log back in.\n And run the same command."
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
        print_info "User \`$USER\` already has access to Docker without sudo."
    else
        print_info "User \`$USER\` does not have access to Docker without sudo."
        print_info "Adding user \`$USER\` to the \`docker\` group ..."
        sudo usermod -aG docker $USER
        print_info "User \`$USER\` added to the \`docker\` group."
        print_success "User added to Docker group. Please logout and log back in. \n And run the same command: curl -sfL https://raw.githubusercontent.com/Incerto-Technologies/release/refs/heads/main/collector/install.sh | sh -s -- --service-url $SERVICE_URL --type $TYPE"
        exit 0
    fi
}

# update env file
update_env_file() {
    FILE="$1"  # The file to be updated (e.g., .env)
    KEY="$2"   # The key to update or add (e.g., "HOST_ID")
    VALUE="$3" # The value to set for the key

    print_info "Updating $FILE with $KEY=$VALUE"
    
    # Check if the file exists
    if [ ! -f "$FILE" ]; then
        print_info "$FILE does not exist. Creating a new one."
        echo "$KEY=$VALUE" > "$FILE"
        print_success "$KEY added to $FILE."
    else
        # Check if the key already exists
        if grep -q "^$KEY=" "$FILE"; then
            print_info "$KEY already exists in $FILE. Updating it."
            sed -i "s/^$KEY=.*/$KEY=$VALUE/" "$FILE"  # Update the existing value
            print_success "$KEY updated in $FILE."
        else
            print_info "$KEY not found in $FILE. Adding it."
            echo "$KEY=$VALUE" >> "$FILE"  # Append the new key-value pair with a preceeding newline
            print_success "$KEY added to $FILE."
        fi
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
        print_success "Successfully authenticated with AWS ECR.\n"
    else
        print_error "Failed to authenticate with AWS ECR. Exiting.\n"
        exit 1
    fi
}

# setup base directories & remove old `.tar` files
setup_base_dir() {
    cd "$HOME" || { print_error "Failed to cd to home directory"; exit 1; }
    mkdir -p "$HOME/incerto" && cd "$HOME/incerto" || { print_error "Failed to cd into ~/incerto"; exit 1; }
    rm -f *.tar
    rm -f *.json
    print_info "Removed old *.tar and *.json \n"
}

# bundle frontend service
bundle_frontend() {
    # pulling and saving latest image
    print_info "Pulling frontend image ... "
    docker pull "$ECR_URL_FRONTEND/$IMAGE_NAME_FRONTEND:$IMAGE_TAG_FRONTEND"
    docker save -o "$HOME/incerto/frontend-$IMAGE_TAG_FRONTEND.tar" "$ECR_URL_FRONTEND/$IMAGE_NAME_FRONTEND:$IMAGE_TAG_FRONTEND"
    printf "\n                      Pulled and saved incerto-frontend image.                      \n\n"
}

# bundle backend service
bundle_backend() {
    # pulling and saving latest image
    print_info "Pulling backend image ... "
    docker pull "$ECR_URL_BACKEND/$IMAGE_NAME_BACKEND:$IMAGE_TAG_BACKEND"
    docker save -o "$HOME/incerto/backend-$IMAGE_TAG_BACKEND.tar" "$ECR_URL_BACKEND/$IMAGE_NAME_BACKEND:$IMAGE_TAG_BACKEND"
    printf "\n                      Pulled and saved incerto-backend image.                      \n\n"
}

# bundle AI service
bundle_ai() {
    # pulling and saving latest image
    print_info "Pulling AI image ... "
    docker pull "$ECR_URL_AI/$IMAGE_NAME_AI:$IMAGE_TAG_AI"
    docker save -o "$HOME/incerto/ai-$IMAGE_TAG_AI.tar" "$ECR_URL_AI/$IMAGE_NAME_AI:$IMAGE_TAG_AI"
    printf "\n                      Pulled and saved incerto-ai image.                      \n\n"
}

create_info_json() {
    print_info "Creating info.json ... "
    VERSION=$(date +"%Y%m%d_%H%M%S")
    CONTENT=$(cat << EOF
    {
        "version": "$VERSION",
        "environment": "$ENV",
        "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
        "images": [
            "$IMAGE_NAME_FRONTEND:$IMAGE_TAG_FRONTEND:$(docker inspect --format='{{index .RepoDigests 0}}' "$ECR_URL_FRONTEND/$IMAGE_NAME_FRONTEND:$IMAGE_TAG_FRONTEND" | cut -d@ -f2)",
            "$IMAGE_NAME_BACKEND:$IMAGE_TAG_BACKEND:$(docker inspect --format='{{index .RepoDigests 0}}' "$ECR_URL_BACKEND/$IMAGE_NAME_BACKEND:$IMAGE_TAG_BACKEND" | cut -d@ -f2)",
            "$IMAGE_NAME_AI:$IMAGE_TAG_AI:$(docker inspect --format='{{index .RepoDigests 0}}' "$ECR_URL_AI/$IMAGE_NAME_AI:$IMAGE_TAG_AI" | cut -d@ -f2)"
        ]
    }
EOF
)
    echo "$CONTENT" | tee "$HOME/incerto/info.json"
    print_success "Saved info.json \n"
}

create_zip() {
    local HOME_DIR="$HOME"
    local INCERTO_DIR="$HOME_DIR/incerto"
    local ZIP_FILE="$HOME_DIR/incerto.zip"
    
    # check if incerto directory exists
    if [ ! -d "$INCERTO_DIR" ]; then
        print_error "Directory '$INCERTO_DIR' not found"
        print_info "Please ensure the incerto directory exists in your home directory"
        return 1
    fi
    
    # check if incerto directory has contents
    if [ -z "$(ls -A "$INCERTO_DIR" 2>/dev/null)" ]; then
        print_error "Directory '$INCERTO_DIR' is empty"
        return 1
    fi
    
    # remove existing zip file if it exists
    if [ -f "$ZIP_FILE" ]; then
        print_info "Removing existing incerto.zip"
        rm "$ZIP_FILE"
    fi
    
    print_info "Creating zip from directory: $INCERTO_DIR"
    print_info "Contents to be zipped:"
    ls -lah "$INCERTO_DIR/"
    
    # Change to home directory and create zip with relative paths
    cd "$HOME_DIR" || {
        print_error "Failed to change to home directory"
        return 1
    }
    
    if zip -r incerto.zip incerto; then
        print_success "Created complete \"incerto.zip\" bundle"
        print_info "Zip file location: $ZIP_FILE"
        print_info "Zip file size: $(du -h "$ZIP_FILE" | cut -f1)"
        return 0
    else
        print_error "Failed to create bundle"
        return 1
    fi
}

main() {
    install_helper_tools

    install_aws_cli

    install_docker
    
    check_docker_permissions

    setup_ecr

    setup_base_dir

    print_info "Pulling and saving Docker images ... "

    bundle_frontend
    bundle_backend
    bundle_ai

    create_info_json
    create_zip

    docker_cleanup
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
