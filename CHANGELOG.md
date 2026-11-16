# Changelog

## 8.0.0-2 (2026-11-16)

- README: add the Deploy on Railway button for the published template `zabbix-1`. No change to the services.

## 8.0.0-1 (2026-11-16)

First release of the template.

- Zabbix server and web interface 8.0.0 LTS (`alpine-8.0.0`), pinned by digest:
  - `zabbix/zabbix-server-pgsql@sha256:27a82a0d504e63943697bdccc964e0a8270d7c0176f4f922161bd482eec5b95c`
  - `zabbix/zabbix-web-nginx-pgsql@sha256:ed54de937d313cabb653464d0b5356c03a325ab44ee67a1784e881962382b113`
- Railway PostgreSQL for all data.
- No default password: the first boot replaces `Admin` / `zabbix` with `ZBX_ADMIN_PASSWORD`, and `/healthz` stays unhealthy until it has.
- The built-in "Zabbix server" host monitors itself with internal checks only ("Linux by Zabbix agent" is unlinked on first boot).
