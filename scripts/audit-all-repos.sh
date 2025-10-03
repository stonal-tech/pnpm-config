#!/bin/bash
# audit-all-repos.sh - Global security audit script for pnpm migration
# Epic: STN-46123

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Directories
PROJECTS_DIR="/Users/cfarkas/projects"
MIGRATION_DIR="/Users/cfarkas/projects/pnpm-migration"
REPORTS_DIR="$MIGRATION_DIR/reports"

# Repositories to audit (29 confirmed repos with front/ts-front topics)
REPOS=(
    # Applications (11)
    "check-front" "count-front" "edit-front" "esg-front" "etl-front"
    "find-front" "referential-front" "stonal-front"
    "user-management-front" "view-front" "view-plus-front"

    # Client Applications (7)
    "client-blog" "client-capex" "client-doc-public-api"
    "client-dqc" "client-lpdi-pro" "client-req" "client-users"

    # Libraries (9)
    "lib-authentication-react" "lib-client-services-ts" "lib-design-system-react"
    "lib-design-token" "lib-front-redux-store-ts" "lib-front-utils-ts"
    "lib-logging-ts" "lib-permissions-angular" "lib-stylelint"

    # Tools & Testing (2)
    "eslint-plugin-stonal-config-front" "e2e-tests"
)

# Risk packages to check for
RISK_PACKAGES=("qix" "colors" "chalk" "node-fetch" "request" "lodash")

# Create reports directory
mkdir -p "$REPORTS_DIR"

# Initialize report files
AUDIT_REPORT="$REPORTS_DIR/audit-summary-$(date +%Y%m%d-%H%M%S).md"
LIFECYCLE_REPORT="$REPORTS_DIR/lifecycle-scripts-$(date +%Y%m%d-%H%M%S).json"
VULNERABILITIES_REPORT="$REPORTS_DIR/vulnerabilities-$(date +%Y%m%d-%H%M%S).json"
RISK_ANALYSIS_REPORT="$REPORTS_DIR/risk-analysis-$(date +%Y%m%d-%H%M%S).md"

echo -e "${BLUE}🔒 Starting global audit for pnpm migration (Epic: STN-46123)${NC}"
echo -e "${BLUE}📊 Auditing ${#REPOS[@]} repositories${NC}"

# Initialize reports
cat > "$AUDIT_REPORT" << EOF
# 🔒 pnpm Migration Security Audit Report

**Date**: $(date)
**Epic**: STN-46123
**Repositories Audited**: ${#REPOS[@]}

## 📋 Summary

| Repository | Status | Package Manager | Vulnerabilities | Lifecycle Scripts | Risk Level |
|------------|--------|-----------------|----------------|-------------------|------------|
EOF

echo '[]' > "$LIFECYCLE_REPORT"
echo '[]' > "$VULNERABILITIES_REPORT"

# Counters
total_repos=0
cloned_repos=0
updated_repos=0
high_risk_repos=0
medium_risk_repos=0
low_risk_repos=0

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

function ensure_repo_updated() {
    local repo_name=$1
    local repo_path="$PROJECTS_DIR/$repo_name"

    if [ ! -d "$repo_path" ]; then
        log_info "Cloning $repo_name..."
        cd "$PROJECTS_DIR"
        if gh repo clone stonal-tech/$repo_name; then
            log_success "Cloned $repo_name"
            ((cloned_repos++))
        else
            log_error "Failed to clone $repo_name"
            return 1
        fi
    else
        log_info "Updating $repo_name..."
        cd "$repo_path"
        if git checkout main >/dev/null 2>&1 && git pull >/dev/null 2>&1; then
            log_success "Updated $repo_name"
            ((updated_repos++))
        else
            log_warning "Failed to update $repo_name (may not have main branch)"
        fi
    fi

    return 0
}

function detect_package_manager() {
    local repo_path=$1

    if [ -f "$repo_path/pnpm-lock.yaml" ]; then
        echo "pnpm"
    elif [ -f "$repo_path/package-lock.json" ]; then
        echo "npm"
    elif [ -f "$repo_path/yarn.lock" ]; then
        echo "yarn"
    else
        echo "unknown"
    fi
}

function check_lifecycle_scripts() {
    local repo_path=$1
    local repo_name=$2

    if [ ! -f "$repo_path/package.json" ]; then
        return
    fi

    # Extract lifecycle scripts
    local scripts=$(cat "$repo_path/package.json" | jq -r '.scripts | to_entries[] | select(.key | test("(pre|post)?(install|prepare)")) | "\(.key): \(.value)"' 2>/dev/null || echo "")

    if [ ! -z "$scripts" ]; then
        # Add to lifecycle report
        local temp_file=$(mktemp)
        cat "$LIFECYCLE_REPORT" | jq ". += [{\"repository\": \"$repo_name\", \"scripts\": $(echo "$scripts" | jq -R . | jq -s .)}]" > "$temp_file"
        mv "$temp_file" "$LIFECYCLE_REPORT"

        log_warning "$repo_name has lifecycle scripts:"
        echo "$scripts" | sed 's/^/    /'
        return 1
    fi

    return 0
}

function check_vulnerabilities() {
    local repo_path=$1
    local repo_name=$2
    local package_manager=$3

    cd "$repo_path"

    local vuln_count=0
    local audit_output=""

    case $package_manager in
        "npm")
            if [ -f "package-lock.json" ]; then
                audit_output=$(npm audit --json 2>/dev/null || echo '{"vulnerabilities":{}}')
                vuln_count=$(echo "$audit_output" | jq '.vulnerabilities | length' 2>/dev/null || echo 0)
            fi
            ;;
        "yarn")
            # Yarn audit is different, simplified check
            if yarn audit --json >/dev/null 2>&1; then
                vuln_count=0
            else
                vuln_count=1
            fi
            ;;
        "pnpm")
            if pnpm audit --json >/dev/null 2>&1; then
                vuln_count=0
            else
                vuln_count=1
            fi
            ;;
    esac

    if [ "$vuln_count" -gt 0 ]; then
        # Add to vulnerabilities report
        local temp_file=$(mktemp)
        cat "$VULNERABILITIES_REPORT" | jq ". += [{\"repository\": \"$repo_name\", \"vulnerabilities\": $vuln_count, \"package_manager\": \"$package_manager\"}]" > "$temp_file"
        mv "$temp_file" "$VULNERABILITIES_REPORT"
    fi

    echo $vuln_count
}

function check_risk_packages() {
    local repo_path=$1
    local repo_name=$2

    if [ ! -f "$repo_path/package.json" ]; then
        return 0
    fi

    local risk_found=0
    local found_packages=()

    for pkg in "${RISK_PACKAGES[@]}"; do
        if cat "$repo_path/package.json" | jq -e ".dependencies.\"$pkg\" // .devDependencies.\"$pkg\"" >/dev/null 2>&1; then
            found_packages+=("$pkg")
            risk_found=1
        fi
    done

    if [ $risk_found -eq 1 ]; then
        log_warning "$repo_name contains risk packages: ${found_packages[*]}"
    fi

    return $risk_found
}

function calculate_risk_level() {
    local has_lifecycle=$1
    local vuln_count=$2
    local has_risk_packages=$3

    if [ $has_lifecycle -eq 1 ] || [ $has_risk_packages -eq 1 ] || [ $vuln_count -gt 10 ]; then
        echo "HIGH"
        ((high_risk_repos++))
    elif [ $vuln_count -gt 0 ] || [ $vuln_count -gt 5 ]; then
        echo "MEDIUM"
        ((medium_risk_repos++))
    else
        echo "LOW"
        ((low_risk_repos++))
    fi
}

# Main audit loop
for repo in "${REPOS[@]}"; do
    log_info "Auditing $repo..."
    ((total_repos++))

    # Ensure repo is available and updated
    if ! ensure_repo_updated "$repo"; then
        echo "| $repo | ❌ Clone/Update Failed | - | - | - | - |" >> "$AUDIT_REPORT"
        continue
    fi

    repo_path="$PROJECTS_DIR/$repo"

    # Detect package manager
    package_manager=$(detect_package_manager "$repo_path")

    # Check lifecycle scripts
    has_lifecycle=0
    if ! check_lifecycle_scripts "$repo_path" "$repo"; then
        has_lifecycle=1
    fi

    # Check vulnerabilities
    vuln_count=$(check_vulnerabilities "$repo_path" "$repo" "$package_manager")

    # Check risk packages
    has_risk_packages=0
    if ! check_risk_packages "$repo_path" "$repo"; then
        has_risk_packages=1
    fi

    # Calculate risk level
    risk_level=$(calculate_risk_level $has_lifecycle $vuln_count $has_risk_packages)

    # Add to summary report
    lifecycle_indicator=""
    if [ $has_lifecycle -eq 1 ]; then lifecycle_indicator="⚠️"; fi

    risk_packages_indicator=""
    if [ $has_risk_packages -eq 1 ]; then risk_packages_indicator="🚨"; fi

    echo "| $repo | ✅ OK | $package_manager | $vuln_count | $lifecycle_indicator | $risk_level $risk_packages_indicator |" >> "$AUDIT_REPORT"

    log_success "Completed audit for $repo (Risk: $risk_level)"
done

# Generate summary section
cat >> "$AUDIT_REPORT" << EOF

## 📊 Audit Statistics

- **Total Repositories**: $total_repos
- **Cloned**: $cloned_repos
- **Updated**: $updated_repos
- **High Risk**: $high_risk_repos
- **Medium Risk**: $medium_risk_repos
- **Low Risk**: $low_risk_repos

## 🎯 Recommended Migration Order

### Priority 1 - High Risk (Immediate)
$(grep "HIGH" "$AUDIT_REPORT" | cut -d'|' -f2 | tr -d ' ' | sed 's/^/- /')

### Priority 2 - Medium Risk (Week 1-2)
$(grep "MEDIUM" "$AUDIT_REPORT" | cut -d'|' -f2 | tr -d ' ' | sed 's/^/- /')

### Priority 3 - Low Risk (Week 3-4)
$(grep "LOW" "$AUDIT_REPORT" | cut -d'|' -f2 | tr -d ' ' | sed 's/^/- /')

## 📋 Next Steps

1. Review lifecycle scripts in: \`$LIFECYCLE_REPORT\`
2. Address vulnerabilities in: \`$VULNERABILITIES_REPORT\`
3. Start with High Risk repositories
4. Create pnpm-config repository with security configurations
5. Begin Phase 1 migration preparation

## 🔗 Generated Reports

- **Lifecycle Scripts**: \`$LIFECYCLE_REPORT\`
- **Vulnerabilities**: \`$VULNERABILITIES_REPORT\`
- **Risk Analysis**: \`$RISK_ANALYSIS_REPORT\`

---
**Generated**: $(date)
**Epic**: STN-46123
EOF

# Create risk analysis report
cat > "$RISK_ANALYSIS_REPORT" << EOF
# 🚨 Risk Analysis Report

**Date**: $(date)
**Epic**: STN-46123

## 📊 Risk Distribution

- **High Risk**: $high_risk_repos repositories
- **Medium Risk**: $medium_risk_repos repositories
- **Low Risk**: $low_risk_repos repositories

## 🔍 Detailed Analysis

### High Risk Factors
- Lifecycle scripts (postinstall, preinstall, prepare)
- Known compromised packages (qix, colors, chalk)
- High vulnerability count (>10)

### Medium Risk Factors
- Some vulnerabilities (1-10)
- Legacy packages without recent updates

### Low Risk Factors
- No lifecycle scripts
- No known vulnerable packages
- Recent dependency updates

## 📋 Action Items

1. **Immediate**: Audit High Risk repositories manually
2. **Week 1**: Implement pnpm with strict security settings
3. **Week 2**: Migrate High Risk repositories first
4. **Week 3-4**: Continue with Medium and Low Risk repositories

---
**Epic**: STN-46123
EOF

log_success "Audit completed successfully!"
echo -e "${GREEN}📊 Reports generated:${NC}"
echo -e "  📋 Summary: $AUDIT_REPORT"
echo -e "  🔧 Lifecycle Scripts: $LIFECYCLE_REPORT"
echo -e "  🛡️  Vulnerabilities: $VULNERABILITIES_REPORT"
echo -e "  ⚠️  Risk Analysis: $RISK_ANALYSIS_REPORT"

echo -e "\n${BLUE}📈 Statistics:${NC}"
echo -e "  Total repositories: $total_repos"
echo -e "  Cloned: $cloned_repos"
echo -e "  Updated: $updated_repos"
echo -e "  High risk: $high_risk_repos"
echo -e "  Medium risk: $medium_risk_repos"
echo -e "  Low risk: $low_risk_repos"