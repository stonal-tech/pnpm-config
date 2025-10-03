/**
 * 🔒 Secure .pnpmfile.cjs configuration for pnpm migration
 * Epic: STN-46123
 *
 * This file provides additional security by filtering out potentially dangerous
 * lifecycle scripts from packages before they can be executed.
 *
 * Security approach:
 * 1. Whitelist approach: Only allow scripts from known safe packages
 * 2. Remove dangerous lifecycle scripts from all other packages
 * 3. Log any script removal for audit purposes
 */

const fs = require('fs');
const path = require('path');

// 🛡️ Whitelist of packages allowed to run lifecycle scripts
// Only include packages that are known to be safe and necessary
const ALLOWED_SCRIPT_PACKAGES = [
  // Build tools (essential for compilation)
  'esbuild',
  '@swc/core',
  '@swc/wasm',
  'rollup',
  'vite',

  // Native binaries (required for functionality)
  'sharp',
  'canvas',
  'node-sass',
  'sass',
  'bcrypt',
  'argon2',
  'sqlite3',
  'better-sqlite3',

  // Font processing
  'fontmin',

  // Image processing
  'imagemin',
  'mozjpeg',
  'pngquant-bin',

  // Browser automation (if needed)
  'puppeteer',
  'playwright',
  'chromedriver',

  // Development tools (generally safe)
  'husky',
  'lefthook',

  // Our organization packages (trusted)
  '@stonal-tech/*',
  '@lfn/*',
  '@stonal/*',
  '@lfn-tech/*'
];

// 🚨 Known dangerous packages to always block
const BLOCKED_PACKAGES = [
  'qix',
  'colors', // Compromised package
  'chalk', // Also had issues
  'ua-parser-js', // Had malicious versions
  'coa', // Had malicious versions
  'rc', // Had malicious versions
];

// 📝 Log file for audit trail
const LOG_FILE = path.join(__dirname, '../reports/pnpmfile-actions.log');

/**
 * Log security actions for audit purposes
 */
function logAction(action, packageName, scriptType, scriptContent) {
  const timestamp = new Date().toISOString();
  const logEntry = `${timestamp} | ${action} | ${packageName} | ${scriptType} | ${scriptContent}\n`;

  try {
    fs.appendFileSync(LOG_FILE, logEntry);
  } catch (error) {
    console.warn('Failed to write to pnpmfile log:', error.message);
  }
}

/**
 * Check if a package is allowed to run scripts
 */
function isPackageAllowed(packageName) {
  // Check blocked packages first
  if (BLOCKED_PACKAGES.includes(packageName)) {
    return false;
  }

  // Check whitelist
  return ALLOWED_SCRIPT_PACKAGES.some(pattern => {
    if (pattern.endsWith('/*')) {
      // Handle wildcard patterns for organizations
      const prefix = pattern.slice(0, -2);
      return packageName.startsWith(prefix);
    }
    return packageName === pattern;
  });
}

/**
 * Remove dangerous lifecycle scripts from package
 */
function sanitizeScripts(pkg) {
  const dangerousScripts = [
    'install',
    'postinstall',
    'preinstall',
    'prepare',
    'prepublish',
    'prepublishOnly',
    'prepack',
    'postpack'
  ];

  let modified = false;

  if (pkg.scripts) {
    dangerousScripts.forEach(scriptType => {
      if (pkg.scripts[scriptType]) {
        logAction('REMOVED_SCRIPT', pkg.name, scriptType, pkg.scripts[scriptType]);
        delete pkg.scripts[scriptType];
        modified = true;
      }
    });
  }

  return modified;
}

module.exports = {
  hooks: {
    /**
     * Main hook: Process each package before installation
     */
    readPackage(pkg, context) {
      // Skip processing for our own packages
      if (pkg.name && pkg.name.startsWith('@stonal-tech/')) {
        return pkg;
      }

      // Block dangerous packages entirely
      if (pkg.name && BLOCKED_PACKAGES.includes(pkg.name)) {
        logAction('BLOCKED_PACKAGE', pkg.name, 'ALL', 'Package entirely blocked');
        console.warn(`🚨 Blocked dangerous package: ${pkg.name}`);
        // Return empty package to effectively block it
        return {
          name: pkg.name,
          version: pkg.version,
          dependencies: {},
          devDependencies: {},
          scripts: {}
        };
      }

      // Check if package is allowed to run scripts
      if (!isPackageAllowed(pkg.name)) {
        const wasModified = sanitizeScripts(pkg);

        if (wasModified) {
          console.log(`🛡️  Sanitized scripts for: ${pkg.name}`);
        }
      } else {
        // Log allowed packages for audit
        if (pkg.scripts && Object.keys(pkg.scripts).some(key =>
          ['install', 'postinstall', 'preinstall', 'prepare'].includes(key)
        )) {
          logAction('ALLOWED_SCRIPTS', pkg.name, 'LIFECYCLE', JSON.stringify(pkg.scripts));
        }
      }

      return pkg;
    },

    /**
     * Hook called after all packages are read
     */
    afterAllResolved(lockfile, context) {
      // Log completion
      const timestamp = new Date().toISOString();
      const summary = `${timestamp} | COMPLETED | pnpm install completed with security filtering\n`;

      try {
        fs.appendFileSync(LOG_FILE, summary);
      } catch (error) {
        // Ignore logging errors
      }

      return lockfile;
    }
  }
};

/**
 * Export configuration for inspection
 */
module.exports.config = {
  allowedPackages: ALLOWED_SCRIPT_PACKAGES,
  blockedPackages: BLOCKED_PACKAGES,
  logFile: LOG_FILE
};