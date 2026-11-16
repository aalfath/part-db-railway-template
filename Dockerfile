# PostgreSQL 18 client tools for Part-DB's pre-migration database backups (see below).
FROM postgres:18.7-bookworm@sha256:ece55f7868da684e400f82f1030a050718adbdd65c23aa500c486f6e2950dc0f AS pgclient

# Part-DB on Railway: the official image, pinned by version and digest.
# Update by bumping this line (and CHANGELOG.md); Railway then offers the update to deployers.
FROM jbtronics/part-db1:2.20.6@sha256:8f12802ba0cb87268fa2382a89953b696ddc2dfa56a330a3828d27e362fd5f3d

# Fixed settings for Railway. Override any of them with a service variable.
ENV APP_ENV=docker \
    DB_AUTOMIGRATE=true \
    TRUSTED_PROXIES=REMOTE_ADDR \
    DEFAULT_LANG=en \
    DEFAULT_TIMEZONE=UTC \
    BASE_CURRENCY=USD \
    INSTANCE_NAME=Part-DB \
    ALLOW_ATTACHMENT_DOWNLOADS=0 \
    USE_GRAVATAR=0

# Railway's Postgres is version 18, and the Part-DB image ships pg_dump 15, which refuses to
# dump a newer server. Part-DB backs the database up with pg_dump before every automatic
# migration, so copy the PostgreSQL 18 client tools and libpq from the official postgres
# image (same Debian release). Debian's pg_wrapper then picks version 18.
COPY --from=pgclient /usr/lib/postgresql/18 /usr/lib/postgresql/18
COPY --from=pgclient /usr/lib/x86_64-linux-gnu/libpq.so.5* /usr/lib/x86_64-linux-gnu/
RUN ldconfig && pg_dump --version | grep -q ' 18\.'

# Railway allows one volume per service, mounted at /var/www/html/public/_storage.
# Part-DB keeps public attachments in public/media and private ones (plus automatic
# pre-migration backups) in uploads/. Both become symlinks into that one volume.
# Part-DB resolves the media folder with realpath() and builds its URLs relative to
# public/, so the volume has to sit inside public/. Apache denies every request to
# public/_storage except the media folder (see railway-storage.conf).
RUN rm -rf /var/www/html/uploads /var/www/html/public/media \
 && mkdir -p /var/www/html/public/_storage \
 && ln -s /var/www/html/public/_storage/uploads /var/www/html/uploads \
 && ln -s _storage/media /var/www/html/public/media \
 && sed -i 's/^Listen 80$/Listen ${PORT}/' /etc/apache2/ports.conf \
 && sed -i 's/<VirtualHost \*:80>/<VirtualHost *:${PORT}>/' /etc/apache2/sites-available/symfony.conf

COPY railway-storage.conf /etc/apache2/conf-enabled/zz-railway-storage.conf
COPY railway-start.sh /usr/local/bin/railway-start.sh
RUN chmod 0755 /usr/local/bin/railway-start.sh

ENV PORT=8080
EXPOSE 8080
ENTRYPOINT ["railway-start.sh"]
CMD ["/usr/local/bin/apache2-foreground"]
