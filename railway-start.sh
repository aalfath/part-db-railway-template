#!/bin/sh
# Railway wrapper for Part-DB: prepares the volume, derives settings, then hands over
# to the image's own entrypoint (which runs the database migrations).
set -e

STORAGE=/var/www/html/public/_storage
mkdir -p "$STORAGE/media" "$STORAGE/uploads"
for d in "$STORAGE" "$STORAGE/media" "$STORAGE/uploads"; do
  if [ "$(stat -c '%u' "$d")" != "$(id -u www-data)" ]; then
    chown -R www-data:www-data "$d"
  fi
done

if [ -z "$APP_SECRET" ]; then
  echo "APP_SECRET is not set. Set it to a long random value." >&2
  exit 1
fi
if [ -z "$DATABASE_URL" ]; then
  echo "DATABASE_URL is not set." >&2
  exit 1
fi

# Doctrine needs the server version in DATABASE_URL (it can't detect it here).
# Read it from the database and append it, unless the URL already has one.
case "$DATABASE_URL" in
  postgres://*|postgresql://*)
    case "$DATABASE_URL" in
      *serverVersion=*) ;;
      *)
        echo "Waiting for PostgreSQL..."
        tries=90
        until v=$(psql "$DATABASE_URL" -tAc 'SHOW server_version_num' 2>/dev/null) && [ -n "$v" ]; do
          tries=$((tries - 1))
          if [ "$tries" -le 0 ]; then
            echo "PostgreSQL is not reachable at DATABASE_URL." >&2
            exit 1
          fi
          sleep 2
        done
        v=$(echo "$v" | tr -d ' ')
        ver="$((v / 10000)).$((v % 10000)).0"
        case "$DATABASE_URL" in
          *\?*) export DATABASE_URL="${DATABASE_URL}&serverVersion=${ver}&charset=utf8" ;;
          *) export DATABASE_URL="${DATABASE_URL}?serverVersion=${ver}&charset=utf8" ;;
        esac
        echo "PostgreSQL ${ver} is reachable."
        ;;
    esac
    ;;
esac

export PORT="${PORT:-8080}"
if [ -z "$DEFAULT_URI" ] && [ -n "$RAILWAY_PUBLIC_DOMAIN" ]; then
  export DEFAULT_URI="https://${RAILWAY_PUBLIC_DOMAIN}/"
fi

exec partdb-entrypoint.sh "$@"
