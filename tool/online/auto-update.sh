#!/bin/bash

echo "\n\n\n********************\nIncerto AutoUpdate, checking for updates at: $(date)\n\n"

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

ECR_URL="434499855633.dkr.ecr.ap-south-1.amazonaws.com"
IMAGE_TAG="prod"
IMAGE_NAME_BACKEND="incerto/backend"
IMAGE_NAME_FRONTEND="incerto/frontend"
IMAGE_NAME_AI="incerto/ai"


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

# Update image tags based on the ENV value
if [ "$ENV" = "dev" ]; then
    IMAGE_TAG="dev"
else
    IMAGE_TAG="prod"
fi

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

# check backend
UPDATE_BE=false
check_backend() {
    print_info "Checking backend ...\n"

    BE_PREV_HASH=$(docker images --no-trunc --quiet $ECR_URL/$IMAGE_NAME_BACKEND:$IMAGE_TAG 2>/dev/null)

    if ! docker pull $ECR_URL/$IMAGE_NAME_BACKEND:$IMAGE_TAG; then
        print_error "Failed to pull Backend image\n"
        exit 1
    fi

    BE_NEW_HASH=$(docker images --no-trunc --quiet $ECR_URL/$IMAGE_NAME_BACKEND:$IMAGE_TAG 2>/dev/null)

    if [ -n "$BE_PREV_HASH" ] && [ "$BE_PREV_HASH" != "$BE_NEW_HASH" ]; then
        UPDATE_BE=true
    else
        UPDATE_BE=false
    fi
}

# frontend service
UPDATE_FE=false
check_frontend() {
    print_info "Checking frontend ...\n"

    FE_PREV_HASH=$(docker images --no-trunc --quiet $ECR_URL/$IMAGE_NAME_FRONTEND:$IMAGE_TAG 2>/dev/null)

    if ! docker pull $ECR_URL/$IMAGE_NAME_FRONTEND:$IMAGE_TAG; then
        print_error "Failed to pull Frontend image\n"
        exit 1
    fi

    FE_NEW_HASH=$(docker images --no-trunc --quiet $ECR_URL/$IMAGE_NAME_FRONTEND:$IMAGE_TAG 2>/dev/null)

    if [ -n "$FE_PREV_HASH" ] && [ "$FE_PREV_HASH" != "$FE_NEW_HASH" ]; then
        UPDATE_FE=true
    else
        UPDATE_FE=false
    fi
}

# ai service
UPDATE_AI=false
check_ai() {
    print_info "Checking AI ...\n"

    AI_PREV_HASH=$(docker images --no-trunc --quiet $ECR_URL/$IMAGE_NAME_AI:$IMAGE_TAG 2>/dev/null)

    if ! docker pull $ECR_URL/$IMAGE_NAME_AI:$IMAGE_TAG; then
        print_error "Failed to pull AI image"
        exit 1
    fi

    AI_NEW_HASH=$(docker images --no-trunc --quiet $ECR_URL/$IMAGE_NAME_AI:$IMAGE_TAG 2>/dev/null)

    if [ -n "$AI_PREV_HASH" ] && [ "$AI_PREV_HASH" != "$AI_NEW_HASH" ]; then
        UPDATE_AI=true
    else
        UPDATE_AI=false
    fi
}

update_deployment() {
    if [ $UPDATE_BE = true ] || [ $UPDATE_FE = true ] || [ $UPDATE_AI = true ]; then
        print_info "\n\nUpdating...\n"
    
        cd ~ && \
            curl -sfL https://raw.githubusercontent.com/Incerto-Technologies/release/refs/heads/feature/auto-update/tool/online/install.sh | \
            bash -s -- \
            --env $ENV \
            --aws-access-key-id $AWS_ACCESS_KEY_ID \
            --aws-secret-access-key $AWS_SECRET_ACCESS_KEY \
            --aws-region $AWS_REGION \
            --frontend $UPDATE_FE \
            --backend $UPDATE_BE \
            --ai $UPDATE_AI \
            --auto-update-cron true \
            --domain $DOMAIN
    else
        print_info "\nNo Updates\n"
    fi
}

main() {
    setup_ecr

    print_info "Checking for updates ... \n"
    check_backend
    check_frontend
    check_ai

    update_deployment
}

main "$@"