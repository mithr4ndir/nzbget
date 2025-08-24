# syntax=docker/dockerfile:1
FROM debian:stable-slim

ENV NZBGET_VERSION=21.1 \
    PUID=1000 PGID=1000 UMASK=002 TZ=Etc/UTC \
    NZBGET_PORT=6789 TERM=xterm

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl p7zip-full tini gosu tzdata ncurses-base \
    && rm -rf /var/lib/apt/lists/*

# app user + dirs
RUN groupadd -g ${PGID} app && useradd -u ${PUID} -g ${PGID} -d /home/app -m -s /usr/sbin/nologin app \
 && mkdir -p /app /config /downloads \
 && chown -R app:app /app /config /downloads

# install nzbget
WORKDIR /app
RUN curl -fsSL "https://github.com/nzbget/nzbget/releases/download/v${NZBGET_VERSION}/nzbget-${NZBGET_VERSION}-bin-linux.run" -o nzbget.run \
 && chmod +x nzbget.run \
 && ./nzbget.run --destdir /app \
 && rm nzbget.run \
 # Template for Settings page lives next to web UI
 && cp /app/nzbget.conf /app/webui/nzbget.conf \
 && chmod 644 /app/webui/nzbget.conf

# default config used to seed /config on first run
COPY nzbget.conf /defaults/nzbget.conf

# health
HEALTHCHECK --interval=30s --timeout=5s --retries=5 CMD curl -fsS "http://127.0.0.1:${NZBGET_PORT}/" >/dev/null || exit 1

EXPOSE 6789
VOLUME ["/config", "/downloads"]

# entrypoint + headless server
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["/usr/bin/tini","--","/usr/local/bin/docker-entrypoint.sh"]

# IMPORTANT: point NZBGet at both WebDir and ConfigTemplate
CMD ["/app/nzbget","-s","-c","/config/nzbget.conf","-o","WebDir=/app/webui","-o","ConfigTemplate=/app/webui/nzbget.conf","-o","ControlIP=0.0.0.0","-o","ControlPort=6789"]
