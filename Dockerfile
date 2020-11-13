ARG version=12

FROM minidocks/base:3.8 AS v10

FROM minidocks/base:3.10 AS v11

FROM minidocks/base:3.11 AS v12

FROM v$version AS latest
LABEL maintainer="Martin Hasoň <martin.hason@gmail.com>"

RUN set -eux; addgroup -g 70 -S postgres; \
    adduser -u 70 -S -D -G postgres -H -h /var/lib/postgresql -s /bin/sh postgres; \
    mkdir -p /var/lib/postgresql; chown -R postgres:postgres /var/lib/postgresql

ENV LANG=en_US.utf8 \
    PGDATA=/var/lib/postgresql/data

RUN apk --update add postgresql postgresql-contrib && clean

# make the sample config easier to munge (and "correct by default")
RUN sed -ri "s!^#?(listen_addresses)\s*=\s*\S+.*!\1 = '*'!" /usr/share/postgresql/postgresql.conf.sample

RUN mkdir -p /run/postgresql && chown -R postgres:postgres /run/postgresql && chmod 2777 /run/postgresql

RUN mkdir /docker-entrypoint-initdb.d

RUN mkdir -p "$PGDATA" && chown -R postgres:postgres "$PGDATA" && chmod 777 "$PGDATA"

VOLUME /var/lib/postgresql/data

COPY rootfs /

# We set the default STOPSIGNAL to SIGINT, which corresponds to what PostgreSQL
# calls "Fast Shutdown mode" wherein new connections are disallowed and any
# in-progress transactions are aborted, allowing PostgreSQL to stop cleanly and
# flush tables to disk, which is the best compromise available to avoid data
# corruption.
#
# Users who know their applications do not keep open long-lived idle connections
# may way to use a value of SIGTERM instead, which corresponds to "Smart
# Shutdown mode" in which any existing sessions are allowed to finish and the
# server stops when all sessions are terminated.
#
# See https://www.postgresql.org/docs/12/server-shutdown.html for more details
# about available PostgreSQL server shutdown signals.
#
# See also https://www.postgresql.org/docs/12/server-start.html for further
# justification of this as the default value, namely that the example (and
# shipped) systemd service files use the "Fast Shutdown mode" for service
# termination.
#
STOPSIGNAL SIGINT
#
# An additional setting that is recommended for all users regardless of this
# value is the runtime "--stop-timeout" (or your orchestrator/runtime's
# equivalent) for controlling how long to wait between sending the defined
# STOPSIGNAL and sending SIGKILL (which is likely to cause data corruption).
#
# The default in most runtimes (such as Docker) is 10 seconds, and the
# documentation at https://www.postgresql.org/docs/12/server-start.html notes
# that even 90 seconds may not be long enough in many instances.

EXPOSE 5432
CMD [ "postgres" ]

FROM latest AS czech

ENV LANG cs_CZ.UTF-8

RUN wget -O /tmp/czech.tar.gz https://postgres.cz/data/czech.tar.gz && cd /tmp && tar -xzf czech.tar.gz -C /tmp/ \
    && mv /tmp/fulltext_dicts/czech* /usr/share/postgresql/tsearch_data/ && clean

RUN wget -O /tmp/czech.tar.gz https://github.com/freaz/docker-postgres-czech-unaccent/raw/master/czech_unaccent.tar.gz && cd /tmp && tar -xzf czech.tar.gz -C /tmp/ \
    && mv /tmp/fulltext_dicts/czech* /usr/share/postgresql/tsearch_data/ && clean

COPY rootfs-czech /

FROM latest
