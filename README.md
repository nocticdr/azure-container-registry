# Docker Image Importer v2.0

```
╔════════════════════════════════════════════════════════════════════════╗
║                                                                        ║
║           ██████╗  ██████╗  ██████╗██╗  ██╗███████╗██████╗             ║
║           ██╔══██╗██╔═══██╗██╔════╝██║ ██╔╝██╔════╝██╔══██╗            ║
║           ██║  ██║██║   ██║██║     █████╔╝ █████╗  ██████╔╝            ║
║           ██║  ██║██║   ██║██║     ██╔═██╗ ██╔══╝  ██╔══██╗            ║
║           ██████╔╝╚██████╔╝╚██████╗██║  ██╗███████╗██║  ██║            ║
║           ╚═════╝  ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝            ║
║                                                                        ║
║                        IMAGE IMPORTER v2.0                             ║
║                                                                        ║
║     🐳 Docker Hub  ──➤  📦 Container Registry  ──➤ ✅ Success           ║
║                                                                        ║
║        Migrate container images from Docker Hub to ACR/GHCR            ║
║                                                                        ║
╚════════════════════════════════════════════════════════════════════════╝
```

A comprehensive interactive bash script for importing Docker images from Docker Hub to Azure Container Registry (ACR) or GitHub Container Registry (GHCR). The script provides an intuitive interface for selecting Docker tags and seamlessly migrating container images between registries.

## 🚀 Features

- **Dual Registry Support**: Import to both Azure Container Registry (ACR) and GitHub Container Registry (GHCR)
- **Interactive Tag Selection**: Browse and select from available Docker Hub tags
- **Smart Authentication**: Automatic Azure CLI login and Docker registry authentication
- **Environment Persistence**: Saves your choices for reuse across sessions
- **Private Repository Support**: Handles both public and private Docker Hub repositories
- **Colorized Output**: Beautiful terminal output with status indicators and emojis
- **Error Handling**: Comprehensive error checking with automatic cleanup
- **Cross-Platform**: Compatible with bash 3.x and newer

## 📋 Prerequisites

Before running this script, ensure you have the following tools installed:

### Required for all operations:
- **curl** - For Docker Hub API requests
- **jq** - For JSON processing
- **bash** 3.x or newer

### For ACR operations:
- **Azure CLI** (`az`) - For ACR operations

### For GHCR operations:
- **Docker** - For GHCR operations

### Installation

#### macOS (using Homebrew)
```bash
brew install azure-cli curl jq docker
```

#### Ubuntu/Debian
```bash
sudo apt update
sudo apt install azure-cli curl jq docker.io
```

#### Windows (using Chocolatey)
```powershell
choco install azure-cli curl jq docker-desktop
```

## 🔧 Configuration

The script uses environment persistence to save your configuration choices. No manual configuration needed - the script will prompt you for all required information and save it for future runs.

### Saved Configuration
The script automatically saves the following in `.nexops_import_env`:
- Docker Hub repository details
- Authentication credentials (if using private repos)
- ACR name and settings
- GHCR namespace and repository preferences

## 🚀 Usage

### 1. Run the Script

```bash
# Make the script executable
chmod +x docker_importer.sh

# Run the script
./docker_importer.sh

# Or source it to keep environment variables active
source ./docker_importer.sh
```

### 2. Follow the Interactive Prompts

The script will guide you through:

1. **Source Configuration**: Docker Hub repository details
2. **Authentication**: Credentials for private repositories (if needed)
3. **Tag Selection**: Choose from available Docker Hub tags
4. **Destination Registry**: Select ACR or GHCR
5. **Import Process**: Automatic image migration

## 📊 Example Output

```
╔════════════════════════════════════════════════════════════════════════╗
║                                                                        ║
║    ██████╗  ██████╗  ██████╗██╗  ██╗███████╗██████╗                   ║
║    ██╔══██╗██╔═══██╗██╔════╝██║ ██╔╝██╔════╝██╔══██╗                  ║
║    ██║  ██║██║   ██║██║     █████╔╝ █████╗  ██████╔╝                  ║
║    ██║  ██║██║   ██║██║     ██╔═██╗ ██╔══╝  ██╔══██╗                  ║
║    ██████╔╝╚██████╔╝╚██████╗██║  ██╗███████╗██║  ██║                  ║
║    ╚═════╝  ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝                  ║
║                                                                        ║
║                        IMAGE IMPORTER v2.0                            ║
║                                                                        ║
║     🐳 Docker Hub  ──➤  📦 Container Registry  ──➤  ✅ Success!      ║
║                                                                        ║
║          Migrate container images from Docker Hub to ACR/GHCR         ║
║                                                                        ║
╚════════════════════════════════════════════════════════════════════════╝

💡 Note: Saved choices are kept in .nexops_import_env.
   To reset them: run rm .nexops_import_env and rerun this script.
   If the script fails, saved values will be cleared automatically.

🐳 Source: Docker Hub repository
Enter Docker Hub repo (org/repo): nginx/nginx

⏬ Fetching tags from Docker Hub...

┌────┬──────────────────────────────────────┐
│ #  │ Tag                                  │
├────┼──────────────────────────────────────┤
│ 1  │ latest                               │
│ 2  │ 1.25.3                               │
│ 3  │ 1.25.2                               │
│ 4  │ alpine                               │
│ 5  │ mainline                             │
└────┴──────────────────────────────────────┘
Select a tag (1-5): 2

🎯 Destination registry
1) Azure Container Registry (ACR)
2) GitHub Container Registry (GHCR)
Choose destination [1/2]: 1

🔎 Checking Azure CLI authentication...
🔎 Verifying access to ACR 'myregistry'...

📦 Importing docker.io/nginx/nginx:1.25.3 → myregistry.azurecr.io/nginx:v1.25.3
✅ Success!
Source : docker.io/nginx/nginx:1.25.3
Target : myregistry.azurecr.io/nginx:v1.25.3
```

## 🔄 Workflow

### ACR Import Workflow
1. **Authentication**: Verifies Azure CLI login and ACR access
2. **Source Selection**: Choose Docker Hub repository and tag
3. **Direct Import**: Uses `az acr import` for efficient server-side copying
4. **Verification**: Confirms successful import

### GHCR Import Workflow
1. **Authentication**: Login to Docker Hub (if private) and GHCR
2. **Source Selection**: Choose Docker Hub repository and tag
3. **Pull-Tag-Push**: Downloads image locally, retags, and pushes to GHCR
4. **Verification**: Confirms successful push

## 🛠️ Advanced Usage

### Environment File Management

```bash
# View saved configuration
cat .nexops_import_env

# Reset all saved choices
rm .nexops_import_env

# Edit specific values
nano .nexops_import_env
```

### Batch Operations

For multiple imports, the script will remember your choices:

```bash
# First run - will prompt for all details
./docker_importer.sh

# Subsequent runs - will use saved choices, only prompt for tag selection
./docker_importer.sh
```

### Sourcing the Script

To keep environment variables active in your shell:

```bash
source ./docker_importer.sh
# Environment variables are now available in your current shell
echo $DOCKER_REPO
echo $ACR_NAME
```

## 🛠️ Troubleshooting

### Common Issues

#### "Not logged in to Azure CLI"
```bash
az login
```

#### "Cannot access ACR"
- Verify ACR name is correct (without .azurecr.io suffix)
- Check Azure permissions and subscription context
- Run `az account set --subscription <subscription-id>` if needed

#### "Failed to fetch Docker Hub tags"
- Check internet connectivity
- Verify repository name format (org/repo)
- For private repos, ensure valid credentials

#### "Docker login failed"
- Verify Docker Hub credentials
- For GHCR, ensure GitHub PAT has `write:packages` permission
- Check if 2FA is interfering with authentication

### Reset and Cleanup

If the script encounters errors, it automatically cleans up saved environment variables. To manually reset:

```bash
rm .nexops_import_env
```

## 🔒 Security Considerations

- **Credential Storage**: Credentials are stored in `.nexops_import_env` (add to `.gitignore`)
- **Automatic Cleanup**: Environment variables are cleared on script failure
- **No Hardcoded Secrets**: All credentials are prompted interactively
- **Secure Transmission**: All API calls use HTTPS

### Best Practices

1. **Add to .gitignore**:
   ```gitignore
   .nexops_import_env
   ```

2. **Use Personal Access Tokens**: For GitHub operations, use PATs instead of passwords

3. **Limit Permissions**: Ensure Azure and GitHub accounts have minimal required permissions

## 📝 Script Customization

### Changing Default Tag Prefix for ACR

The script uses "v" as the default prefix for ACR tags. To change this:

```bash
# Set in environment before running
export TAG_PREFIX_IN_ACR="release-"
./docker_importer.sh
```

### Modifying Number of Tags Displayed

Edit the script to change `page_size=50` in the Docker Hub API call to display more tags.

## 📄 License

This script is provided as-is for educational and operational purposes. Please ensure compliance with:
- Azure Container Registry terms of service
- Docker Hub terms of service
- GitHub Container Registry terms of service

## 🤝 Contributing

Feel free to submit issues and enhancement requests!

## 📞 Support

For issues related to:
- **Azure CLI**: [Azure CLI Documentation](https://docs.microsoft.com/en-us/cli/azure/)
- **ACR**: [Azure Container Registry Documentation](https://docs.microsoft.com/en-us/azure/container-registry/)
- **Docker Hub**: [Docker Hub Documentation](https://docs.docker.com/docker-hub/)
- **GHCR**: [GitHub Container Registry Documentation](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)