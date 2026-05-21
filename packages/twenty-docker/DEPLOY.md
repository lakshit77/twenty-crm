# Production deploy (Hostinger VPS + GoDaddy DNS + GHCR)

Public URL: **https://crm.lakshitukani.com**

Image: `ghcr.io/lakshit77/twenty-crm:latest`

## 1. Publish image (GitHub)

Push to `main` (paths that touch app code) runs [.github/workflows/publish-ghcr.yaml](../../.github/workflows/publish-ghcr.yaml), or run **Actions → Publish Twenty image to GHCR → Run workflow**.

First time: GitHub → **Packages** → `twenty-crm` → **Package settings** → set visibility to **Public** (simplest for VPS pull without login).

Manual build from laptop:

```bash
cd /path/to/twenty-crm
docker build --target twenty -f packages/twenty-docker/twenty/Dockerfile \
  -t ghcr.io/lakshit77/twenty-crm:latest .
echo YOUR_GITHUB_PAT | docker login ghcr.io -u lakshit77 --password-stdin
docker push ghcr.io/lakshit77/twenty-crm:latest
```

## 2. GoDaddy DNS

| Type | Name | Value        |
| ---- | ---- | ------------ |
| A    | crm  | VPS public IP |

Wait until `dig crm.lakshitukani.com` returns that IP.

## 3. VPS files (small folder only)

On the VPS, create `~/twenty-crm/` with only:

- `docker-compose.prod.yml`
- `Caddyfile`
- `.env` (from `.env.production.example`, filled with real secrets)

Copy from laptop:

```bash
scp packages/twenty-docker/docker-compose.prod.yml \
    packages/twenty-docker/Caddyfile \
    packages/twenty-docker/.env.production.example \
    user@YOUR_VPS_IP:~/twenty-crm/
# On VPS: cp .env.production.example .env && nano .env
```

## 4. VPS setup commands

```bash
# Docker
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
# log out and back in

# Firewall
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw enable

# GHCR (skip if package is public)
echo YOUR_GITHUB_PAT | docker login ghcr.io -u lakshit77 --password-stdin

cd ~/twenty-crm
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
docker compose -f docker-compose.prod.yml ps
docker compose -f docker-compose.prod.yml logs -f server
```

Open https://crm.lakshitukani.com

## 5. Updates

After a new image is pushed:

```bash
cd ~/twenty-crm
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
```

## 6. R2 CORS (if uploads fail)

In Cloudflare R2 bucket CORS, allow origin `https://crm.lakshitukani.com`.
