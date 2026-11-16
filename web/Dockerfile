# Zabbix web interface 8.0 LTS (official nginx + PHP-FPM image, pinned by version and digest).
FROM zabbix/zabbix-web-nginx-pgsql:alpine-8.0.0@sha256:ed54de937d313cabb653464d0b5356c03a325ab44ee67a1784e881962382b113

USER root
# /healthz answers 200 only after the first-boot setup has replaced the default
# Admin password, so Railway never routes traffic to a frontend with Admin/zabbix.
RUN printf '\nlocation = /healthz {\n    access_log off;\n    default_type text/plain;\n    alias /tmp/zbx-ready;\n}\n' >> /etc/nginx/includes/server-common.conf
COPY --chmod=755 railway-start.sh /usr/local/bin/railway-start.sh
USER 1997

# ZBX_SERVER_PORT must be set too: the frontend only uses ZBX_SERVER_HOST when both
# are set, otherwise it falls back to the server's NodeAddress (localhost:10051).
ENV PHP_TZ=UTC \
    ZBX_SERVER_NAME=Zabbix \
    ZBX_SERVER_PORT=10051 \
    DB_SERVER_PORT=5432

EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/railway-start.sh"]
