# Docker LAB — DBACentralRepositoryv4

LAB: two isolated **SQL Server 2022 Developer** Linux containers (repo: TCP 15433, target: TCP 15434). Both bind to 127.0.0.1, each with a separate Docker volume and SA password. Production is **Windows Authentication**, LAB uses **SQL Authentication**.

## Prerequisites

Docker Desktop (Linux containers), PowerShell 7, PowerShell SqlServer 22.x, sufficient resources for two SQL Server instances (allow at least ~4 GB combined RAM in practice).

## Start (from project root)

```powershell
pwsh ./docker/Start-Lab.ps1
pwsh ./docker/Initialize-Repository.ps1
pwsh ./docker/Test-Inventory.ps1            # read-only against source, no repository writes
pwsh ./docker/Test-Inventory.ps1 -Persist   # save inventory snapshots into v4
```

Secrets are generated on first start in `docker/.env` and excluded by `.gitignore`. `config/servers.local.json` is generated from example and also ignored. Never commit secrets.

## Check / stop / remove

```powershell
docker compose --env-file ./docker/.env -f ./docker/docker-compose.yml ps
docker compose --env-file ./docker/.env -f ./docker/docker-compose.yml logs --tail 70 repository
docker compose --env-file ./docker/.env -f ./docker/docker-compose.yml down
```

**Important:** `down` preserves volumes; `down -v` deletes LAB database files. Do not use `-v` unless deliberately resetting LAB.

## SQL authentication

Both local instances use `sa` only in this initial ephemeral LAB. A subsequent iteration should create least-privilege collector/repository users and grant only needed metadata/read/write permissions. Never use `sa` in production.

## Production

On Windows production instances, omit `SourceCredential` and use integrated auth under the approved service identity. This is not yet a production rollout recipe; FCI/AG health and permissions tests are pending.

## Source image

Official image: `mcr.microsoft.com/mssql/server:2022-latest`. Pin digest after validating a desired CU.
