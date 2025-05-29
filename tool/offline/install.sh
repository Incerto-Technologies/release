#!/bin/bash

set -e  # exit immediately if a command exits with a non-zero status

# colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NO_COLOR='\033[0m'

# Logging functions
print_info() {
    printf "${BLUE}[INFO]${NO_COLOR} %s\n" "$1"
}

print_success() {
    printf "${GREEN}[SUCCESS]${NO_COLOR} %s\n" "$1"
}

print_error() {
    printf "${RED}[ERROR]${NO_COLOR} %s\n" "$1"
}

# configuration
ZIP_FILE="$HOME/incerto.zip"
EXTRACT_DIRECTORY="$HOME/incerto"

# frontend service (image names will be determined after loading)
IMAGE_NAME_FRONTEND=""
CONTAINER_NAME_FRONTEND="incerto-frontend"
INCERTO_FRONTEND="true"

# backend service (image names will be determined after loading)
IMAGE_NAME_BACKEND=""
CONTAINER_NAME_BACKEND="incerto-backend"
INCERTO_BACKEND="true"

# ai service (image names will be determined after loading)
IMAGE_NAME_AI=""
CONTAINER_NAME_AI="incerto-ai"
INCERTO_AI="true"

# env (only prod allowed for offline install)
ENV="prod"

while [ $# -gt 0 ]; do
    case $1 in
        --env)
            ENV="$2"
            if [ -z "$ENV" ]; then
                print_info "Missing value for --env. Defaulting to 'prod'. Accepted values: 'dev' or 'prod'. \n"
            fi
            shift 2
            ;;
         --frontend)
            INCERTO_FRONTEND="$2"
            if [ -z "$INCERTO_FRONTEND" ]; then
                print_error "Missing value for --frontend. Please provide a true or false.\n"
                exit 1
            fi
            shift 2
            ;;
        --backend)
            INCERTO_BACKEND="$2"
            if [ -z "$INCERTO_BACKEND" ]; then
                print_error "Missing value for --backend. Please provide a true or false.\n"
                exit 1
            fi
            shift 2
            ;;
        --ai)
            INCERTO_AI="$2"
            if [ -z "$INCERTO_AI" ]; then
                print_error "Missing value for --ai. Please provide a true or false.\n"
                exit 1
            fi
            shift 2
            ;;
        --domain)
            DOMAIN="$2"
            if [ -z "$DOMAIN" ]; then
                print_error "Missing value for --domain. Please provide a valid domain value like utility.incerto.in.\n"
                exit 1
            fi
            shift 2
            ;;
        *)
            print_error "Unknown option: $1\n"
            exit 1
            ;;
    esac
done

print_info "Proceeding with using\n"
printf "\n    env: $ENV \n    frontend: $INCERTO_FRONTEND \n    backend: $INCERTO_BACKEND \n    ai: $INCERTO_AI \n    domain: $DOMAIN\n\n"

# install helper tools
install_helper_tools() {
    # need zip unzip
    if command -v zip &> /dev/null && command -v unzip &> /dev/null; then
        print_info "zip and unzip are already installed on this machine.\n\n"
        return 0
    fi
    print_info "Installing helper tools ... \n"
    
    # detect OS and install accordingly
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian) 
                print_info "Detected Ubuntu/Debian. Installing via apt ...\n"
                sudo apt update -y
                sudo apt install -y zip unzip
                ;;
            centos|rhel|fedora|amazon|amzn)
                print_info "Detected RHEL-based system. Installing via direct download ...\n"
                if command -v dnf &> /dev/null; then
                    # Use dnf for newer RHEL/Fedora systems
                    sudo dnf install -y zip unzip
                elif command -v yum &> /dev/null; then
                    # Use yum for older RHEL/CentOS systems
                    sudo yum install -y zip unzip
                else
                    print_error "No package manager (dnf/yum) found.\n"
                    return 1
                fi
                ;;
            *) 
                print_error "Unsupported Linux distribution: $ID\n"
                return 1
                ;;
        esac
    else
        print_error "OS detection failed. Unable to proceed.\n"
        exit 1
    fi
    
    # Verify installation was successful
    if command -v zip &> /dev/null && command -v unzip &> /dev/null; then
        print_success "AWS CLI successfully installed!\n"
        return 0
    else
        print_error "AWS CLI installation failed. Command not found after installation.\n"
        return 1
    fi
}

# function to install Docker on Ubuntu/Debian
install_docker_ubuntu() {
    print_info "Installing Docker on Ubuntu ...\n"
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
    print_success "Docker installed successfully on Ubuntu.\n"
}

# function to install Docker on RHEL
install_docker_rhel() {
    print_info "Installing Docker on RHEL ...\n"
    # Check for Amazon Linux version
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [ "$ID" = "amzn" ] && [ "$VERSION_ID" = "2" ]; then
            print_info "Detected Amazon Linux 2. Installing Docker for Amazon Linux 2 ...\n"
            sudo yum update -y
            sudo amazon-linux-extras enable docker
            sudo yum install -y docker
            sudo systemctl start docker
            sudo systemctl enable docker
            print_success "Docker installed on Amazon Linux 2.\n"
            return
        elif [ "$ID" = "amzn" ] && [ "$VERSION_ID" = "2023" ]; then
            print_info "Detected Amazon Linux 2023. Installing Docker for Amazon Linux 2023 ...\n"
            sudo dnf update -y
            sudo dnf install -y docker
            sudo systemctl start docker
            sudo systemctl enable docker
            print_success "Docker installed on Amazon Linux 2023.\n"
            return
        elif [ "$ID" = "rhel" ]; then
            print_info "Detected Red Hat. Installing Docker for RedHat ...\n"
            sudo dnf update -y
            sudo dnf install -y dnf-plugins-core yum-utils device-mapper-persistent-data lvm2
            sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
            sudo dnf install -y docker-ce docker-ce-cli containerd.io
            sudo systemctl start docker
            sudo systemctl enable docker
            print_success "Docker installed on RedHat.\n"
            return
        else
            print_error "Unsupported Linux distribution: $ID\n"
            return 1
        fi
    fi
}

# after installation: set up Docker group and permissions
configure_docker_post_install() {
    print_info "Configuring Docker group and permissions ...\n"
    sudo groupadd docker || true  # Create the Docker group if it doesn't exist
    sudo usermod -aG docker $USER  # Add the current user to the Docker group
    print_success "Docker group configured. Please logout and log back in.\n And run the same command."
}

# check and install Docker
install_docker() {
    if [ -x /usr/bin/docker ] || [ -x /usr/local/bin/docker ]; then
        print_info "Docker is already installed on this machine.\n\n"
        return 0
    fi
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian) install_docker_ubuntu ;;
            centos|rhel|fedora|amazon|amzn) install_docker_rhel ;;
            *)
                print_error "Unsupported operating system. Only Ubuntu and RHEL are supported.\n"
                exit 1
                ;;
        esac
        # perform post-installation steps
        configure_docker_post_install
        exit 0
    else
        print_error "OS detection failed. Unable to proceed.\n"
        exit 1
    fi
}

# check Docker permission
check_docker_permissions() {
    print_info "Checking Docker permissions for the current user ...\n"
    if groups $USER | grep -q '\bdocker\b'; then
        print_info "User \`$USER\` already has access to Docker without sudo.\n"
    else
        print_info "User \`$USER\` does not have access to Docker without sudo.\n"
        print_info "Adding user \`$USER\` to the \`docker\` group ...\n"
        sudo usermod -aG docker $USER
        print_info "User \`$USER\` added to the \`docker\` group.\n"
        print_success "User added to Docker group. Please logout and log back in.\n And run the same command: curl -sfL https://raw.githubusercontent.com/Incerto-Technologies/release/refs/heads/main/collector/install.sh | sh -s -- --service-url $SERVICE_URL --type $TYPE"
        exit 0
    fi
}

# force Docker cleanup
docker_cleanup () {
    docker system prune -f
}

# setup base directories
setup_base_dir() {
    cd "$HOME" || { print_error "Failed to cd to home directory"; exit 1; }
    mkdir -p "$HOME/incerto" && cd "$HOME/incerto" || { print_error "Failed to cd into ~/incerto"; exit 1; }
}

# function to extract zip file
extract_images() {
    print_info "Checking for incerto.zip file ... \n"
    if [ ! -f "$ZIP_FILE" ]; then
        print_error "File $ZIP_FILE not found!"
        exit 1
    fi
    
    print_info "Preparing extraction directory ... \n"
    if [ -d "$EXTRACT_DIRECTORY" ]; then
        print_info "Directory $EXTRACT_DIRECTORY already exists"
        print_info "Backing up existing .tar and .json files ... \n"
        
        # Create backup directory with timestamp
        BACKUP_DIRECTORY="$EXTRACT_DIRECTORY/backup_$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$BACKUP_DIRECTORY"
        
        # Move existing .tar and .json files to backup
        find "$EXTRACT_DIRECTORY" -maxdepth 1 -name "*.tar" -exec mv {} "$BACKUP_DIRECTORY/" \; 2>/dev/null || true
        find "$EXTRACT_DIRECTORY" -maxdepth 1 -name "*.json" -exec mv {} "$BACKUP_DIRECTORY/" \; 2>/dev/null || true
        
        print_info "Existing .tar and .json files backed up to $BACKUP_DIRECTORY"
    else
        print_info "Creating directory $EXTRACT_DIRECTORY"
        mkdir -p "$EXTRACT_DIRECTORY"
    fi
    
    print_info "Extracting incerto.zip ... \n"
    unzip -o "$ZIP_FILE" -d "$$HOME"
    print_success "Extraction completed \n"
}

# function to load Docker images
load_images() {
    print_info "Loading Docker images from .tar files ... \n"
    
    cd "$EXTRACT_DIRECTORY"
      
    print_info "Loading Frontend service image ... \n"
    IMAGE_NAME_FRONTEND=$(docker load -i frontend-prod.tar | grep "Loaded image:" | awk '{print $3}')
    print_success "Frontend image loaded: $IMAGE_NAME_FRONTEND \n"
    
    print_info "Loading Backend service image ... \n"
    IMAGE_NAME_BACKEND=$(docker load -i backend-prod.tar | grep "Loaded image:" | awk '{print $3}')
    print_success "Backend image loaded: $IMAGE_NAME_BACKEND \n"

    print_info "Loading AI service image ... \n"
    IMAGE_NAME_AI=$(docker load -i ai-prod.tar | grep "Loaded image:" | awk '{print $3}')
    print_success "AI image loaded: $IMAGE_NAME_AI \n"
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
            print_info "Creating missing directory: $dir\n"
            mkdir -p "$dir"
        fi
    done
    # ensure required files exist
    for file in "${REQUIRED_FILES[@]}"; do
        if [ ! -f "$file" ]; then
            print_info "Required file missing: $file\n"
            touch "$file"
            print_info "Created the missing file: $file\n"
        fi
    done
    # stop and remove the existing container if it exists
    if [ "$(docker ps -aq -f name=$CONTAINER_NAME_FRONTEND)" ]; then
        print_info "A container with the name $CONTAINER_NAME_FRONTEND already exists. Removing it ...\n"
        docker rm -f $CONTAINER_NAME_FRONTEND
        print_success "Existing container removed.\n"
    else
        print_info "No existing container with the name $CONTAINER_NAME_FRONTEND found.\n"
    fi

    # set up memory limits
    MEMORY_LIMIT_PERCENTAGE=40
    MEMORY_TOTAL_MB=$(( $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 ))
    MEMORY_LIMIT_MB=$((($MEMORY_TOTAL_MB * $MEMORY_LIMIT_PERCENTAGE) / 100))
    print_info "Allocating %d%% (%dMB out of %dMB) for the service\n" $MEMORY_LIMIT_PERCENTAGE $MEMORY_LIMIT_MB $MEMORY_TOTAL_MB
    
    # run the new container
    print_info "Starting a new container with the latest image ...\n"
    docker run -d \
        --name $CONTAINER_NAME_FRONTEND \
        --pull=always \
        --restart=always \
        --memory=${MEMORY_LIMIT_MB}m \
        --network host \
        --env-file $(pwd)/frontend/.env \
        -v $(pwd)/frontend/config.json:/app/dist/config.json:rw \
        $IMAGE_NAME_FRONTEND
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
            print_info "Creating missing directory: $dir\n"
            mkdir -p "$dir"
        fi
    done
    # ensure required files exist
    for file in "${REQUIRED_FILES[@]}"; do
        if [ ! -f "$file" ]; then
            print_info "Required file missing: $file\n"
            touch "$file"
            print_info "Created the missing file: $file\n"
        fi
    done
    # stop and remove the existing container if it exists
    if [ "$(docker ps -aq -f name=$CONTAINER_NAME_BACKEND)" ]; then
        print_info "A container with the name $CONTAINER_NAME_BACKEND already exists. Removing it ...\n"
        docker rm -f $CONTAINER_NAME_BACKEND
        print_success "Existing container removed.\n"
    else
        print_info "No existing container with the name $CONTAINER_NAME_BACKEND found.\n"
    fi
    # change permissions
    print_info "Change permissions for $(pwd)/backend/logs as it is read-write\n"
    sudo chmod -R 777 $(pwd)/backend/logs
    
    # set up memory limits
    MEMORY_LIMIT_PERCENTAGE=50
    MEMORY_TOTAL_MB=$(( $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 ))
    MEMORY_LIMIT_MB=$((($MEMORY_TOTAL_MB * $MEMORY_LIMIT_PERCENTAGE) / 100))
    print_info "Allocating %d%% (%dMB out of %dMB) for the service\n" $MEMORY_LIMIT_PERCENTAGE $MEMORY_LIMIT_MB $MEMORY_TOTAL_MB
    
    # run the new container
    print_info "Starting a new container with the latest image ...\n"
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
        $IMAGE_NAME_BACKEND
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
            print_info "Creating missing directory: $dir\n"
            mkdir -p "$dir"
        fi
    done
    # ensure required files exist
    for file in "${REQUIRED_FILES[@]}"; do
        if [ ! -f "$file" ]; then
            print_info "Required file missing: $file\n"
            touch "$file"
            print_info "Created the missing file: $file\n"
        fi
    done
    # stop and remove the existing container if it exists
    if [ "$(docker ps -aq -f name=$CONTAINER_NAME_AI)" ]; then
        print_info "A container with the name $CONTAINER_NAME_AI already exists. Removing it ...\n"
        docker rm -f $CONTAINER_NAME_AI
        print_success "Existing container removed.\n"
    else
        print_info "No existing container with the name $CONTAINER_NAME_AI found.\n"
    fi
    # change permissions
    print_info "Change permissions for $(pwd)/ai/logs as it is read-write\n"
    sudo chmod -R 777 $(pwd)/ai/logs
    
    # set up memory limits
    MEMORY_LIMIT_PERCENTAGE=50
    MEMORY_TOTAL_MB=$(( $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 ))
    MEMORY_LIMIT_MB=$((($MEMORY_TOTAL_MB * $MEMORY_LIMIT_PERCENTAGE) / 100))
    print_info "Allocating %d%% (%dMB out of %dMB) for the service\n" $MEMORY_LIMIT_PERCENTAGE $MEMORY_LIMIT_MB $MEMORY_TOTAL_MB
    
    # run the new container
    print_info "Starting a new container with the latest image...\n"
    docker run -d \
        --name $CONTAINER_NAME_AI \
        --pull=always \
        --restart=always \
        --memory=${MEMORY_LIMIT_MB}m \
        --network host \
        --env-file $(pwd)/ai/.env \
        -v $(pwd)/ai/logs:/app/logs:rw \
        $IMAGE_NAME_AI
    printf "\n                      AI service is up and running.                      \n\n"
}

# function to show container status
show_status() {
    print_info "Container Status \n"
    docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Command}}\t{{.Status}}\t{{.RunningFor}}\t{{.Ports}}\t{{.Size}}"
    printf "\n"
}

main() {
    install_helper_tools

    install_docker    
    check_docker_permissions

    extract_images
    
    load_images

    setup_base_dir

    if [ "$INCERTO_FRONTEND" = "true" ]; then
        run_frontend
    fi

    if [ "$INCERTO_BACKEND" = "true" ]; then
        run_backend
    fi

    if [ "$INCERTO_AI" = "true" ]; then
        run_ai
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
