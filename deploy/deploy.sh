#!/bin/bash

set -e

# Default values
PREFIX=""
HUB_REGION=""
WORKER_REGIONS=()
INCLUDE_HUB_AS_WORKER=false
VPC_ID=""
SUBNET_IDS=()
INSTANCE_TYPE=""

# Function to print usage
usage() {
    echo "Usage: $0 --prefix <prefix> --hub <hub_region> --worker <worker_region1> [--worker <worker_region2> ...] [--hub-as-worker] [--vpc <vpc_id>] [--subnet <subnet_id1> [--subnet <subnet_id2> ...]] --instance-type <instance_type>"
    echo "Example: $0 --prefix myapp --hub us-east-1 --worker us-west-2 --worker eu-west-1 --hub-as-worker --instance-type p5en.48xlarge"
    echo "Example with VPC: $0 --prefix myapp --hub us-east-1 --worker us-west-2 --vpc vpc-12345 --subnet subnet-abc123 --subnet subnet-def456"
    echo
    echo "Options:"
    echo "  --prefix         Prefix for all resource names"
    echo "  --hub            Hub region for SpotInstanceFinder"
    echo "  --worker         Worker region(s) for spot instances"
    echo "  --hub-as-worker  Include hub region as a worker region"
    echo "  --vpc            VPC ID to deploy resources into (optional, uses default VPC if not specified)"
    echo "  --subnet         Subnet ID(s) to deploy resources into (optional, uses all subnets in VPC if not specified)"
    echo "  --instance-type  Instance type for spot instances"
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --prefix)
            PREFIX="$2"
            shift 2
            ;;
        --hub)
            HUB_REGION="$2"
            shift 2
            ;;
        --worker)
            WORKER_REGIONS+=("$2")
            shift 2
            ;;
        --hub-as-worker)
            INCLUDE_HUB_AS_WORKER=true
            shift
            ;;
        --vpc)
            VPC_ID="$2"
            shift 2
            ;;
        --subnet)
            SUBNET_IDS+=("$2")
            shift 2
            ;;
        --instance-type)
            INSTANCE_TYPE="$2"
            shift 2
            ;;
        *)
            echo "Unknown parameter: $1"
            usage
            ;;
    esac
done

# Validate required parameters
if [ -z "$PREFIX" ]; then
    echo "Error: Prefix is required"
    usage
fi

if [ -z "$HUB_REGION" ]; then
    echo "Error: Hub region is required"
    usage
fi

if [ -z "$INSTANCE_TYPE" ]; then
    echo "Error: Instance Type is required"
    usage
fi

if [ ${#WORKER_REGIONS[@]} -eq 0 ]; then
    echo "Error: At least one worker region is required"
    usage
fi

# Add hub region to worker regions if --hub-as-worker is set
if [ "$INCLUDE_HUB_AS_WORKER" = true ]; then
    WORKER_REGIONS+=("$HUB_REGION")
fi

# Remove duplicates from worker regions while preserving order
WORKER_REGIONS=($(echo "${WORKER_REGIONS[@]}" | tr ' ' '\n' | awk '!seen[$0]++' | tr '\n' ' '))

# Create hub tfvars
cat > hub/terraform.tfvars << EOF
prefix = "${PREFIX}"
hub_region = "${HUB_REGION}"
worker_regions = [$(printf '"%s",' "${WORKER_REGIONS[@]}" | sed 's/,$//')]
instance_type = "$INSTANCE_TYPE"
EOF

# Deploy hub
echo "Deploying hub..."
terraform -chdir=hub init -backend-config="path=terraform.hub.tfstate"
# terraform -chdir=hub plan -var-file=terraform.tfvars -state=terraform.hub.tfstate
terraform -chdir=hub apply -auto-approve -var-file=terraform.tfvars

# Deploy workers
echo "Deploying workers..."
for region in "${WORKER_REGIONS[@]}"; do
    echo "Deploying worker in region: $region"

    # Create worker directory for this region
    mkdir -p "worker/$region"
    cp worker/main.tf.template "worker/$region/main.tf"

    # Create worker tfvars
    cat > "worker/$region/terraform.tfvars" << EOF
prefix = "${PREFIX}"
worker_region = "$region"
hub_region = "$HUB_REGION"
instance_type = "$INSTANCE_TYPE"
EOF

    # Add VPC ID if provided
    if [ -n "$VPC_ID" ]; then
        echo "vpc_id = \"$VPC_ID\"" >> "worker/$region/terraform.tfvars"
    fi

    # Add subnet IDs if provided
    if [ ${#SUBNET_IDS[@]} -gt 0 ]; then
        echo "subnet_ids = [$(printf '"%s",' "${SUBNET_IDS[@]}" | sed 's/,$//')]" >> "worker/$region/terraform.tfvars"
    fi

    # Initialize and apply with region-specific state
    terraform -chdir="worker/$region" init -backend-config="path=terraform.worker.$region.tfstate"
    # terraform -chdir="worker/$region" plan -var-file=terraform.tfvars
    terraform -chdir="worker/$region" apply -auto-approve -var-file=terraform.tfvars
done

echo "Deployment completed successfully!"
