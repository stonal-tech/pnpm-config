# 🔒 pnpm Security Configuration

> Centralized security configurations for stonal-tech front-end repositories

**Epic**: STN-46123
**Organization**: stonal-tech
**Purpose**: Supply chain security enhancement via pnpm migration

## 📋 Overview

This repository provides centralized, security-focused configurations for migrating front-end repositories from npm/yarn to pnpm. All configurations prioritize security over convenience to protect against supply chain attacks.

## 🗂️ Repository Structure

```
pnpm-config/
├── .npmrc                          # Secure npm/pnpm configuration
├── .pnpmfile.cjs                   # Script whitelist and filtering
├── github-workflow-security.yml    # CI/CD security checks
├── scripts/                        # Migration and audit tools
│   ├── audit-all-repos.sh         # Global security audit
│   ├── configure-codeartifact.sh  # AWS CodeArtifact setup
│   └── secure-migrate.sh          # Repository migration tool
└── README.md                       # This file
```

## 🔧 Configuration Files

### `.npmrc` - Security Configuration
- **`ignore-scripts=true`**: Prevents automatic script execution
- **`strict-peer-dependencies=true`**: Eliminates phantom dependencies
- **Registry separation**: Public packages from npm, organization packages from CodeArtifact
- **Enhanced audit settings**: Moderate security level enforcement

### `.pnpmfile.cjs` - Script Whitelist
- **Whitelist approach**: Only allows scripts from trusted packages
- **Dangerous package blocking**: Prevents installation of known compromised packages
- **Audit logging**: Tracks all security actions for compliance

### `github-workflow-security.yml` - CI/CD Security
- **Lifecycle script detection**: Alerts on dangerous scripts
- **Vulnerability scanning**: Automated security audits
- **Build verification**: Ensures security doesn't break functionality
- **Compliance reporting**: Generates security reports for each build

## 🚀 Usage

### For Repository Migration

1. **Clone this repository**:
   ```bash
   git clone https://github.com/stonal-tech/pnpm-config.git
   cd pnpm-config
   ```

2. **Run global audit** (optional but recommended):
   ```bash
   ./scripts/audit-all-repos.sh
   ```

3. **Migrate a specific repository**:
   ```bash
   ./scripts/secure-migrate.sh <repository-name>
   ```

4. **Configure AWS CodeArtifact**:
   ```bash
   ./scripts/configure-codeartifact.sh
   ```

### For New Projects

1. **Copy security configurations**:
   ```bash
   cp pnpm-config/.npmrc your-project/
   cp pnpm-config/.pnpmfile.cjs your-project/
   ```

2. **Add GitHub Actions workflow**:
   ```bash
   mkdir -p your-project/.github/workflows/
   cp pnpm-config/github-workflow-security.yml your-project/.github/workflows/
   ```

3. **Update package.json**:
   ```json
   {
     "packageManager": "pnpm@9.15.0",
     "scripts": {
       "preinstall": "npx only-allow pnpm",
       "security:check": "pnpm audit && pnpm ls --depth=0"
     }
   }
   ```

## 🛡️ Security Features

### Supply Chain Protection
- **Script execution blocking**: Prevents malicious postinstall scripts
- **Package filtering**: Blocks known compromised packages
- **Integrity verification**: SHA512 checksums for all packages
- **Strict isolation**: No cross-package contamination

### Audit & Compliance
- **Automated scanning**: CI/CD integration for continuous monitoring
- **Detailed reporting**: Migration and security reports for each repository
- **Version tracking**: Epic STN-46123 referenced in all changes

### Performance Benefits
- **2-3x faster installations**: pnpm's efficient linking system
- **50% disk space savings**: Shared package store
- **30-40% CI time reduction**: Faster dependency resolution

## 📊 Migration Status

### Phase 0-1: Setup & Preparation ✅ COMPLETED
- [x] JIRA Epic STN-46123 created
- [x] Global audit script developed
- [x] Security configurations created
- [x] Migration tooling completed
- [x] AWS CodeArtifact configured

### Phase 2: POC Migration (Next)
Target repositories:
- client-users (low criticality)
- lib-design-system-react (4 dependents)
- stonal-front (production)

## 🔗 Related Resources

- **Strategy Document**: [pnpm-migration-strategy-en.md](../pnpm-migration-strategy-en.md)
- **JIRA Epic**: [STN-46123](https://stonal-tech.atlassian.net/browse/STN-46123)
- **Migration Project**: `/Users/cfarkas/projects/pnpm-migration/`

## ⚠️ Security Warnings

1. **Never disable `ignore-scripts`** without explicit security review
2. **Always review lifecycle scripts** before adding to whitelist
3. **Regenerate CodeArtifact tokens** every 12 hours
4. **Audit dependencies regularly** for new vulnerabilities

## 📋 Support

For migration issues or security concerns:
1. Check existing security reports in project `/reports` directory
2. Review JIRA Epic STN-46123 for status updates
3. Consult migration strategy document for detailed procedures

---

**Epic**: STN-46123
**Owner**: Front-end Lead Dev
**Last Updated**: 2025-10-03
**Status**: 🟢 Phase 1 Complete - Ready for POC Migration