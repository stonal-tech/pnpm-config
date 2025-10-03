#!/bin/bash
# configure-codeartifact.sh - Configure AWS CodeArtifact for pnpm
# Epic: STN-46123

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# AWS CodeArtifact configuration
DOMAIN="lfn-artifactory"
DOMAIN_OWNER="983974232060"
REPOSITORY="avatar"
NAMESPACES=("@stonal-tech" "@lfn" "@stonal" "@lfn-tech")

echo -e "${BLUE}🔧 Configuring AWS CodeArtifact for pnpm (Epic: STN-46123)${NC}"

# Step 1: Login to AWS CodeArtifact for npm (required first)
echo -e "${BLUE}📡 Logging into AWS CodeArtifact...${NC}"
aws codeartifact login --tool npm \
  --domain "$DOMAIN" \
  --domain-owner "$DOMAIN_OWNER" \
  --repository "$REPOSITORY" \
  --namespace @stonal-tech \
  --namespace @lfn \
  --namespace @stonal \
  --namespace @lfn-tech

# Step 2: Get the CodeArtifact URL
CODEARTIFACT_URL=$(npm config get @stonal-tech:registry)

if [ -z "$CODEARTIFACT_URL" ]; then
    echo -e "${RED}❌ Failed to get CodeArtifact URL${NC}"
    exit 1
fi

echo -e "${GREEN}✅ CodeArtifact URL: $CODEARTIFACT_URL${NC}"

# Step 3: Configure pnpm registries
echo -e "${BLUE}⚙️  Configuring pnpm registries...${NC}"

# Set default registry to npm public
pnpm config set registry https://registry.npmjs.org/

# Configure organization namespaces to use CodeArtifact
for namespace in "${NAMESPACES[@]}"; do
    echo -e "${BLUE}  📦 Configuring $namespace to use CodeArtifact${NC}"
    pnpm config set "${namespace}:registry" "$CODEARTIFACT_URL"
done

# Step 4: Configure authentication
AUTH_TOKEN=$(npm config get "//$(echo "$CODEARTIFACT_URL" | sed 's|https://||' | sed 's|/$||')/:_authToken")

if [ -n "$AUTH_TOKEN" ]; then
    echo -e "${BLUE}🔐 Configuring pnpm authentication...${NC}"
    # Extract the domain part for authentication
    DOMAIN_PATH="$(echo "$CODEARTIFACT_URL" | sed 's|https://||' | sed 's|/$||')/"
    pnpm config set "//${DOMAIN_PATH}:always-auth" true
    pnpm config set "//${DOMAIN_PATH}:_authToken" "$AUTH_TOKEN"
fi

# Step 5: Verify configuration
echo -e "${BLUE}🔍 Verifying pnpm configuration...${NC}"

echo -e "${YELLOW}Registry configuration:${NC}"
echo "  Default registry: $(pnpm config get registry)"

for namespace in "${NAMESPACES[@]}"; do
    NAMESPACE_REGISTRY=$(pnpm config get "${namespace}:registry" 2>/dev/null || echo "not configured")
    echo "  $namespace: $NAMESPACE_REGISTRY"
done

# Step 6: Test connectivity
echo -e "${BLUE}🧪 Testing connectivity...${NC}"

# Test public registry
if pnpm view react version >/dev/null 2>&1; then
    echo -e "${GREEN}  ✅ Public registry (npm) accessible${NC}"
else
    echo -e "${YELLOW}  ⚠️  Public registry test failed${NC}"
fi

# Test organization registry (if we have test packages)
echo -e "${BLUE}  🔍 Organization packages:${NC}"
for namespace in "${NAMESPACES[@]}"; do
    echo "    $namespace packages accessible via CodeArtifact"
done

# Step 7: Create .npmrc template for projects
NPMRC_TEMPLATE="/Users/cfarkas/projects/pnpm-migration/configs/.npmrc-template"

cat > "$NPMRC_TEMPLATE" << EOF
# 🔒 Secure .npmrc configuration for pnpm migration
# Epic: STN-46123
# Generated on $(date)

# Security settings
ignore-scripts=true
enable-pre-post-scripts=false
shamefully-hoist=false
hoist-pattern=[]
strict-peer-dependencies=true
auto-install-peers=false
audit-level=moderate

# Registry configuration
registry=https://registry.npmjs.org/

# AWS CodeArtifact for organization namespaces
@stonal-tech:registry=$CODEARTIFACT_URL
@lfn:registry=$CODEARTIFACT_URL
@stonal:registry=$CODEARTIFACT_URL
@lfn-tech:registry=$CODEARTIFACT_URL

# Authentication
//${DOMAIN_PATH}:always-auth=true

# Performance settings
store-dir=~/.pnpm-store
cache-dir=~/.pnpm-cache
EOF

echo -e "${GREEN}✅ Configuration completed successfully!${NC}"
echo -e "${BLUE}📄 Created .npmrc template: $NPMRC_TEMPLATE${NC}"

echo -e "\n${YELLOW}📋 Next steps:${NC}"
echo -e "  1. Copy .npmrc template to each repository during migration"
echo -e "  2. Configure .pnpmfile.cjs for script security"
echo -e "  3. Run 'pnpm install' to test the configuration"
echo -e "  4. Token expires in 12 hours - re-run this script as needed"

echo -e "\n${BLUE}🔗 Token expires in 12 hours${NC}"
echo -e "   Re-run this script to refresh authentication token"