#!/bin/bash

# Script to fetch latest Docker image versions from GitHub releases and import selected version to ACR
# Requires: curl, jq, az cli
# Compatible with bash 3.x and newer

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
ACR_NAME="your-acr-name"                    # Replace with your Azure Container Registry name
DOCKER_REPO="organization/repository"       # Replace with your Docker Hub repository
GITHUB_REPO="organization/repository"       # Replace with your GitHub repository

echo -e "${BLUE}🔍 Fetching latest versions from GitHub releases...${NC}"

# Check bash version
if [ -z "$BASH_VERSION" ]; then
    echo -e "${RED}❌ This script requires bash. Please run with: bash $0${NC}"
    exit 1
fi

# Check if required tools are installed
for tool in curl jq az; do
    if ! command -v $tool &> /dev/null; then
        echo -e "${RED}❌ Error: $tool is not installed${NC}"
        exit 1
    fi
done

# Check if logged in to Azure
echo "Checking Azure CLI authentication..."
if ! az account show &>/dev/null; then
    echo -e "${RED}❌ Not logged in to Azure CLI. Please run 'az login' first.${NC}"
    exit 1
fi

# Check if ACR exists and is accessible
echo "Verifying ACR access..."
if ! az acr show --name "$ACR_NAME" &>/dev/null; then
    echo -e "${RED}❌ Cannot access ACR '$ACR_NAME'. Please check permissions.${NC}"
    exit 1
fi

# Fetch existing tags from ACR
echo "Checking existing images in ACR..."
# Extract repository name from DOCKER_REPO (e.g., "org/repo" -> "repo")
REPO_NAME=$(echo "$DOCKER_REPO" | cut -d'/' -f2)
# existing_tags=$(az acr repository show-tags --name "$ACR_NAME" --repository "$REPO_NAME" --output tsv --query "[].name" 2>/dev/null || echo "")
existing_tags=$(az acr repository show-tags --name "$ACR_NAME" --repository "$REPO_NAME" --output tsv)
# Function to check if tag exists in ACR (using grep instead of associative arrays)
check_acr_tag() {
    local tag="$1"
    if echo "$existing_tags" | grep -q "^${tag}$"; then
        echo "EXISTS"
    else
        echo "Missing"
    fi
}

# Function to get colored status
get_colored_status() {
    local status="$1"
    if [ "$status" = "EXISTS" ]; then
        echo -e "${GREEN}✓ EXISTS${NC}"
    else
        echo -e "${RED}✗ Missing${NC}"
    fi
}

# Fetch latest releases from GitHub API
echo "Fetching releases from GitHub..."
releases_json=$(curl -s "https://api.github.com/repos/${GITHUB_REPO}/releases?per_page=10")

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to fetch releases from GitHub${NC}"
    exit 1
fi

# Check if we got valid JSON
if ! echo "$releases_json" | jq empty 2>/dev/null; then
    echo -e "${RED}❌ Invalid response from GitHub API${NC}"
    exit 1
fi

# Extract version info and format for display
echo "Processing release data..."
versions_data=$(echo "$releases_json" | jq -r '
    .[:5] | 
    map(select(.tag_name != null and .published_at != null)) |
    .[] | 
    [.tag_name, .published_at, .name // .tag_name] | 
    @tsv
')

if [ -z "$versions_data" ]; then
    echo -e "${RED}❌ No valid releases found${NC}"
    exit 1
fi

# Display table header
echo
echo -e "${GREEN}📋 Latest 5 versions from $GITHUB_REPO:${NC}"
echo "┌────┬─────────────┬─────────────┬────────────┬────────────────────────┐"
echo "│ #  │ Version     │ Date        │ In ACR     │ Release Name           │"
echo "├────┼─────────────┼─────────────┼────────────┼────────────────────────┤"

# Process and display versions
declare -a versions
declare -a dates
declare -a names
declare -a acr_status
counter=1

while IFS=$'\t' read -r version date name; do
    if [ $counter -le 5 ]; then
        # Format date (convert from ISO to readable format)
        formatted_date=$(date -d "$date" +"%Y-%m-%d" 2>/dev/null || echo "${date:0:10}")
        
        # Check if version exists in ACR
        acr_exists=$(check_acr_tag "v$version")
        acr_colored=$(get_colored_status "$acr_exists")
        
        # Truncate name if too long
        truncated_name=$(echo "$name" | cut -c1-22)
        if [ ${#name} -gt 22 ]; then
            truncated_name="${truncated_name}..."
        fi
        
        printf "│ %-2d │ %-11s │ %-11s │ " "$counter" "$version" "$formatted_date"
        printf "%b%-12s%b │ %-22s │\n" "$([ "$acr_exists" = "EXISTS" ] && echo -e "${GREEN}" || echo -e "${RED}")" "$([ "$acr_exists" = "EXISTS" ] && echo "✓ EXISTS" || echo "✗ Missing")" "$NC" "$truncated_name"
        
        versions[counter]="$version"
        dates[counter]="$formatted_date"
        names[counter]="$name"
        acr_status[counter]="$acr_exists"
        
        ((counter++))
    fi
done <<< "$versions_data"

echo "└────┴─────────────┴─────────────┴──────────────┴────────────────────────┘"
echo

# Show ACR repository info
echo -e "${CYAN}📦 ACR Repository: $ACR_NAME.azurecr.io/$REPO_NAME${NC}"
if [ -n "$existing_tags" ]; then
    tag_count=$(echo "$existing_tags" | wc -l)
    echo -e "${CYAN}📊 Currently stored versions: $tag_count${NC}"
else
    echo -e "${YELLOW}⚠️  No $REPO_NAME images found in ACR${NC}"
fi
echo

# Prompt user for selection
while true; do
    echo -e "${YELLOW}Please select a version to import (1-5, or 'q' to quit):${NC}"
    read -p "Enter your choice: " choice
    
    case $choice in
        [1-5])
            if [ -n "${versions[$choice]}" ]; then
                selected_version="${versions[$choice]}"
                selected_date="${dates[$choice]}"
                selected_name="${names[$choice]}"
                selected_acr_status="${acr_status[$choice]}"
                break
            else
                echo -e "${RED}❌ Invalid selection. Please try again.${NC}"
            fi
            ;;
        [qQ])
            echo -e "${YELLOW}👋 Exiting...${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Invalid input. Please enter 1-5 or 'q' to quit.${NC}"
            ;;
    esac
done

selected_version_append_v="v$selected_version"

echo
echo -e "${GREEN}✅ Selected version: $selected_version${NC}"
echo -e "${GREEN}📅 Release date: $selected_date${NC}"
echo -e "${GREEN}📝 Release name: $selected_name${NC}"

# Check if already exists
if [ "$selected_acr_status" = "EXISTS" ]; then
    echo -e "${YELLOW}⚠️  This version already exists in ACR!${NC}"
    echo -e "${YELLOW}🤔 Do you want to re-import it anyway? This will overwrite the existing image. (y/N)${NC}"
    read -p "Confirm overwrite: " confirm
else
    echo -e "${BLUE}ℹ️  This version is not in ACR yet.${NC}"
    echo -e "${YELLOW}🤔 Do you want to import this version to ACR '$ACR_NAME'? (y/N)${NC}"
    read -p "Confirm import: " confirm
fi

case $confirm in
    [yY]|[yY][eE][sS])
        echo -e "${BLUE}🚀 Starting import...${NC}"
        ;;
    *)
        echo -e "${YELLOW}👋 Import cancelled.${NC}"
        exit 0
        ;;
esac

# Perform the import
echo -e "${BLUE}📦 Importing $REPO_NAME:$selected_version_append_v to $ACR_NAME...${NC}"

import_command="az acr import --name $ACR_NAME --source docker.io/$DOCKER_REPO:$selected_version --image $REPO_NAME:$selected_version_append_v"

echo "Executing: $import_command"
echo

if eval "$import_command"; then
    echo
    echo -e "${GREEN}✅ Successfully imported $REPO_NAME:$selected_version_append_v to ACR!${NC}"
    echo
    echo -e "${GREEN}📋 Summary:${NC}"
    echo "   • Source: docker.io/$DOCKER_REPO:$selected_version"
    echo "   • Target: $ACR_NAME.azurecr.io/$REPO_NAME:$selected_version_append_v"
    echo "   • Release: $selected_name"
    echo "   • Date: $selected_date"
    echo
    echo -e "${BLUE}💡 You can now use this image in your Kubernetes deployment:${NC}"
    echo "   image: $ACR_NAME.azurecr.io/$REPO_NAME:$selected_version_append_v"
    echo
    echo -e "${CYAN}🔄 Updated ACR status: This version now exists in your ACR${NC}"
else
    echo
    echo -e "${RED}❌ Failed to import the image. Please check the error above.${NC}"
    exit 1
fi