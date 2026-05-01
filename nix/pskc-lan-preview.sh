#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Build and serve the generated PSKC Astro site over the local network with nginx.

Usage:
  pskc-lan-preview
  pskc-lan-preview --daemon
  pskc-lan-preview --status
  pskc-lan-preview --stop

Environment:
  PSKC_HOST=0.0.0.0   Address nginx listens on.
  PSKC_PORT=8080      Port nginx listens on. Use a non-root port.
  PSKC_BUILD=1        Build before serving. Set to 0 to serve existing dist/.
  PSKC_SITE_ROOT=$PWD Site root. Defaults to the current directory.

Examples:
  pskc-lan-preview
  pskc-lan-preview --daemon
  pskc-lan-preview --status
  pskc-lan-preview --stop
  PSKC_PORT=8081 pskc-lan-preview
  PSKC_BUILD=0 pskc-lan-preview
USAGE
}

mode="foreground"
case "${1:-}" in
  "")
    mode="foreground"
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  --daemon | --start | start)
    mode="daemon"
    ;;
  --foreground | serve)
    mode="foreground"
    ;;
  --status | status)
    mode="status"
    ;;
  --stop | stop)
    mode="stop"
    ;;
  *)
    echo "error: unknown argument: $1" >&2
    usage >&2
    exit 2
    ;;
esac

site_root="$(cd "${PSKC_SITE_ROOT:-$PWD}" && pwd)"
host="${PSKC_HOST:-0.0.0.0}"
port="${PSKC_PORT:-8080}"
build="${PSKC_BUILD:-1}"
dist_dir="$site_root/dist"

if [[ ! -f "$site_root/package.json" || ! -f "$site_root/astro.config.mjs" ]]; then
  echo "error: $site_root does not look like the PSKC Astro site root" >&2
  echo "       cd into ~/projects/hta/pskc-site or set PSKC_SITE_ROOT." >&2
  exit 1
fi

if [[ "$port" =~ [^0-9] || "$port" -lt 1024 || "$port" -gt 65535 ]]; then
  echo "error: PSKC_PORT must be a number between 1024 and 65535" >&2
  exit 1
fi

runtime_base="${PSKC_RUNTIME_DIR:-${XDG_RUNTIME_DIR:-}}"
if [[ -z "$runtime_base" || ! -d "$runtime_base" || ! -w "$runtime_base" ]]; then
  runtime_base="${TMPDIR:-/tmp}"
fi
runtime_dir="$runtime_base/pskc-site-nginx-$port"
conf_file="$runtime_dir/nginx.conf"
pid_file="$runtime_dir/nginx.pid"

running_pid() {
  local pid

  if [[ ! -f "$pid_file" ]]; then
    return 1
  fi

  pid="$(cat "$pid_file" 2>/dev/null || true)"
  if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
    echo "$pid"
    return 0
  fi

  return 1
}

print_urls() {
  echo "  Local:  http://127.0.0.1:$port/"

  if [[ "$host" != "0.0.0.0" && "$host" != "127.0.0.1" ]]; then
    echo "  Host:   http://$host:$port/"
  fi

  if command -v ip >/dev/null 2>&1; then
    addresses="$(
      ip -o -4 addr show scope global 2>/dev/null |
        awk '{ split($4, address, "/"); print address[1] }' || true
    )"

    while read -r address; do
      [[ -n "$address" ]] && echo "  LAN:    http://$address:$port/"
    done <<< "$addresses"
  fi
}

print_logs() {
  echo "  Logs:   $runtime_dir/logs/access.log"
  echo "          $runtime_dir/logs/error.log"
}

prepare_runtime() {
  mkdir -p \
    "$runtime_dir/logs" \
    "$runtime_dir/tmp/client_body" \
    "$runtime_dir/tmp/proxy" \
    "$runtime_dir/tmp/fastcgi" \
    "$runtime_dir/tmp/uwsgi" \
    "$runtime_dir/tmp/scgi"
}

close_extra_fds() {
  local fd fd_dir fd_path

  fd_dir="/proc/$$/fd"

  for fd_path in "$fd_dir"/*; do
    fd="${fd_path##*/}"
    [[ "$fd" =~ ^[0-9]+$ ]] || continue
    [[ "$fd" -gt 2 ]] || continue
    eval "exec ${fd}>&-"
  done
}

write_config() {
  nginx_prefix="$(dirname "$(dirname "$(command -v nginx)")")"
  mime_types="$nginx_prefix/conf/mime.types"

  cat > "$conf_file" <<EOF
worker_processes 1;
pid $pid_file;
error_log $runtime_dir/logs/error.log info;

events {
  worker_connections 1024;
}

http {
  include $mime_types;
  default_type application/octet-stream;

  access_log $runtime_dir/logs/access.log;
  sendfile on;
  keepalive_timeout 65;
  server_tokens off;

  client_body_temp_path $runtime_dir/tmp/client_body;
  proxy_temp_path $runtime_dir/tmp/proxy;
  fastcgi_temp_path $runtime_dir/tmp/fastcgi;
  uwsgi_temp_path $runtime_dir/tmp/uwsgi;
  scgi_temp_path $runtime_dir/tmp/scgi;

  gzip on;
  gzip_types text/plain text/css application/javascript application/json image/svg+xml;

  server {
    listen $host:$port;
    server_name _;
    root "$dist_dir";
    index index.html;
    absolute_redirect off;

    location / {
      try_files \$uri \$uri/index.html \$uri.html /404.html;
    }

    error_page 404 /404.html;

    location = /404.html {
      try_files /404.html =404;
    }

    location ~* \.(?:css|js|png|jpg|jpeg|gif|svg|ico|webmanifest|xml)$ {
      try_files \$uri =404;
      expires 1h;
      add_header Cache-Control "public";
    }
  }
}
EOF
}

if [[ "$mode" == "status" ]]; then
  if pid="$(running_pid)"; then
    echo "PSKC nginx preview is running on pid $pid"
    print_urls
    print_logs
    exit 0
  fi

  echo "PSKC nginx preview is not running on port $port"
  exit 1
fi

if [[ "$mode" == "stop" ]]; then
  if pid="$(running_pid)"; then
    kill "$pid" 2>/dev/null || true

    for _ in 1 2 3 4 5; do
      if kill -0 "$pid" 2>/dev/null; then
        sleep 1
      else
        break
      fi
    done

    if kill -0 "$pid" 2>/dev/null; then
      echo "PSKC nginx preview is still stopping on pid $pid"
    else
      rm -f "$pid_file"
      echo "Stopped PSKC nginx preview on port $port"
    fi
    exit 0
  fi

  rm -f "$pid_file"
  echo "PSKC nginx preview is not running on port $port"
  exit 0
fi

if [[ "$build" != "0" ]]; then
  if [[ ! -d "$site_root/node_modules" ]]; then
    echo "node_modules not found; installing dependencies with npm ci..."
    (cd "$site_root" && npm ci)
  fi

  echo "Building Astro site..."
  (cd "$site_root" && npm run build)
fi

if [[ ! -f "$dist_dir/index.html" ]]; then
  echo "error: $dist_dir/index.html does not exist" >&2
  echo "       run npm run build or use PSKC_BUILD=1." >&2
  exit 1
fi

prepare_runtime

if pid="$(running_pid)"; then
  echo "PSKC nginx preview is already running on pid $pid"
  print_urls
  print_logs
  exit 0
fi

rm -f "$pid_file"

write_config

if [[ "$mode" == "daemon" ]]; then
  start_log="$runtime_dir/logs/start.log"

  if ! (
    close_extra_fds
    exec nginx -e "$runtime_dir/logs/error.log" -p "$runtime_dir" -c "$conf_file" \
      </dev/null >"$start_log" 2>&1
  ); then
    cat "$start_log" >&2
    exit 1
  fi

  echo "Started PSKC nginx preview from $dist_dir"
  print_urls
  print_logs
  exit 0
fi

echo
echo "Serving PSKC static site from:"
echo "  $dist_dir"
echo
echo "Reachable URLs:"
print_urls
echo
echo "Logs:"
echo "  $runtime_dir/logs/access.log"
echo "  $runtime_dir/logs/error.log"
echo
echo "Stop with Ctrl-C."
echo

exec nginx -e "$runtime_dir/logs/error.log" -p "$runtime_dir" -c "$conf_file" -g "daemon off;"
