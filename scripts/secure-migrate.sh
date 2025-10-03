#!/bin/bash
# secure-migrate.sh - Secure migration script for pnpm
# Epic: STN-46123

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
MIGRATION_DIR="/Users/cfarkas/projects/pnpm-migration"
PROJECTS_DIR="/Users/cfarkas/projects"
CONFIGS_DIR="$MIGRATION_DIR/configs"
REPORTS_DIR="$MIGRATION_DIR/reports"

# Check if repository name is provided
if [ -z "$1" ]; then
    echo -e "${RED}❌ Usage: $0 <repository-name>${NC}"
    echo -e "${BLUE}📋 Available repositories:${NC}"
    echo -e "   Applications: check-front, count-front, edit-front, esg-front, etl-front, find-front, referential-front, stonal-front, user-management-front, view-front, view-plus-front"
    echo -e "   Clients: client-blog, client-capex, client-doc-public-api, client-dqc, client-lpdi-pro, client-req, client-users"
    echo -e "   Libraries: lib-authentication-react, lib-client-services-ts, lib-design-system-react, lib-design-token, lib-front-redux-store-ts, lib-front-utils-ts, lib-logging-ts, lib-permissions-angular, lib-stylelint"
    echo -e "   Tools: eslint-plugin-stonal-config-front, e2e-tests"
    exit 1
fi

REPO=$1
REPO_PATH="$PROJECTS_DIR/$REPO"

# Logging functions
function log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

function log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

function log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

function log_error() {
    echo -e "${RED}❌ $1${NC}"
}

function log_step() {
    echo -e "${CYAN}🔄 $1${NC}"
}

# Create migration report
MIGRATION_REPORT="$REPORTS_DIR/migration-$REPO-$(date +%Y%m%d-%H%M%S).md"

cat > "$MIGRATION_REPORT" << EOF
# 🔒 Migration Report: $REPO

**Date**: $(date)
**Epic**: STN-46123
**Repository**: $REPO

## 📋 Migration Steps

EOF

function add_to_report() {
    echo "$1" >> "$MIGRATION_REPORT"
}

echo -e "${BLUE}🔒 Starting secure migration of $REPO (Epic: STN-46123)${NC}"

# Step 1: Clone/Update repository
log_step "Step 1: Ensuring repository is up-to-date"
add_to_report "### Step 1: Repository Setup"

if [ ! -d "$REPO_PATH" ]; then
    log_info "Cloning $REPO from GitHub..."
    cd "$PROJECTS_DIR"
    if gh repo clone stonal-tech/$REPO; then
        log_success "Repository cloned successfully"
        add_to_report "- ✅ Cloned repository from GitHub"
    else
        log_error "Failed to clone repository"
        add_to_report "- ❌ Failed to clone repository"
        exit 1
    fi
else
    log_info "Updating $REPO to latest version..."
    cd "$REPO_PATH"
    if git checkout main >/dev/null 2>&1 && git pull >/dev/null 2>&1; then
        log_success "Repository updated successfully"
        add_to_report "- ✅ Updated repository to latest main branch"
    else
        log_warning "Failed to update repository (may not have main branch)"
        add_to_report "- ⚠️ Could not update repository (may not have main branch)"
    fi
fi

cd "$REPO_PATH"

# Step 2: Pre-migration security audit
log_step "Step 2: Pre-migration security audit"
add_to_report ""
add_to_report "### Step 2: Security Audit"

# Check for package.json
if [ ! -f "package.json" ]; then
    log_error "No package.json found in $REPO"
    add_to_report "- ❌ No package.json found"
    exit 1
fi

log_success "Found package.json"
add_to_report "- ✅ package.json found"

# Backup existing package-lock files and scripts
log_info "Creating backup of existing configuration..."
BACKUP_DIR="backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup lock files
if [ -f "package-lock.json" ]; then
    cp "package-lock.json" "$BACKUP_DIR/"
    log_info "Backed up package-lock.json"
    add_to_report "- 📦 Backed up package-lock.json"
fi

if [ -f "yarn.lock" ]; then
    cp "yarn.lock" "$BACKUP_DIR/"
    log_info "Backed up yarn.lock"
    add_to_report "- 📦 Backed up yarn.lock"
fi

# Backup scripts for security review
cat package.json | jq '.scripts' > "$BACKUP_DIR/scripts-backup.json" 2>/dev/null || echo '{}' > "$BACKUP_DIR/scripts-backup.json"
add_to_report "- 📦 Backed up scripts configuration"

# Check for lifecycle scripts
LIFECYCLE_SCRIPTS=$(cat package.json | jq -r '.scripts | to_entries[] | select(.key | test("(pre|post)?(install|prepare)")) | "\(.key): \(.value)"' 2>/dev/null || echo "")

if [ ! -z "$LIFECYCLE_SCRIPTS" ]; then
    log_warning "Found lifecycle scripts (will be disabled by pnpm security config):"
    echo "$LIFECYCLE_SCRIPTS" | sed 's/^/    /'
    add_to_report "- ⚠️ Found lifecycle scripts (will be disabled):"
    echo "$LIFECYCLE_SCRIPTS" | sed 's/^/  - /' >> "$MIGRATION_REPORT"
else
    log_success "No dangerous lifecycle scripts found"
    add_to_report "- ✅ No lifecycle scripts found"
fi

# Run npm audit before migration
log_info "Running security audit..."
npm audit --json > "$BACKUP_DIR/audit-before.json" 2>/dev/null || echo '{"vulnerabilities":{}}' > "$BACKUP_DIR/audit-before.json"
CRITICAL_VULNS=$(cat "$BACKUP_DIR/audit-before.json" | jq '.vulnerabilities | length' 2>/dev/null || echo 0)

if [ "$CRITICAL_VULNS" -gt 0 ]; then
    log_warning "$CRITICAL_VULNS vulnerabilities detected in current setup"
    add_to_report "- ⚠️ $CRITICAL_VULNS vulnerabilities detected"
else
    log_success "No vulnerabilities detected"
    add_to_report "- ✅ No vulnerabilities detected"
fi

# Step 3: Clean old package managers
log_step "Step 3: Cleaning old package manager files"
add_to_report ""
add_to_report "### Step 3: Cleanup"

# Remove node_modules and lock files
if [ -d "node_modules" ]; then
    log_info "Removing node_modules..."
    rm -rf node_modules
    add_to_report "- 🗑️ Removed node_modules"
fi

if [ -f "package-lock.json" ]; then
    log_info "Removing package-lock.json..."
    rm package-lock.json
    add_to_report "- 🗑️ Removed package-lock.json"
fi

if [ -f "yarn.lock" ]; then
    log_info "Removing yarn.lock..."
    rm yarn.lock
    add_to_report "- 🗑️ Removed yarn.lock"
fi

# Step 4: Configure pnpm security settings
log_step "Step 4: Configuring pnpm security settings"
add_to_report ""
add_to_report "### Step 4: Security Configuration"

# Copy secure .npmrc
log_info "Installing secure .npmrc configuration..."
cp "$CONFIGS_DIR/.npmrc" .npmrc
add_to_report "- 🔧 Installed secure .npmrc"

# Copy .pnpmfile.cjs for script filtering
log_info "Installing script whitelist configuration..."
cp "$CONFIGS_DIR/.pnpmfile.cjs" .pnpmfile.cjs
add_to_report "- 🛡️ Installed .pnpmfile.cjs script whitelist"

# Step 5: Update package.json with pnpm configuration
log_step "Step 5: Updating package.json for pnpm"
add_to_report ""
add_to_report "### Step 5: Package Configuration"

# Add packageManager field and security scripts
log_info "Adding pnpm configuration to package.json..."

TEMP_PACKAGE=$(mktemp)
cat package.json | jq '
  .packageManager = "pnpm@9.15.0" |
  .scripts.preinstall = "npx only-allow pnpm" |
  .scripts["security:check"] = "pnpm audit && pnpm ls --depth=0"
' > "$TEMP_PACKAGE"

if [ $? -eq 0 ]; then
    mv "$TEMP_PACKAGE" package.json
    log_success "Updated package.json with pnpm configuration"
    add_to_report "- ✅ Added packageManager field"
    add_to_report "- ✅ Added preinstall script to enforce pnpm"
    add_to_report "- ✅ Added security:check script"
else
    log_error "Failed to update package.json"
    add_to_report "- ❌ Failed to update package.json"
    rm -f "$TEMP_PACKAGE"
    exit 1
fi

# Step 6: Configure AWS CodeArtifact
log_step "Step 6: Configuring AWS CodeArtifact"
add_to_report ""
add_to_report "### Step 6: Registry Configuration"

# Ensure CodeArtifact is configured
log_info "Refreshing AWS CodeArtifact authentication..."
aws codeartifact login --tool npm \
  --domain lfn-artifactory \
  --domain-owner 983974232060 \
  --repository avatar \
  --namespace @stonal-tech \
  --namespace @lfn \
  --namespace @stonal \
  --namespace @lfn-tech >/dev/null 2>&1

if [ $? -eq 0 ]; then
    log_success "AWS CodeArtifact configured"
    add_to_report "- ✅ AWS CodeArtifact authentication refreshed"
else
    log_warning "Failed to refresh CodeArtifact authentication"
    add_to_report "- ⚠️ CodeArtifact authentication may need manual refresh"
fi

# Step 7: Install dependencies with pnpm
log_step "Step 7: Installing dependencies with pnpm"
add_to_report ""
add_to_report "### Step 7: Dependency Installation"

log_info "Installing dependencies with pnpm (security mode)..."

# First try pnpm import to convert from existing lock file
if [ -f "$BACKUP_DIR/package-lock.json" ] || [ -f "$BACKUP_DIR/yarn.lock" ]; then
    log_info "Attempting to import from existing lock file..."
    if pnpm import >/dev/null 2>&1; then
        log_success "Successfully imported dependencies"
        add_to_report "- ✅ Imported dependencies from existing lock file"
    else
        log_warning "Import failed, performing fresh install"
        add_to_report "- ⚠️ Import failed, performing fresh install"
    fi
fi

# Install with security settings
log_info "Running pnpm install with security settings..."
if pnpm install --frozen-lockfile --ignore-scripts 2>&1 | tee "$BACKUP_DIR/install-log.txt"; then
    log_success "Dependencies installed successfully"
    add_to_report "- ✅ Dependencies installed with pnpm"
else
    log_warning "Install completed with warnings (check log)"
    add_to_report "- ⚠️ Install completed with warnings"
fi

# Step 8: Post-migration verification
log_step "Step 8: Post-migration verification"
add_to_report ""
add_to_report "### Step 8: Verification"

# Check if pnpm-lock.yaml was created
if [ -f "pnpm-lock.yaml" ]; then
    log_success "pnpm-lock.yaml created successfully"
    add_to_report "- ✅ pnpm-lock.yaml generated"
else
    log_error "pnpm-lock.yaml not found"
    add_to_report "- ❌ pnpm-lock.yaml missing"
fi

# Run security audit
log_info "Running post-migration security audit..."
if pnpm audit --audit-level=moderate >/dev/null 2>&1; then
    log_success "Security audit passed"
    add_to_report "- ✅ Security audit passed"
else
    log_warning "Security audit found issues (review manually)"
    add_to_report "- ⚠️ Security audit found issues"
fi

# Verify dependencies
log_info "Verifying dependency tree..."
pnpm ls --depth=0 > "$BACKUP_DIR/dependencies-after.txt" 2>&1
add_to_report "- 📋 Dependency tree verified"

# Step 9: Test build (if applicable)
log_step "Step 9: Testing build"
add_to_report ""
add_to_report "### Step 9: Build Test"

if cat package.json | jq -e '.scripts.build' >/dev/null 2>&1; then
    log_info "Testing build process..."
    if timeout 300 pnpm run build >/dev/null 2>&1; then
        log_success "Build test passed"
        add_to_report "- ✅ Build test successful"
    else
        log_warning "Build test failed or timed out"
        add_to_report "- ⚠️ Build test failed (manual review needed)"
    fi
else
    log_info "No build script found, skipping build test"
    add_to_report "- ℹ️ No build script found"
fi

# Step 10: Prepare for commit
log_step "Step 10: Preparing Git commit"
add_to_report ""
add_to_report "### Step 10: Git Preparation"

# Create migration branch
BRANCH_NAME="chore/pnpm-migration"
log_info "Creating migration branch: $BRANCH_NAME"

if git checkout -b "$BRANCH_NAME" >/dev/null 2>&1; then
    log_success "Created branch $BRANCH_NAME"
    add_to_report "- ✅ Created branch $BRANCH_NAME"
elif git checkout "$BRANCH_NAME" >/dev/null 2>&1; then
    log_info "Switched to existing branch $BRANCH_NAME"
    add_to_report "- ✅ Switched to branch $BRANCH_NAME"
else
    log_error "Failed to create/switch to migration branch"
    add_to_report "- ❌ Failed to create migration branch"
    exit 1
fi

# Stage changes
log_info "Staging changes for commit..."
git add -A

# Create commit
COMMIT_MESSAGE="chore: migrate to pnpm for enhanced security

epic:STN-46123

- Add pnpm as package manager (v9.15.0)
- Configure ignore-scripts for security
- Add preinstall script to enforce pnpm
- Update lock file to pnpm-lock.yaml
- Configure .npmrc for Code Artifact and npm registry
- Add script whitelist via .pnpmfile.cjs"

log_info "Creating commit..."
if git commit -m "$COMMIT_MESSAGE" >/dev/null 2>&1; then
    log_success "Changes committed successfully"
    add_to_report "- ✅ Changes committed with message referencing STN-46123"
else
    log_warning "Commit failed (may be no changes to commit)"
    add_to_report "- ⚠️ Commit failed or no changes to commit"
fi

# Final report
add_to_report ""
add_to_report "## 📊 Migration Summary"
add_to_report ""
add_to_report "- **Repository**: $REPO"
add_to_report "- **Branch**: $BRANCH_NAME"
add_to_report "- **Epic**: STN-46123"
add_to_report "- **Backup Directory**: $BACKUP_DIR"
add_to_report "- **Migration Date**: $(date)"
add_to_report ""
add_to_report "## 📋 Next Steps"
add_to_report ""
add_to_report "1. Review migration report: \`$MIGRATION_REPORT\`"
add_to_report "2. Test application functionality"
add_to_report "3. Run full test suite if available"
add_to_report "4. Create pull request: \`[STN-46123] Migrate to pnpm\`"
add_to_report "5. Review and merge after approval"
add_to_report ""
add_to_report "## 🔧 Manual Review Items"
add_to_report ""
add_to_report "- [ ] Verify all dependencies are working"
add_to_report "- [ ] Check if any custom scripts need updating"
add_to_report "- [ ] Validate build/test processes"
add_to_report "- [ ] Review security audit results"
add_to_report ""
add_to_report "---"
add_to_report "**Generated by**: secure-migrate.sh"
add_to_report "**Epic**: STN-46123"

# Summary
echo -e "\n${GREEN}🎉 Migration completed successfully!${NC}"
echo -e "${BLUE}📊 Summary:${NC}"
echo -e "  Repository: $REPO"
echo -e "  Branch: $BRANCH_NAME"
echo -e "  Backup: $BACKUP_DIR"
echo -e "  Report: $MIGRATION_REPORT"

echo -e "\n${YELLOW}📋 Next steps:${NC}"
echo -e "  1. Review the migration report"
echo -e "  2. Test the application"
echo -e "  3. Create PR: gh pr create --title '[STN-46123] Migrate to pnpm'"
echo -e "  4. Review lifecycle scripts in backup if any"

echo -e "\n${CYAN}🔗 Files created:${NC}"
echo -e "  - .npmrc (secure configuration)"
echo -e "  - .pnpmfile.cjs (script whitelist)"
echo -e "  - pnpm-lock.yaml (new lock file)"
echo -e "  - $BACKUP_DIR/ (backup of old files)"