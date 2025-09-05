# Azure Container Registry Image Import Script

A comprehensive bash script for importing Docker images from Docker Hub to Azure Container Registry (ACR) with an interactive version selection interface. The script fetches release information from GitHub and allows you to select which version to import.

## 🚀 Features

- **Interactive Version Selection**: Browse and select from the latest 5 releases from any GitHub repository
- **ACR Status Checking**: Automatically checks which versions already exist in your ACR
- **Colorized Output**: Beautiful terminal output with status indicators
- **Error Handling**: Comprehensive error checking and validation
- **Overwrite Protection**: Warns before overwriting existing images
- **Cross-Platform**: Compatible with bash 3.x and newer

## 📋 Prerequisites

Before running this script, ensure you have the following tools installed:

- **Azure CLI** (`az`) - For ACR operations
- **curl** - For GitHub API requests
- **jq** - For JSON processing
- **bash** 3.x or newer

### Installation

#### macOS (using Homebrew)
```bash
brew install azure-cli curl jq
```

#### Ubuntu/Debian
```bash
sudo apt update
sudo apt install azure-cli curl jq
```

#### Windows (using Chocolatey)
```powershell
choco install azure-cli curl jq
```

## 🔧 Configuration

The script uses the following default configuration (editable in the script):

```bash
ACR_NAME="your-acr-name"                    # Replace with your Azure Container Registry name
DOCKER_REPO="organization/repository"       # Replace with your Docker Hub repository
GITHUB_REPO="organization/repository"       # Replace with your GitHub repository
```

## 🚀 Usage

### 1. Authentication

First, log in to Azure CLI:

```bash
az login
```

### 2. Run the Script

```bash
# Make the script executable
chmod +x import_image_github_acr.sh

# Run the script
./import_image_github_acr.sh
```

### 3. Interactive Selection

The script will:
1. Fetch the latest 5 releases from the configured GitHub repository
2. Check which versions already exist in your ACR
3. Display a formatted table with version information
4. Prompt you to select a version (1-5) or quit (q)

## 📊 Example Output

```
🔍 Fetching latest versions from GitHub releases...
Checking Azure CLI authentication...
Verifying ACR access...
Checking existing images in ACR...

📋 Latest 5 versions from organization/repository:
┌────┬─────────────┬─────────────┬────────────┬─────────────────────────────┐
│ #  │ Version     │ Date        │ In ACR     │ Release Name                │
├────┼─────────────┼─────────────┼────────────┼─────────────────────────────┤
│ 1  │ v1.25.0     │ 2024-01-15  │ ✓ EXISTS   │ Release v1.25.0             │
│ 2  │ v1.24.5     │ 2024-01-10  │ ✗ Missing  │ Bug fixes and improvements  │
│ 3  │ v1.24.4     │ 2024-01-05  │ ✓ EXISTS   │ Release v1.24.4             │
│ 4  │ v1.24.3     │ 2024-01-01  │ ✗ Missing  │ New Year Release            │
│ 5  │ v1.24.2     │ 2023-12-28  │ ✓ EXISTS   │ Release v1.24.2             │
└────┴─────────────┴─────────────┴────────────┴─────────────────────────────┘

📦 ACR Repository: your-acr-name.azurecr.io/repository
📊 Currently stored versions: 3

Please select a version to import (1-5, or 'q' to quit):
Enter your choice: 2
```

## 🔄 Workflow

The script follows this workflow:

1. **Validation Phase**
   - Checks bash version compatibility
   - Verifies required tools are installed
   - Validates Azure CLI authentication
   - Confirms ACR access permissions

2. **Data Collection Phase**
   - Fetches latest releases from GitHub API
   - Retrieves existing tags from ACR
   - Processes and formats version data

3. **Interactive Selection Phase**
   - Displays formatted version table
   - Handles user input and validation
   - Provides confirmation prompts

4. **Import Phase**
   - Executes Azure CLI import command
   - Provides real-time feedback
   - Displays success/failure status

## 🛠️ Troubleshooting

### Common Issues

#### "Not logged in to Azure CLI"
```bash
az login
```

#### "Cannot access ACR"
- Verify ACR name is correct
- Check Azure permissions
- Ensure ACR exists in your subscription

#### "Failed to fetch releases from GitHub"
- Check internet connectivity
- Verify GitHub API access
- Check if the repository exists

#### "Invalid response from GitHub API"
- GitHub API might be temporarily unavailable
- Check GitHub status page
- Retry after a few minutes

### Debug Mode

For detailed debugging, you can modify the script to enable verbose output:

```bash
# Add this line after set -e
set -x
```

## 📝 Script Customization

### Changing the Target Repository

To import a different Docker image:

1. Update `DOCKER_REPO` variable
2. Update `GITHUB_REPO` variable
3. Modify the ACR repository name in the import command

### Adding More Versions

To display more than 5 versions:

1. Change the `per_page=10` parameter in the GitHub API call
2. Update the table display logic
3. Modify the selection range validation

## 🔒 Security Considerations

- The script uses Azure CLI authentication (no hardcoded credentials)
- All API calls use HTTPS
- No sensitive data is logged or stored
- ACR access is validated before operations

## 📄 License

This script is provided as-is for educational and operational purposes. Please ensure compliance with:
- Azure Container Registry terms of service
- Docker Hub terms of service
- GitHub API terms of service

## 🤝 Contributing

Feel free to submit issues and enhancement requests!

## 📞 Support

For issues related to:
- **Azure CLI**: [Azure CLI Documentation](https://docs.microsoft.com/en-us/cli/azure/)
- **ACR**: [Azure Container Registry Documentation](https://docs.microsoft.com/en-us/azure/container-registry/)
- **Docker Hub**: [Docker Hub Documentation](https://docs.docker.com/docker-hub/)
- **GitHub API**: [GitHub API Documentation](https://docs.github.com/en/rest)
