#!/usr/bin/env bash
# Interactive image importer: Docker Hub (source) -> ACR or GHCR (dest)
# Requires: curl, jq; plus az (for ACR path) and/or docker (for GHCR path)
# Bash 3.x+ compatible

# ---- trap setup (drop-in) ----
set -Euo pipefail   # (keep your safety flags)
# set -o errtrace   # optional: if you want ERR to propagate into functions/subshells

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; BLUE=$'\033[0;34m'; CYAN=$'\033[0;36m'; NC=$'\033[0m'

ENV_FILE=".nexops_import_env"
VARS_TO_CLEAR=(DOCKER_REPO IS_PRIVATE DOCKERHUB_USERNAME DOCKERHUB_TOKEN \
  GITHUB_REPO GITHUB_TOKEN ACR_NAME TAG_PREFIX_IN_ACR GHCR_NAMESPACE \
  GHCR_REPO GHCR_USER GHCR_TOKEN)

_cleared=0
clear_envs_once() {
  # prevent re-entry and stop any further traps from firing
  (( _cleared )) && return
  _cleared=1
  trap - ERR INT TERM EXIT

  printf '\033[1;33m⚠ Clearing saved environment variables...\033[0m\n'
  for v in "${VARS_TO_CLEAR[@]}"; do unset "$v" 2>/dev/null || true; done
  [ -f "$ENV_FILE" ] && rm -f "$ENV_FILE"
}

on_err()  { clear_envs_once; exit 1; }   # script error
on_int()  { clear_envs_once; exit 130; } # Ctrl+C
on_term() { clear_envs_once; exit 143; } # SIGTERM
on_exit() { trap - ERR INT TERM EXIT; }  # do nothing on clean exit

trap on_err  ERR
trap on_int  INT
trap on_term TERM
trap on_exit EXIT

echo "╔════════════════════════════════════════════════════════════════════════╗"
echo "║                                                                        ║"
echo "║        ██╗  ██╗ █████╗ ██████╗ ██████╗  ██████╗  ██████╗ ███╗   ██╗   ║"
echo "║        ██║  ██║██╔══██╗██╔══██╗██╔══██╗██╔═══██╗██╔═══██╗████╗  ██║   ║"
echo "║        ███████║███████║██████╔╝██████╔╝██║   ██║██║   ██║██╔██╗ ██║   ║"
echo "║        ██╔══██║██╔══██║██╔══██╗██╔═══╝ ██║   ██║██║   ██║██║╚██╗██║   ║"
echo "║        ██║  ██║██║  ██║██║  ██║██║     ╚██████╔╝╚██████╔╝██║ ╚████║   ║"
echo "║        ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝      ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝   ║"
echo "║                                                                        ║"
echo "║                   DOCKER IMAGE IMPORTER v2.1                           ║"
echo "║                                                                        ║"
echo "║     🐳 Docker Hub  ──➤  📦 Container Registry  ──➤ ✅ Success          ║"
echo "║                                                                        ║"
echo "║     Migrate container images from Docker Hub to ACR/GHCR/LOCAL         ║"
echo "║                                                                        ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"
echo

# ---- tip shown before first prompt ----
echo -e "${CYAN}💡 Note:${NC} Saved choices are kept in ${ENV_FILE}."
echo -e "   To reset them: run ${BLUE}rm ${ENV_FILE}${NC} and rerun this script."
echo -e "   If the script fails, saved values will be cleared automatically."
echo

is_sourced() {
  # Returns 0 if the script is sourced, 1 if executed
  # shellcheck disable=SC2128
  [[ "${BASH_SOURCE[0]}" != "$0" ]]
}

need() { command -v "$1" >/dev/null || { echo "${RED}❌ Missing dependency: $1${NC}"; exit 1; }; }

persist_env() {
  local name="$1" value="$2"
  # Export to current shell if sourced
  if is_sourced; then
    export "$name=$value"
  fi
  # Write to env file for later reuse
  grep -vE "^${name}=" "$ENV_FILE" 2>/dev/null > "${ENV_FILE}.tmp" || true
  mv "${ENV_FILE}.tmp" "$ENV_FILE" 2>/dev/null || true
  printf "%s=%q\n" "$name" "$value" >> "$ENV_FILE"
}

explain_env_persistence() {
  echo
  echo -e "${CYAN}📂 Saved your choices to ${ENV_FILE}.${NC}"
  if is_sourced; then
    echo -e "${GREEN}✔ Env vars are active in this shell session.${NC}"
  else
    echo -e "${YELLOW}⚠ This script was executed (not sourced), so env vars are not active in your shell.${NC}"
    echo -e "   Load them with: ${BLUE}source ${ENV_FILE}${NC}"
  fi
  echo "To change a value: edit ${ENV_FILE} or rerun this script and overwrite."
  echo "To clear everything: rm ${ENV_FILE}"
  echo
}

prompt_default() {
  local prompt="$1" default="${2:-}"
  local answer
  if [ -n "${default}" ]; then
    read -r -p "$prompt [$default]: " answer || true
    echo "${answer:-$default}"
  else
    read -r -p "$prompt: " answer || true
    echo "$answer"
  fi
}

# Load existing environment if available
if [ -f "$ENV_FILE" ]; then
  echo -e "${CYAN}📂 Loading saved choices from ${ENV_FILE}${NC}"
  set -a  # automatically export all variables
  source "$ENV_FILE"
  set +a

  # If a previous Docker repo exists, offer to reuse it (default: proceed)
  if [ -n "${DOCKER_REPO:-}" ]; then
    echo -e "${CYAN}🔎 Found existing Docker repo in ${ENV_FILE}:${NC} ${GREEN}${DOCKER_REPO}${NC}"
    reuse_choice="$(prompt_default "Proceed with this repository? (Y/n)" "Y")"
    if [[ ! "$reuse_choice" =~ ^[Yy]$ ]]; then
      DOCKER_REPO=""
    fi
  fi
fi

echo -e "${BLUE}🐳 Source: Docker Hub repository${NC}"
need curl; need jq

DOCKER_REPO="${DOCKER_REPO:-$(prompt_default "Enter Docker Hub repo (org/repo)" "")}" 
while [[ ! "$DOCKER_REPO" =~ .+/.+ ]]; do
  echo -e "${RED}Please use the form org/repo${NC}"
  DOCKER_REPO="$(prompt_default "Enter Docker Hub repo (org/repo)" "")"
done
persist_env "DOCKER_REPO" "$DOCKER_REPO"

IS_PRIVATE="${IS_PRIVATE:-$(prompt_default "Is the Docker Hub repo private? (y/N)" "N")}"
if [[ "$IS_PRIVATE" =~ ^[Yy]$ ]]; then
  DOCKERHUB_USERNAME="${DOCKERHUB_USERNAME:-$(prompt_default "Docker Hub username" "")}"
  DOCKERHUB_TOKEN="${DOCKERHUB_TOKEN:-$(prompt_default "Docker Hub access token/password (will be stored in ${ENV_FILE})" "")}"
  if [ -z "$DOCKERHUB_USERNAME" ] || [ -z "$DOCKERHUB_TOKEN" ]; then
    echo -e "${RED}Private repo requires username and token.${NC}"; exit 1;
  fi
  persist_env "DOCKERHUB_USERNAME" "$DOCKERHUB_USERNAME"
  persist_env "DOCKERHUB_TOKEN" "$DOCKERHUB_TOKEN"
else
  persist_env "DOCKERHUB_USERNAME" ""
  persist_env "DOCKERHUB_TOKEN" ""
fi
persist_env "IS_PRIVATE" "$IS_PRIVATE"

echo

echo -e "${BLUE}🔖 Choose a tag to import${NC}"
echo -e "${CYAN}⏬ Fetching tags from Docker Hub...${NC}"
ORG="${DOCKER_REPO%%/*}"; REPO="${DOCKER_REPO##*/}"
  # Docker Hub tags API
if [[ "$IS_PRIVATE" =~ ^[Yy]$ ]]; then
    AUTH_HEADER="Authorization: Bearer $(curl -fsSL \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"${DOCKERHUB_USERNAME}\",\"password\":\"${DOCKERHUB_TOKEN}\"}" \
    https://hub.docker.com/v2/users/login/ | jq -r .token)"
else
    AUTH_HEADER=""
fi
  TAGS="$(curl -fsSL ${AUTH_HEADER:+-H "$AUTH_HEADER"} "https://hub.docker.com/v2/repositories/${ORG}/${REPO}/tags/?page_size=50")" \
    || { echo -e "${RED}Failed to fetch Docker Hub tags${NC}"; exit 1; }
  mapfile -t TROWS < <(echo "$TAGS" | jq -r '.results[]?.name' | grep -vE '^[0-9a-f]{12}$' | head -n 20)
  [ "${#TROWS[@]}" -gt 0 ] || { echo -e "${RED}No tags found on Docker Hub${NC}"; exit 1; }

  echo
  printf "┌────┬──────────────────────────────────────┐\n"
  printf "│ #  │ Tag                                  │\n"
  printf "├────┼──────────────────────────────────────┤\n"
  j=1; for t in "${TROWS[@]}"; do printf "│ %-2d │ %-36s │\n" "$j" "$t"; j=$((j+1)); done
  printf "└────┴──────────────────────────────────────┘\n"
  while :; do
    read -r -p "Select a tag (1-$((j-1))): " choice
    [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -lt "$j" ] && break
    echo -e "${RED}Invalid choice${NC}"
  done
  SRC_TAG="${TROWS[$((choice-1))]}"

echo
echo -e "${BLUE}🎯 Destination registry${NC}"
echo "1) Azure Container Registry (ACR)"
echo "2) GitHub Container Registry (GHCR)"
echo "3) Local Docker (save/tag locally)"
while :; do
  read -r -p "Choose destination [1/2/3]: " DEST
  [[ "$DEST" == "1" || "$DEST" == "2" || "$DEST" == "3" ]] && break
  echo -e "${RED}Please choose 1, 2 or 3${NC}"
done

if [ "$DEST" = "1" ]; then
  # ACR path
  need az
  ACR_NAME="${ACR_NAME:-$(prompt_default "Enter ACR name (without .azurecr.io)" "")}"
  while [ -z "$ACR_NAME" ]; do ACR_NAME="$(prompt_default "Enter ACR name (without .azurecr.io)" "")"; done
  persist_env "ACR_NAME" "$ACR_NAME"

  echo -e "${CYAN}🔎 Checking Azure CLI authentication...${NC}"
  if ! az account show >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠ Not logged in to Azure.${NC}"
    echo -e "${BLUE}👉 Opening interactive login...${NC}"
    az login || { echo -e "${RED}❌ Azure login failed. Exiting.${NC}"; exit 1; }
  fi

  echo -e "${CYAN}🔎 Verifying access to ACR '$ACR_NAME'...${NC}"
  if ! az acr show --name "$ACR_NAME" >/dev/null 2>&1; then
    echo -e "${RED}❌ Cannot access ACR '$ACR_NAME'. Please check permissions or subscription context.${NC}"
    echo -e "${YELLOW}Tip:${NC} Run ${BLUE}az account set --subscription <id>${NC} if you have multiple subscriptions."
    exit 1
  fi

ORG="${DOCKER_REPO%%/*}"; REPO="${DOCKER_REPO##*/}"
  TARGET_TAG_PREFIX="${TAG_PREFIX_IN_ACR:-v}"   # default "v" unless overridden from env
  TARGET_TAG_PREFIX="${TARGET_TAG_PREFIX:-v}"   # fallback to v if unset/empty
  persist_env "TAG_PREFIX_IN_ACR" "$TARGET_TAG_PREFIX"
  # If source tag already starts with v/V, do not add another 'v'
  if [[ "$SRC_TAG" =~ ^[vV] ]]; then
    TARGET_TAG="$SRC_TAG"
  else
    TARGET_TAG="${TARGET_TAG_PREFIX}${SRC_TAG}"
  fi

  # Check if the image already exists in ACR
  echo -e "${CYAN}🔍 Checking if image already exists in ACR...${NC}"
  
  # Get all tags for the repository, or empty if repository doesn't exist
  EXISTING_TAGS=$(az acr repository show-tags --name "$ACR_NAME" --repository "$REPO" --output tsv 2>/dev/null || echo "")
  
  if [ -z "$EXISTING_TAGS" ]; then
    echo -e "${GREEN}✅ Repository ${REPO} does not exist in ACR. Safe to import.${NC}"
  elif echo "$EXISTING_TAGS" | grep -q "^${TARGET_TAG}$"; then
    echo -e "${YELLOW}⚠ Image ${REPO}:${TARGET_TAG} already exists in ${ACR_NAME}.azurecr.io${NC}"
    echo -e "${BLUE}Current target: ${ACR_NAME}.azurecr.io/${REPO}:${TARGET_TAG}${NC}"
    echo -e "${CYAN}Existing tags in repository:${NC}"
    echo "$EXISTING_TAGS" | head -5 | sed 's/^/  - /'
    [ $(echo "$EXISTING_TAGS" | wc -l) -gt 5 ] && echo "  ... and $(($(echo "$EXISTING_TAGS" | wc -l) - 5)) more"
    echo
    
    OVERWRITE_CHOICE="$(prompt_default "Do you want to overwrite the existing image? (y/N)" "N")"
    if [[ ! "$OVERWRITE_CHOICE" =~ ^[Yy]$ ]]; then
      echo -e "${CYAN}📋 Import cancelled. No changes made.${NC}"
      explain_env_persistence
      exit 0
    fi
    echo -e "${YELLOW}⚠ Proceeding with overwrite...${NC}"
  else
    echo -e "${GREEN}✅ Image ${REPO}:${TARGET_TAG} does not exist in ACR (repository has $(echo "$EXISTING_TAGS" | wc -l) other tags). Safe to import.${NC}"
  fi

  echo
  echo -e "${BLUE}📦 Importing docker.io/${DOCKER_REPO}:${SRC_TAG} → ${ACR_NAME}.azurecr.io/${REPO}:${TARGET_TAG}${NC}"
  
  set +e
  if [[ "$IS_PRIVATE" =~ ^[Yy]$ ]]; then
    az acr import --name "$ACR_NAME" \
      --source "docker.io/${DOCKER_REPO}:${SRC_TAG}" \
      --image "${REPO}:${TARGET_TAG}" \
      --username "$DOCKERHUB_USERNAME" \
      --password "$DOCKERHUB_TOKEN"
  else
    az acr import --name "$ACR_NAME" \
      --source "docker.io/${DOCKER_REPO}:${SRC_TAG}" \
      --image "${REPO}:${TARGET_TAG}"
  fi
  rc=$?; set -e
  if [ $rc -ne 0 ]; then
    echo -e "${RED}❌ ACR import failed${NC}"; explain_env_persistence; exit $rc;
  fi

  echo -e "${GREEN}✅ Success!${NC}"
  echo "Source : docker.io/${DOCKER_REPO}:${SRC_TAG}"
  echo "Target : ${ACR_NAME}.azurecr.io/${REPO}:${TARGET_TAG}"

elif [ "$DEST" = "2" ]; then
  # GHCR path
  need docker
  echo -e "${CYAN}🐙 Using GitHub Container Registry (ghcr.io)${NC}"
  GHCR_NAMESPACE="${GHCR_NAMESPACE:-$(prompt_default "GHCR namespace (your GitHub username or org)" "")}"
  while [ -z "$GHCR_NAMESPACE" ]; do GHCR_NAMESPACE="$(prompt_default "GHCR namespace (username/org)" "")"; done
  persist_env "GHCR_NAMESPACE" "$GHCR_NAMESPACE"

  # Default target repo = same leaf name as source repo
  REPO_LEAF="${DOCKER_REPO##*/}"
  GHCR_REPO="${GHCR_REPO:-$(prompt_default "GHCR repository name" "$REPO_LEAF")}"
  persist_env "GHCR_REPO" "$GHCR_REPO"

  echo "Do you want to login to Docker Hub and GHCR now (recommended)?"
  DO_LOGIN="$(prompt_default "Login? (y/N)" "N")"

  if [[ "$DO_LOGIN" =~ ^[Yy]$ ]]; then
    if [[ "$IS_PRIVATE" =~ ^[Yy]$ ]]; then
      echo -e "${CYAN}🔐 docker login docker.io (Docker Hub)${NC}"
      echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin docker.io || { echo -e "${RED}Docker Hub login failed${NC}"; exit 1; }
    fi
    echo -e "${CYAN}🔐 docker login ghcr.io${NC}"
    GHCR_USER="${GHCR_USER:-$(prompt_default "GHCR username (usually your GitHub handle)" "$GHCR_NAMESPACE")}"
    GHCR_TOKEN="${GHCR_TOKEN:-$(prompt_default "GHCR PAT (write:packages) (will be stored in ${ENV_FILE})" "")}"
    [ -n "$GHCR_TOKEN" ] || { echo -e "${RED}GHCR PAT required to push${NC}"; exit 1; }
    persist_env "GHCR_USER" "$GHCR_USER"
    persist_env "GHCR_TOKEN" "$GHCR_TOKEN"
    echo "$GHCR_TOKEN" | docker login -u "$GHCR_USER" --password-stdin ghcr.io || { echo -e "${RED}GHCR login failed${NC}"; exit 1; }
  fi

  SRC_IMAGE="docker.io/${DOCKER_REPO}:${SRC_TAG}"
  DST_IMAGE="ghcr.io/${GHCR_NAMESPACE}/${GHCR_REPO}:${SRC_TAG}"

  echo
  echo -e "${BLUE}⏬ docker pull ${SRC_IMAGE}${NC}"
  docker pull "${SRC_IMAGE}" || { echo -e "${RED}Failed to pull source image${NC}"; explain_env_persistence; exit 1; }

  echo -e "${BLUE}🏷 docker tag ${SRC_IMAGE} ${DST_IMAGE}${NC}"
  docker tag "${SRC_IMAGE}" "${DST_IMAGE}"

  echo -e "${BLUE}⏫ docker push ${DST_IMAGE}${NC}"
  docker push "${DST_IMAGE}" || { echo -e "${RED}Failed to push to GHCR${NC}"; explain_env_persistence; exit 1; }

  echo -e "${GREEN}✅ Success!${NC}"
  echo "Source : ${SRC_IMAGE}"
  echo "Target : ${DST_IMAGE}"
elif [ "$DEST" = "3" ]; then
  # Local Docker path
  need docker
  SRC_IMAGE="docker.io/${DOCKER_REPO}:${SRC_TAG}"
  LOCAL_REPO_LEAF="${DOCKER_REPO##*/}"
  LOCAL_IMAGE="${LOCAL_REPO_LEAF}:${SRC_TAG}"
  echo
  echo -e "${BLUE}⏬ docker pull ${SRC_IMAGE}${NC}"
  docker pull "${SRC_IMAGE}" || { echo -e "${RED}Failed to pull source image${NC}"; explain_env_persistence; exit 1; }
  echo -e "${BLUE}🏷 docker tag ${SRC_IMAGE} ${LOCAL_IMAGE}${NC}"
  docker tag "${SRC_IMAGE}" "${LOCAL_IMAGE}" || { echo -e "${RED}Failed to tag locally${NC}"; explain_env_persistence; exit 1; }
  echo -e "${GREEN}✅ Saved locally as ${LOCAL_IMAGE}${NC}"
fi

explain_env_persistence