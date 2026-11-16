# Part-DB on Railway

Railway template for [Part-DB](https://github.com/Part-DB/Part-DB-server), an open-source inventory manager for electronic components.

This repo is what the Railway template builds. It deploys:

- **Part-DB 2.20.6**, the official image `jbtronics/part-db1:2.20.6` pinned by digest, with a small Railway wrapper.
- **PostgreSQL** (Railway's own database service).
- One volume for uploaded attachments and automatic backups.

## Variables

| Variable | Default | What it does |
|---|---|---|
| `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` | Connection to the Postgres service. The wrapper adds the server version Doctrine needs. |
| `APP_SECRET` | generated | Signs cookies and CSRF tokens. |
| `INITIAL_ADMIN_PW` | generated | Password of the `admin` user. Used once, when the database is first created. |
| `PORT` | `8080` | Port Apache listens on. |

Log in as `admin` with the `INITIAL_ADMIN_PW` value from the service's Variables tab, then change the password under the user settings. Changing the variable later has no effect.

Fixed settings baked into the image (override any of them with a service variable): `DB_AUTOMIGRATE=true`, `TRUSTED_PROXIES=REMOTE_ADDR`, `DEFAULT_LANG=en`, `DEFAULT_TIMEZONE=UTC`, `BASE_CURRENCY=USD`, `INSTANCE_NAME=Part-DB`, `ALLOW_ATTACHMENT_DOWNLOADS=0`, `USE_GRAVATAR=0`. `DEFAULT_URI` is derived from the Railway domain. Set `BASE_CURRENCY` before you enter prices: it can't be changed later.

Optional settings (email, SAML single sign-on, `TRUSTED_HOSTS`, part information providers) are listed in the [Part-DB configuration docs](https://docs.part-db.de/configuration.html).

## How it works

- `Dockerfile` starts from the pinned Part-DB image, adds the PostgreSQL 18 client tools (copied from the pinned official `postgres:18.7-bookworm` image) so Part-DB's pre-migration backup can dump Railway's Postgres 18, and makes Apache listen on `PORT`.
- Railway allows one volume per service. It's mounted at `/var/www/html/public/_storage`, and Part-DB's `public/media` (public attachments) and `uploads` (private attachments and backups) are symlinks into it. Part-DB builds attachment URLs relative to `public/`, so the volume has to sit inside it. `railway-storage.conf` makes Apache refuse every request into the volume except `media/`, and refuses PHP files there.
- `railway-start.sh` prepares the volume, reads the Postgres version, sets `DEFAULT_URI`, then runs the image's own entrypoint, which backs up the database and runs the migrations on every start (`DB_AUTOMIGRATE`).

## Updates

Changes reach deployers through this repo: each change to `main` (for example a new Part-DB version in the `FROM` line) shows up as an update in their Railway project, and they choose when to apply it. Read `CHANGELOG.md` before you apply one. On start, Part-DB writes a database backup to `uploads/.automigration-backup/` before it migrates.

## License

The wrapper files in this repo are MIT. Part-DB itself is AGPL-3.0.
