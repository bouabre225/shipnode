# Package Managers

ShipNode auto-detects npm, yarn, pnpm, or bun.

## Auto-Detection

ShipNode checks for lockfiles in this order:

| Lockfile | Package Manager |
|----------|----------------|
| `bun.lockb` or `bun.lock` | bun |
| `pnpm-lock.yaml` | pnpm |
| `yarn.lock` | yarn |
| (none) | npm |

## Override Detection

Force a specific package manager in `shipnode.conf`:

```bash
PKG_MANAGER=bun
```

Valid values: `npm`, `yarn`, `pnpm`, `bun`

## Commands Generated

ShipNode generates these commands based on detected manager:

| Action | npm | yarn | pnpm | bun |
|--------|-----|------|------|-----|
| Install | `npm install` | `yarn install` | `pnpm install` | `bun install` |
| Build | `npm run build` | `yarn build` | `pnpm run build` | `bun run build` |
| Start | `npm start` | `yarn start` | `pnpm start` | `bun start` |
| PM2 start | `pm2 start npm -- start` | `pm2 start yarn -- start` | `pm2 start pnpm -- start` | `pm2 start bun -- start` |

## Server Installation

During `shipnode setup`, detected package managers are installed:

- **npm** - Comes with Node.js (no installation needed)
- **yarn** - `npm install -g yarn`
- **pnpm** - `npm install -g pnpm`
- **bun** - `curl -fsSL https://bun.sh/install | bash`

## Workspaces

All package managers support workspaces:

```json
// package.json (npm/yarn/pnpm)
{
  "workspaces": ["packages/*"]
}
```

## CI/CD

In GitHub Actions, install before deploying:

```yaml
- name: Install dependencies
  run: npm ci  # or yarn, pnpm, bun install
```

## Lockfile in .gitignore

Make sure lockfiles are committed:

```
# Keep lockfiles
bun.lockb
pnpm-lock.yaml
yarn.lock
package-lock.json
```

This ensures consistent installs across all environments.

## Switching Package Managers

To switch package managers:

1. Remove old lockfile
2. Run new package manager install
3. Commit new lockfile
4. Deploy

ShipNode will auto-detect the new lockfile.
