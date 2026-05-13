# Cloudflare Easy Mode

Cloudflare Easy Mode hides your origin IP by routing both app traffic and SSH through Cloudflare Tunnel.

```text
Users -> app.example.com -> Cloudflare -> Tunnel -> localhost app/Caddy
ShipNode -> ssh.example.com -> Cloudflare Access -> Tunnel -> localhost:22
```

Your server keeps outbound access to Cloudflare, but public inbound `22`, `80`, and `443` can be closed.

## Configuration

Add this to `shipnode.conf`:

```bash
DOMAIN=app.example.com

SSH_USER=deploy
SSH_HOST=ssh.example.com
SSH_PORT=22
SSH_PROXY_MODE=cloudflare

CLOUDFLARE_ENABLED=true
CLOUDFLARE_ZONE=example.com
CLOUDFLARE_LOCKDOWN_FIREWALL=true
CLOUDFLARE_ACCESS_EMAILS=you@example.com
```

Keep secrets outside git:

```bash
export CLOUDFLARE_API_TOKEN=...
```

For first-time setup, `ssh.example.com` may not exist yet. Use a temporary direct bootstrap host from your shell:

```bash
export SHIPNODE_BOOTSTRAP_SSH_HOST=203.0.113.10
```

Do not commit the bootstrap host.

## API Token

Use an **Account API Token** for production. Cloudflare recommends Account API Tokens for durable integrations that should not be associated with a specific user. User API tokens still work for local testing, but they are tied to the user who created them.

```text
Manage Account -> Account API Tokens -> Create Token
```

Creating an Account API Token requires Super Administrator permission on the Cloudflare account.

ShipNode needs the token to manage four Cloudflare resources:

| Resource | Why ShipNode needs it |
|----------|------------------------|
| Zone read | Find the zone ID for `CLOUDFLARE_ZONE` |
| DNS write | Create or update CNAME records for `DOMAIN` and `SSH_HOST` |
| Cloudflare Tunnel write | Create or reuse a tunnel and update ingress rules |
| Access applications/policies write | Create the SSH Access app and optional email allow policy |

Suggested token scope:

```text
Account:
  Cloudflare Tunnel: Edit
  Access: Apps and Policies: Edit

Zone:
  Zone: Read
  DNS: Edit

Resources:
  Include the account that owns your tunnel
  Include the zone matching CLOUDFLARE_ZONE
```

Cloudflare may rename permissions over time. If the dashboard uses newer names, choose the equivalent permissions for Tunnel write, Access app/policy write, Zone read, and DNS edit.

New Account API Tokens use Cloudflare's `cfat_` token prefix, which helps credential scanning tools detect leaked tokens. Keep the token in your shell, password manager, or CI secret store, not in `shipnode.conf`.

Cloudflare docs:

- [Account API Tokens](https://developers.cloudflare.com/fundamentals/api/get-started/account-owned-tokens/)
- [Create API token](https://developers.cloudflare.com/fundamentals/api/get-started/create-token/)
- [Token formats](https://developers.cloudflare.com/fundamentals/api/get-started/token-formats/)

## What `shipnode cloudflare init` Does

`shipnode cloudflare init` performs these steps:

1. Validates `DOMAIN`, `SSH_HOST`, `CLOUDFLARE_ZONE`, and Cloudflare SSH mode.
2. Looks up the Cloudflare zone and account.
3. Creates or reuses a remotely managed Cloudflare Tunnel.
4. Merges tunnel ingress without removing other apps already on the tunnel:
   - `DOMAIN -> http://localhost:$BACKEND_PORT` for backend apps.
   - `DOMAIN -> http://localhost:80` for frontend/Caddy apps.
   - `SSH_HOST -> ssh://localhost:22`.
5. Creates or updates proxied CNAME records pointing both hostnames to the tunnel target.
6. Creates or updates a Cloudflare Access SSH application for `SSH_HOST`.
7. Adds an email allow policy when `CLOUDFLARE_ACCESS_EMAILS` is set.
8. Installs and starts `cloudflared` on the server.
9. If `CLOUDFLARE_LOCKDOWN_FIREWALL=true`, removes public UFW allows for `22`, `80`, and `443`.

Firewall lockdown is skipped if no Cloudflare Access policy exists, to avoid locking you out.

## Multiple Apps On One Server

You can run multiple ShipNode apps behind the same Cloudflare Tunnel. Set the same `CLOUDFLARE_TUNNEL_NAME` in each app and give each app a different `DOMAIN`.

```bash
# app1
DOMAIN=app1.example.com
BACKEND_PORT=3001
CLOUDFLARE_TUNNEL_NAME=shipnode-server
```

```bash
# app2
DOMAIN=app2.example.com
BACKEND_PORT=3002
CLOUDFLARE_TUNNEL_NAME=shipnode-server
```

When `shipnode cloudflare init` runs, ShipNode fetches the current tunnel configuration, updates only the matching app and SSH hostnames, preserves unrelated hostname rules, and keeps the fallback rule last.

Use a shared `SSH_HOST=ssh.example.com` for the server, or unique SSH hostnames per app if you prefer separate Access applications.

## Commands

```bash
shipnode cloudflare init
```

Create/update Cloudflare resources and install `cloudflared` on the server.

```bash
shipnode cloudflare audit
```

Check for common privacy mistakes:

- Raw IP in `SSH_HOST`.
- `SSH_PROXY_MODE` not set to `cloudflare`.
- Missing local `cloudflared`.
- Remote `cloudflared` service not active.
- UFW still allowing public `22`, `80`, or `443`.

```bash
shipnode cloudflare status
```

Show resolved Cloudflare config and remote `cloudflared` service status.

## First-Time Setup

1. Configure `shipnode.conf` with `SSH_HOST=ssh.example.com`.
2. Export your Cloudflare token:

   ```bash
   export CLOUDFLARE_API_TOKEN=...
   ```

3. Export a temporary bootstrap host if the Cloudflare SSH hostname is not ready:

   ```bash
   export SHIPNODE_BOOTSTRAP_SSH_HOST=203.0.113.10
   ```

4. Run:

   ```bash
   shipnode cloudflare init
   ```

5. Install `cloudflared` locally if needed, then verify:

   ```bash
   shipnode cloudflare audit
   shipnode doctor
   ```

6. Remove the bootstrap environment variable:

   ```bash
   unset SHIPNODE_BOOTSTRAP_SSH_HOST
   ```

After this, ShipNode connects through `SSH_HOST=ssh.example.com`.

## Notes

- Do not create public `A` or `AAAA` records pointing to the server IP.
- If the origin IP was already published, rotate the server IP if strict secrecy matters.
- Keep `CLOUDFLARE_API_TOKEN`, tunnel tokens, and bootstrap hosts out of git.
- CI deployments through Cloudflare Access may require a service-token flow; local deploys use `cloudflared access ssh`.
