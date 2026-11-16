#!/bin/sh
# Railway wrapper for the official Zabbix web image.
# 1. Starts the image's own entrypoint (nginx + PHP-FPM).
# 2. On a fresh install, replaces the default Admin/zabbix password with
#    ZBX_ADMIN_PASSWORD through the Zabbix API, and unlinks the
#    "Linux by Zabbix agent" template from the built-in "Zabbix server" host
#    (this template has no agent to talk to), so the first dashboard isn't red.
# 3. Only then creates /tmp/zbx-ready, which makes /healthz answer 200.
set -u

READY=/tmp/zbx-ready
API=http://127.0.0.1:8080/api_jsonrpc.php
rm -f "$READY"

/usr/bin/docker-entrypoint "$@" &
APP=$!
trap 'kill -TERM "$APP" 2>/dev/null' TERM INT

log() { echo "[railway-start] $*"; }

# Escape a string for use inside a JSON string.
json_esc() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

# POST the JSON body on stdin to the API. $1 = optional bearer token.
api() {
  if [ -n "${1:-}" ]; then
    curl -s -m 30 -H 'Content-Type: application/json-rpc' -H "Authorization: Bearer $1" --data-binary @- "$API"
  else
    curl -s -m 30 -H 'Content-Type: application/json-rpc' --data-binary @- "$API"
  fi
}

result_str() { sed -n 's/.*"result":"\([^"]*\)".*/\1/p'; }
first_id() { sed -n "s/.*\"$1\":\"\([0-9]*\)\".*/\1/p" | head -n 1; }

login() {
  printf '{"jsonrpc":"2.0","method":"user.login","params":{"username":"Admin","password":"%s"},"id":1}' "$(json_esc "$1")" | api
}

fresh_install_setup() {
  tok=$1
  # Unlink the agent template from the built-in host (best effort).
  tid=$(printf '{"jsonrpc":"2.0","method":"template.get","params":{"output":["templateid"],"filter":{"host":["Linux by Zabbix agent"]}},"id":2}' | api "$tok" | first_id templateid)
  hid=$(printf '{"jsonrpc":"2.0","method":"host.get","params":{"output":["hostid"],"filter":{"host":["Zabbix server"]}},"id":3}' | api "$tok" | first_id hostid)
  if [ -n "$tid" ] && [ -n "$hid" ]; then
    if printf '{"jsonrpc":"2.0","method":"host.update","params":{"hostid":"%s","templates_clear":[{"templateid":"%s"}]},"id":4}' "$hid" "$tid" | api "$tok" | grep -q '"result"'; then
      log "unlinked 'Linux by Zabbix agent' from host 'Zabbix server'"
    else
      log "could not unlink the agent template (not fatal)"
    fi
  fi
  uid=$(printf '{"jsonrpc":"2.0","method":"user.get","params":{"output":["userid"],"filter":{"username":["Admin"]}},"id":5}' | api "$tok" | first_id userid)
  [ -n "$uid" ] || return 1
  printf '{"jsonrpc":"2.0","method":"user.update","params":{"userid":"%s","current_passwd":"zabbix","passwd":"%s"},"id":6}' \
    "$uid" "$(json_esc "$ZBX_ADMIN_PASSWORD")" | api "$tok" | grep -q '"result"'
}

setup() {
  NEW=${ZBX_ADMIN_PASSWORD:-}
  if [ -z "$NEW" ]; then
    log "ERROR: ZBX_ADMIN_PASSWORD is empty. Set it so the default Admin password can be replaced."
  fi
  while kill -0 "$APP" 2>/dev/null; do
    if [ -n "$NEW" ] && [ -n "$(login "$NEW" | result_str)" ]; then
      log "Admin password is set; ready"
      return 0
    fi
    r=$(login zabbix)
    tok=$(printf '%s' "$r" | result_str)
    if [ -n "$tok" ]; then
      if [ -z "$NEW" ]; then
        log "default Admin password is still active and ZBX_ADMIN_PASSWORD is empty: staying unhealthy"
      elif fresh_install_setup "$tok" && [ -n "$(login "$NEW" | result_str)" ]; then
        log "fresh install: Admin password replaced with ZBX_ADMIN_PASSWORD; ready"
        return 0
      else
        log "could not change the Admin password yet; retrying"
      fi
    elif printf '%s' "$r" | grep -q 'Incorrect user name or password'; then
      log "Admin password was changed in Zabbix (not ZBX_ADMIN_PASSWORD); leaving it; ready"
      return 0
    fi
    sleep 5
  done
  return 1
}

if setup; then
  echo ok > "$READY"
fi

wait "$APP"
code=$?
# wait returns early when a trapped signal arrives; wait again for the real exit.
if kill -0 "$APP" 2>/dev/null; then wait "$APP"; code=$?; fi
exit "$code"
