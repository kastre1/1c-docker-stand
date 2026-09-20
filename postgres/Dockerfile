# ============================================================
# PostgreSQL 15.17-1.1C (сборка 1С) на базе Ubuntu 24.04
# ============================================================
FROM postgres:15 AS official

FROM ubuntu:24.04

USER root

# Зависимости
RUN apt-get update && apt-get install -y --no-install-recommends \
    locales libicu74 libssl3 libxml2 libreadline8 \
    libzstd1 liblz4-1 zlib1g tzdata ca-certificates gnupg gosu \
 && rm -rf /var/lib/apt/lists/*

# .deb 1С
COPY distr-min/*.deb /tmp/debs/
RUN dpkg -i --force-overwrite /tmp/debs/*.deb || true \
 && apt-get update \
 && apt-get install -f -y --no-install-recommends \
 && rm -rf /tmp/debs /var/lib/apt/lists/*

# Удаляем кластер, созданный .deb-пакетом — entrypoint создаст свой
RUN rm -rf /var/lib/postgresql/15

# Локаль
RUN sed -i 's/^# *\(ru_RU.UTF-8\)/\1/' /etc/locale.gen \
 && sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen \
 && locale-gen
ENV LANG=ru_RU.UTF-8 \
    LANGUAGE=ru_RU:ru \
    LC_ALL=ru_RU.UTF-8

# entrypoint из официального postgres:15
COPY --from=official /usr/local/bin/docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Каталог для init-скриптов
RUN mkdir -p /docker-entrypoint-initdb.d

# Каталоги PostgreSQL
RUN mkdir -p /var/lib/postgresql /var/run/postgresql /var/lib/postgresql/data \
 && chown -R postgres:postgres /var/lib/postgresql /var/run/postgresql /docker-entrypoint-initdb.d \
 && chmod 2775 /var/run/postgresql

# ⚠️ ГЛАВНОЕ: бинарники 1С в PATH
ENV PATH="/usr/lib/postgresql/15/bin:${PATH}"

ENV PGDATA=/var/lib/postgresql/data
VOLUME /var/lib/postgresql/data

EXPOSE 5432
ENTRYPOINT ["docker-entrypoint.sh"]
STOPSIGNAL SIGINT
CMD ["postgres"]
