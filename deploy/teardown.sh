#!/bin/bash

set -e

echo "Starting automatic teardown process..."

# Find all worker regions from directory structure
echo "Finding worker regions..."
WORKER_REGIONS=()
for worker_dir in worker/*/; do
    if [ -d "$worker_dir" ]; then
        region=$(basename "$worker_dir")
        WORKER_REGIONS+=("$region")
    fi
done

echo "Found worker regions: ${WORKER_REGIONS[@]}"

# Teardown all workers
echo "Tearing down worker regions..."
for region in "${WORKER_REGIONS[@]}"; do
    echo "Tearing down worker in region: $region"

    # Initialize and destroy with region-specific state
    echo "Running terraform destroy for worker region: $region"
    terraform -chdir="worker/$region" init -backend-config="path=terraform.worker.$region.tfstate"
    terraform -chdir="worker/$region" destroy -auto-approve -var-file=terraform.tfvars

    echo "Worker region $region teardown complete."
done

# Teardown hub
echo "Tearing down hub region..."

# Check if hub directory exists
if [ ! -d "hub" ]; then
    echo "Error: Hub directory not found. Exiting..."
    exit 1
fi

# Assume hub tfvars exists

# Initialize and destroy hub
echo "Running terraform destroy for hub region"
terraform -chdir=hub init -backend-config="path=terraform.hub.tfstate"
terraform -chdir=hub destroy -auto-approve -var-file=terraform.tfvars

echo "Hub region teardown complete."

# Clean up temporary files and worker directories
echo "Cleaning up temporary files and worker directories..."
find . -name "terraform.tfvars" -type f -delete
find . -name ".terraform" -type d -exec rm -rf {} +
find . -name ".terraform.lock.hcl" -type f -delete
find . -name "terraform.*.tfstate*" -type f -delete

# Delete worker region directories
echo "Removing worker region directories..."
for region in "${WORKER_REGIONS[@]}"; do
    echo "Removing worker directory: worker/$region"
    rm -rf "worker/$region"
done

echo "Teardown process completed successfully!"
