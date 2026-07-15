# Twenty CRM — production deployment (agent runbook)

This document is the single source of truth for deploying this fork to production.
Read it fully before changing VPS, DNS, or compose files.

## Architecture summary

| Component | Where it runs |
| --------- | ------------- |
| **App image** | `ghcr.io/lakshit77/twenty-crm:latest` (built by GitHub Actions) |
| **Postgres** | Supabase (external, `PG_DATABASE_URL`) |
| **Files** | Cloudflare R2 (`STORAGE_TYPE=S_3`, `STORAGE_S3_*`) |
| **Redis** | Container on VPS (`REDIS_URL=redis://redis:6379`) |
| **HTTPS / 80–443** | **Traefik** bundled in `docker-compose.prod.standalone.yml` on the dedicated VPS |
| **n8n** | Separate VPS (`194.238.18.193`, `/root`) — not co-located with Twenty |

**Do not clone the full monorepo on the VPS.** Copy `docker-compose.prod.standalone.yml` and `.env` to `~/twenty-crm/`.

Public URL: **https://crm.lakshitukani.com**

---

## Fixed infrastructure values

| Item | Value |
| ---- | ----- |
| GitHub repo | `lakshit77/twenty-crm` |
| GHCR image | `ghcr.io/lakshit77/twenty-crm:latest` |
| VPS SSH | `root@89.116.20.227` (hostname `srv1511866.hstgr.cloud`, Mumbai) |
| VPS deploy path | `~/twenty-crm/` |
| DNS | GoDaddy A record: `crm` → `89.116.20.227` |
| Compose file | `docker-compose.prod.standalone.yml` (Traefik + app on one stack) |
| Local SSH key (gitignored) | `twenty-crm/new.ssh/id_ed25519` |
| n8n VPS (unchanged) | `root@194.238.18.193` (`srv894857.hstgr.cloud`) — key: `.ssh/id_ed25519` |

---

## User guide — connect with SSH

### Option A — Terminal on your Mac (recommended)

1. Open **Terminal** (or iTerm).
2. Run:

```bash
ssh -i /Users/lakshitukani/Lakshit/coding/twenty-crm/new.ssh/id_ed25519 root@89.116.20.227
```

3. First connection: type `yes` if asked to trust the host.
4. You should see a prompt like `root@srv1511866:~#` — you are on the VPS.

**Tip:** Add this to `~/.ssh/config` on your Mac for a short alias:

```
Host twenty-vps
  HostName 89.116.20.227
  User root
  IdentityFile /Users/lakshitukani/Lakshit/coding/twenty-crm/new.ssh/id_ed25519
```

Then connect with:

```bash
ssh twenty-vps
```

### Option B — Hostinger panel (browser terminal)

1. Log in to **Hostinger** → **VPS** → your server (`srv1511866`, Mumbai).
2. Open **Browser terminal** / **SSH terminal** in the panel.
3. You are already logged in as `root` — no key file needed on your Mac.

### If SSH fails

| Error | Fix |
| ----- | --- |
| `Permission denied (publickey)` | In Hostinger → VPS → **SSH keys**, add `new.ssh/id_ed25519.pub` |
| `Connection timed out` | Check VPS is running; confirm IP is still `89.116.20.227` in the panel |
| `No such file` for key | Use the full path to `id_ed25519` as in the command above |

---

## User guide — commands on the VPS

After SSH, you are usually in `/root`. All Twenty production commands run from **`~/twenty-crm`**.

### Go to the project folder (every time)

```bash
cd ~/twenty-crm
```

### Shorthand (optional, paste once per SSH session)

```bash
alias tcrm='docker compose -f docker-compose.prod.standalone.yml'
```

After that you can use `tcrm` instead of the long `docker compose -f ...` command.

---

### Commands you will use most often

| What you want | Command (without alias) | With `tcrm` alias |
| ------------- | ------------------------ | ------------------ |
| **See if containers are running** | `docker compose -f docker-compose.prod.standalone.yml ps` | `tcrm ps` |
| **Pull latest image from GHCR** (after GitHub build) | `docker compose -f docker-compose.prod.standalone.yml pull` | `tcrm pull` |
| **Start / apply updates** | `docker compose -f docker-compose.prod.standalone.yml up -d` | `tcrm up -d` |
| **Pull + restart** (typical deploy) | `docker compose -f docker-compose.prod.standalone.yml pull && docker compose -f docker-compose.prod.standalone.yml up -d` | `tcrm pull && tcrm up -d` |
| **Stop Twenty** | `docker compose -f docker-compose.prod.standalone.yml down` | `tcrm down` |
| **Restart Twenty** | `docker compose -f docker-compose.prod.standalone.yml restart` | `tcrm restart` |
| **Restart only the API** | `docker compose -f docker-compose.prod.standalone.yml restart server` | `tcrm restart server` |
| **Restart only the worker** | `docker compose -f docker-compose.prod.standalone.yml restart worker` | `tcrm restart worker` |
| **Follow server logs** (Ctrl+C to exit) | `docker compose -f docker-compose.prod.standalone.yml logs -f server` | `tcrm logs -f server` |
| **Follow worker logs** | `docker compose -f docker-compose.prod.standalone.yml logs -f worker` | `tcrm logs -f worker` |
| **Last 100 log lines (server)** | `docker compose -f docker-compose.prod.standalone.yml logs --tail=100 server` | `tcrm logs --tail=100 server` |

### Edit environment variables on the VPS

```bash
cd ~/twenty-crm
nano .env
# save: Ctrl+O, Enter, then Ctrl+X
docker compose -f docker-compose.prod.standalone.yml up -d
```

After changing `.env`, always run `up -d` again so containers pick up new values.

### HTTPS / certificate issues

Traefik runs as `twenty-crm-traefik-1` in the same compose stack:

```bash
docker restart twenty-crm-traefik-1
docker logs twenty-crm-traefik-1 --tail=50
```

### Check disk and memory

```bash
df -h
free -h
docker stats --no-stream
```

### List all Docker containers on the VPS

```bash
docker ps
```

Expected: `twenty-crm-traefik-1`, `twenty-crm-server-1`, `twenty-crm-worker-1`, `twenty-crm-redis-1`.

### Open the app in your browser

**https://crm.lakshitukani.com** — no port number needed.

### One-shot copy-paste — full update after a new GHCR build

```bash
cd ~/twenty-crm
docker compose -f docker-compose.prod.standalone.yml pull
docker compose -f docker-compose.prod.standalone.yml up -d
docker compose -f docker-compose.prod.standalone.yml ps
docker compose -f docker-compose.prod.standalone.yml logs --tail=30 server
```

---

### Run a single command from your Mac without staying logged in

You do not have to open an interactive SSH session. From your Mac:

```bash
ssh -i /Users/lakshitukani/Lakshit/coding/twenty-crm/new.ssh/id_ed25519 root@89.116.20.227 \
  "cd ~/twenty-crm && docker compose -f docker-compose.prod.standalone.yml pull && docker compose -f docker-compose.prod.standalone.yml up -d"
```

---

## Agent runbook — initial setup and automation

The sections below are for **first-time setup** or **agents** running deploy steps from a developer machine.

---

## Secrets and git safety

- **Never commit** `packages/twenty-docker/.env` (gitignored via `**/**/.env`).
- Template only: [`.env.production.example`](.env.production.example).
- Copy production values from the developer machine’s local `.env`; set `SERVER_URL=https://crm.lakshitukani.com`.
- **Never rotate `ENCRYPTION_KEY`** after the Supabase DB has data unless following the key-rotation guide.
- Supabase URL: no `?sslmode=require`; use `PG_SSL_ALLOW_SELF_SIGNED=true` for the session pooler.

---

## Phase 1 — Build and publish image (GHCR)

### Automated (preferred)

Workflow: [`.github/workflows/publish-ghcr.yaml`](../../.github/workflows/publish-ghcr.yaml)

- Triggers: push to `main` (app paths) or **workflow_dispatch**.
- First build: ~15–90 minutes.
- Package must be **public** on GitHub Packages (`twenty-crm`) for passwordless VPS pull.

### Manual (if Actions unavailable)

```bash
cd /path/to/twenty-crm
docker build --target twenty -f packages/twenty-docker/twenty/Dockerfile \
  -t ghcr.io/lakshit77/twenty-crm:latest .
docker login ghcr.io -u lakshit77
docker push ghcr.io/lakshit77/twenty-crm:latest
```

### Verify action SHAs

If the workflow fails at “Set up job” with “unable to find version”, pin SHAs from the tag’s commit on GitHub API — do not guess SHAs.

---

## Phase 2 — DNS (GoDaddy)

| Type | Name | Value |
| ---- | ---- | ----- |
| A | `crm` | `89.116.20.227` |

Verify:

```bash
dig +short crm.lakshitukani.com
# must return 89.116.20.227
```

Traefik will request Let’s Encrypt only after DNS resolves.

---

## Phase 3 — VPS prerequisites

Hostinger KVM (2 CPU, 8 GB RAM) with Ubuntu 24.04 + Docker is sufficient for low traffic alongside n8n.

```bash
# From developer machine
export SSH_KEY="/path/to/twenty-crm/new.ssh/id_ed25519"
export VPS="root@89.116.20.227"

ssh -i "$SSH_KEY" $VPS "docker compose version"
```

If Docker missing:

```bash
ssh -i "$SSH_KEY" $VPS "curl -fsSL https://get.docker.com | sh"
```

Firewall (if ufw enabled):

```bash
ssh -i "$SSH_KEY" $VPS "ufw allow 22 && ufw allow 80 && ufw allow 443"
```

GHCR login on VPS only if the package is **private**:

```bash
ssh -i "$SSH_KEY" $VPS "docker login ghcr.io -u lakshit77"
```

---

## Phase 4 — Deploy files to VPS

Only two files are required in `~/twenty-crm/`:

1. `docker-compose.prod.standalone.yml`
2. `.env` (production secrets)

```bash
export SSH_KEY="/path/to/twenty-crm/new.ssh/id_ed25519"
export VPS="root@89.116.20.227"
DOCKER_DIR="/path/to/twenty-crm/packages/twenty-docker"

ssh -i "$SSH_KEY" $VPS "mkdir -p ~/twenty-crm && chmod 700 ~/twenty-crm"

scp -i "$SSH_KEY" \
  "$DOCKER_DIR/docker-compose.prod.standalone.yml" \
  "$DOCKER_DIR/.env" \
  "$VPS:~/twenty-crm/"

ssh -i "$SSH_KEY" $VPS "sed -i 's|^SERVER_URL=.*|SERVER_URL=https://crm.lakshitukani.com|' ~/twenty-crm/.env && chmod 600 ~/twenty-crm/.env"
```

Remove obsolete files on VPS if present from earlier attempts:

```bash
ssh -i "$SSH_KEY" $VPS "rm -f ~/twenty-crm/Caddyfile ~/twenty-crm/docker-compose.prod.traefik.yml"
```

---

## Phase 5 — Start the stack

```bash
ssh -i "$SSH_KEY" $VPS "cd ~/twenty-crm && docker compose -f docker-compose.prod.standalone.yml pull"
ssh -i "$SSH_KEY" $VPS "cd ~/twenty-crm && docker compose -f docker-compose.prod.standalone.yml up -d"
ssh -i "$SSH_KEY" $VPS "cd ~/twenty-crm && docker compose -f docker-compose.prod.standalone.yml ps"
```

Wait until `server` is **healthy** (~3–10 min first run; runs DB upgrade against Supabase):

```bash
ssh -i "$SSH_KEY" $VPS "cd ~/twenty-crm && docker compose -f docker-compose.prod.standalone.yml logs -f server"
```

Expected containers: `twenty-crm-traefik-1`, `twenty-crm-server-1`, `twenty-crm-worker-1`, `twenty-crm-redis-1`.

---

## Phase 6 — Traefik and HTTPS

Traefik is bundled in `docker-compose.prod.standalone.yml` as `twenty-crm-traefik-1`. It binds ports 80 and 443 and discovers the `server` container via Docker labels on the same compose network.

Set `SSL_EMAIL` in `~/twenty-crm/.env` for Let's Encrypt (TLS-ALPN challenge).

If HTTPS fails shortly after DNS goes live:

```bash
ssh -i "$SSH_KEY" $VPS "docker restart twenty-crm-traefik-1"
# wait 30–60s, then test
curl -I https://crm.lakshitukani.com
```

Common Traefik log errors:

- **NXDOMAIN** — DNS not propagated yet; wait and restart Traefik.
- **certificate resolver letsencrypt** — labels must use `mytlschallenge` (already set in standalone compose).

### Changing the public hostname

1. Update GoDaddy DNS.
2. Change `Host(\`...\`)` label in `docker-compose.prod.standalone.yml`.
3. Update `SERVER_URL` in VPS `.env`.
4. `docker compose -f docker-compose.prod.standalone.yml up -d`.

---

## Phase 7 — Verification

1. Open **https://crm.lakshitukani.com**
2. Log in (same Supabase data as local if same `ENCRYPTION_KEY` + `PG_DATABASE_URL`).
3. Upload a file.

**R2 CORS** (if uploads fail): Cloudflare R2 bucket → CORS → allow origin `https://crm.lakshitukani.com`.

---

## Phase 8 — Release updates

After a new image is pushed to GHCR, use the **User guide — commands on the VPS** section (`pull` + `up -d`), or from your Mac:

```bash
ssh -i "$SSH_KEY" $VPS "cd ~/twenty-crm && docker compose -f docker-compose.prod.standalone.yml pull && docker compose -f docker-compose.prod.standalone.yml up -d"
```

---

## Optional cleanup — n8n VPS (`194.238.18.193`)

Twenty CRM no longer runs on the n8n VPS. Only `root-n8n-1` and `root-traefik-1` should remain there.

### Old Hostinger Twenty stack (`twenty-dfxy-*`)

If an older compose project still runs as `twenty-dfxy-*` on the n8n VPS, stop and remove it to free RAM:

```bash
export SSH_KEY="/path/to/twenty-crm/.ssh/id_ed25519"
export VPS="root@194.238.18.193"
ssh -i "$SSH_KEY" $VPS "
  docker stop twenty-dfxy-twenty-1 twenty-dfxy-twenty-worker-1 twenty-dfxy-twenty-redis-1 twenty-dfxy-twenty-db-1 2>/dev/null
  docker rm twenty-dfxy-twenty-1 twenty-dfxy-twenty-worker-1 twenty-dfxy-twenty-redis-1 twenty-dfxy-twenty-db-1 2>/dev/null
"
```

---

## Local development vs production

| | Local | Production VPS |
| - | ----- | ---------------- |
| Compose file | `docker-compose.yml` | `docker-compose.prod.standalone.yml` |
| Image | `twentycrm/twenty` or local build | `ghcr.io/lakshit77/twenty-crm` |
| `SERVER_URL` | `http://localhost:3000` | `https://crm.lakshitukani.com` |
| Reverse proxy | None (port 3000) | Traefik (bundled in standalone compose) |
| Env file | `packages/twenty-docker/.env` | `~/twenty-crm/.env` on VPS |

---

## Troubleshooting

| Symptom | Check |
| ------- | ----- |
| `Permission denied (publickey)` | Add `new.ssh/id_ed25519.pub` to Hostinger SSH keys; use correct `SSH_KEY` path |
| Pull 401 / denied | GHCR package visibility or `docker login` on VPS |
| Server unhealthy | `docker compose logs server` — Supabase URL, SSL flag, `ENCRYPTION_KEY` |
| **504** on `https://crm...` | Check `twenty-crm-server-1` is healthy; restart Traefik: `docker restart twenty-crm-traefik-1` |
| HTTPS certificate error | DNS points to `89.116.20.227` + `docker restart twenty-crm-traefik-1` |
| Port 80/443 bind error | Another process on the VPS is using those ports — stop it before starting Twenty |
| Upload 403 | R2 CORS for production origin |
| Wrong app version | `docker compose pull` then `up -d` |

---

## File map (this package)

| File | Purpose |
| ---- | ------- |
| `docker-compose.prod.standalone.yml` | Dedicated VPS stack (Traefik + app + Redis) |
| `docker-compose.prod.yml` | Legacy shared-VPS stack (external Traefik on n8n host) |
| `docker-compose.yml` | Local Hub image + port 3000 |
| `.env.production.example` | VPS `.env` template (no secrets) |
| `.env` | Local secrets (gitignored) |
| `DEPLOY.md` | This runbook |
| `twenty/Dockerfile` | Image build definition |
| `../../.github/workflows/publish-ghcr.yaml` | CI publish to GHCR |

**Removed (do not recreate on dedicated VPS):** Caddy, content-backend stacks — incompatible with Twenty's Traefik on 80/443.
