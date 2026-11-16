[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/zabbix-1?utm_medium=integration&utm_source=button&utm_campaign=zabbix)

# Zabbix on Railway

A Railway template for [Zabbix](https://www.zabbix.com/) **8.0 LTS**, the open-source monitoring platform for servers, networks, applications and cloud services. It is built from the official Zabbix Docker images, pinned by version and digest.

## What it deploys

| Service | Source | Purpose |
|---|---|---|
| `zabbix-web` | [`web/`](web/) – `zabbix/zabbix-web-nginx-pgsql:alpine-8.0.0` | Web interface and API (nginx + PHP-FPM), public on port 8080 |
| `zabbix-server` | [`server/`](server/) – `zabbix/zabbix-server-pgsql:alpine-8.0.0` | Zabbix server: polling, triggers, alerts. Private network only, port 10051 |
| `Postgres` | Railway PostgreSQL | All configuration and history (on a Railway volume) |

The Zabbix server creates the database schema on its first start.

## First login

- URL: the `zabbix-web` service's public domain.
- User: `Admin`
- Password: the `ZBX_ADMIN_PASSWORD` variable of the `zabbix-web` service (generated at deploy time).

There is no default password. On a fresh install, `web/railway-start.sh` signs in once with the factory password and replaces it with `ZBX_ADMIN_PASSWORD` through the Zabbix API. The health check path `/healthz` answers 200 only after that, so Railway never routes traffic to a frontend that still accepts `Admin` / `zabbix`. If you later change the Admin password inside Zabbix, the wrapper leaves it alone.

On the same first boot, the wrapper unlinks the "Linux by Zabbix agent" template from the built-in "Zabbix server" host: no agent runs next to the server here, so that template would only raise an "agent is not available" problem. The host keeps its "Zabbix server health" template, which uses internal checks.

## Variables

| Service | Variable | Value | Notes |
|---|---|---|---|
| zabbix-web | `ZBX_ADMIN_PASSWORD` | `${{secret(24,…)}}` | Admin password set on first boot |
| zabbix-web | `PORT` | `8080` | Port nginx listens on (for Railway's health check and domain) |
| zabbix-web | `ZBX_SERVER_HOST` | `${{zabbix-server.RAILWAY_PRIVATE_DOMAIN}}` | Where the frontend reaches the server |
| both | `DB_SERVER_HOST`, `DB_SERVER_PORT`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` | references to `Postgres` | Database connection |

Baked-in defaults you can override with a service variable: `PHP_TZ=UTC` and `ZBX_SERVER_NAME=Zabbix` (web), `ZBX_ENABLE_SNMP_TRAPS=false` (server). Any other setting from the [official image docs](https://www.zabbix.com/documentation/8.0/en/manual/installation/containers) (for example `ZBX_CACHESIZE`, `ZBX_STARTPOLLERS`) works the same way.

## Monitoring hosts

- **Agents that connect in (active checks):** add a TCP proxy to `zabbix-server` on port 10051 and point the agent's `ServerActive` at the proxy's host and port.
- **Agents, SNMP or HTTP checks that the server polls:** the server reaches anything on the public internet, and other Railway services in the same project over the private network.

## Updates

Railway notifies everyone who deployed this template when a change is merged to `main` of this repo, and each deployer chooses when to apply it. Read [CHANGELOG.md](CHANGELOG.md) before applying. Zabbix upgrades its database schema on the server's first start after an upgrade. Back up the Postgres volume before a major upgrade.

## Local test

```sh
docker build -t zbx-server server && docker build -t zbx-web web
```

Run them with a PostgreSQL 15–18 database and the variables above.
