# Zabbix server 8.0 LTS (official image, pinned by version and digest).
# All Zabbix state lives in PostgreSQL, so this service needs no volume.
FROM zabbix/zabbix-server-pgsql:alpine-8.0.0@sha256:27a82a0d504e63943697bdccc964e0a8270d7c0176f4f922161bd482eec5b95c

# Defaults for Railway. Every one of them can be overridden with a service variable.
ENV DB_SERVER_PORT=5432 \
    ZBX_ENABLE_SNMP_TRAPS=false

EXPOSE 10051
