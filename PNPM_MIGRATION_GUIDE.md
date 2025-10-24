# Migration from Yarn to pnpm - Complete Guide

## ✅ What Has Been Updated

All necessary files have been updated to use pnpm instead of Yarn:

### Configuration Files

- ✅ Created `pnpm-workspace.yaml` (defines workspace structure)
- ✅ Updated `package.json` (root - all scripts converted to pnpm)
- ✅ Updated `packages/nextjs/package.json` (removed Yarn-specific build flags)
- ✅ Updated `packages/nextjs/Dockerfile` (pnpm installation and build)
- ✅ Updated `packages/nextjs/vercel.json` (pnpm install command)

### Documentation Files

- ✅ Updated `README.md` (all commands and requirements)
- ✅ Updated `AGENTS.md` (all development commands)

## 🚀 Migration Steps

### 1. Install pnpm Globally

```bash
npm install -g pnpm
```

Or use corepack (recommended):

```bash
corepack enable
corepack prepare pnpm@9.0.0 --activate
```

### 2. Remove Yarn Files

```bash
rm -rf node_modules
rm -rf packages/*/node_modules
rm yarn.lock
rm .yarnrc.yml
```

### 3. Install Dependencies with pnpm

```bash
pnpm install
```

This will:

- Create a new `pnpm-lock.yaml` file
- Install all dependencies using pnpm's efficient symlink strategy
- Respect the workspace structure defined in `pnpm-workspace.yaml`

### 4. Verify the Installation

Check that everything works:

```bash
# Check pnpm version
pnpm --version

# List workspaces
pnpm -r list --depth 0

# Verify scripts work
pnpm compile
pnpm next:check-types
```

## 📋 Key Command Changes

### Workspace Commands

| Yarn                                  | pnpm                                 |
| ------------------------------------- | ------------------------------------ |
| `yarn workspace @se-2/foundry deploy` | `pnpm --filter @se-2/foundry deploy` |
| `yarn workspace @se-2/nextjs build`   | `pnpm --filter @se-2/nextjs build`   |

### Common Commands

| Yarn                    | pnpm                    |
| ----------------------- | ----------------------- |
| `yarn install`          | `pnpm install`          |
| `yarn add <package>`    | `pnpm add <package>`    |
| `yarn remove <package>` | `pnpm remove <package>` |
| `yarn`                  | `pnpm install`          |
| `yarn <script>`         | `pnpm <script>`         |

### Development Workflow

All your familiar commands now use pnpm:

```bash
# Start local blockchain
pnpm fork

# Deploy contracts
pnpm deploy

# Start frontend
pnpm start

# Run tests
pnpm test

# Type checking
pnpm next:check-types

# Format code
pnpm format
```

## 🎯 Workspace Filter Syntax

pnpm uses `--filter` (or `-F`) for workspace operations:

```bash
# Run command in specific workspace
pnpm --filter @se-2/foundry test
pnpm -F @se-2/nextjs build

# Run command in all workspaces
pnpm -r test  # recursive

# Run command in all workspaces in parallel
pnpm -r --parallel build
```

## 🔧 Advanced Features

### Faster Install with Store

pnpm uses a content-addressable store for all dependencies:

- Dependencies are stored once globally
- Projects use hardlinks/symlinks
- Much faster installs
- Saves disk space

### Strict Node Modules

pnpm creates a strict `node_modules` structure:

- Only direct dependencies are accessible
- Prevents phantom dependencies (dependencies you don't declare)
- More reliable builds

### Filtering Options

```bash
# Filter by package name pattern
pnpm --filter "./packages/*" build

# Filter changed packages (with git)
pnpm --filter "...[origin/main]" test
```

## ⚙️ Configuration Files

### pnpm-workspace.yaml

```yaml
packages:
  - "packages/*"
```

This file replaces the `workspaces` field in `package.json`.

### package.json (root)

```json
{
  "packageManager": "pnpm@9.0.0",
  "scripts": {
    "deploy": "pnpm foundry:deploy",
    "foundry:deploy": "pnpm --filter @se-2/foundry deploy"
  }
}
```

## 🐛 Troubleshooting

### Issue: Command not found

**Solution:** Make sure pnpm is installed globally:

```bash
npm install -g pnpm
# or
corepack enable && corepack prepare pnpm@9.0.0 --activate
```

### Issue: Workspace not found

**Solution:** Check that workspace names match in `package.json` files:

- `@se-2/foundry` in `packages/foundry/package.json`
- `@se-2/nextjs` in `packages/nextjs/package.json`

### Issue: Dependencies not resolving

**Solution:** Clear cache and reinstall:

```bash
pnpm store prune
rm -rf node_modules packages/*/node_modules
pnpm install
```

### Issue: postinstall scripts failing

**Solution:** Make sure `.env.example` files exist in workspaces that need them:

```bash
touch packages/foundry/.env.example
```

## 📦 Benefits of pnpm

1. **Faster:** Up to 2x faster than npm/yarn
2. **Efficient:** Content-addressable storage saves disk space
3. **Strict:** Prevents phantom dependencies
4. **Compatible:** Works with existing Node.js ecosystem
5. **Monorepo-friendly:** Built-in workspace support

## 🔄 Rollback (if needed)

If you need to roll back to Yarn:

```bash
# Remove pnpm files
rm -rf node_modules packages/*/node_modules
rm pnpm-lock.yaml

# Reinstall with Yarn
yarn install
```

Then revert the updated files using git:

```bash
git checkout package.json packages/nextjs/package.json packages/nextjs/Dockerfile
```

## 📚 Additional Resources

- [pnpm Documentation](https://pnpm.io/)
- [pnpm Workspace Guide](https://pnpm.io/workspaces)
- [pnpm CLI Reference](https://pnpm.io/cli/install)
- [Filtering Packages](https://pnpm.io/filtering)

## ✨ Next Steps

After successful migration:

1. Update your CI/CD pipelines to use pnpm
2. Update any deployment scripts
3. Inform team members about the migration
4. Consider adding `.npmrc` for project-specific pnpm settings
5. Delete this guide file if you no longer need it

## 🎉 You're Done!

Your project is now using pnpm! All commands have been updated, and you can continue development with faster installs and a more reliable dependency management system.
