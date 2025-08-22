# syntax=docker/dockerfile:1
FROM debian:stable-slim

# Set versions + defaults
ENV NZBGET_VERSION=21.1 \
    PUID=1000 \
    PGID=1000 \
    TZ=Etc/UTC \
    UMASK=002 \
    NZBGET_HOME=/config \
    NZBGET_PORT=6789

# deps: ca-certificates for https, tini for proper signal handling, curl for download, p7zip-full for unpacking
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      p7zip-full \
      tini \
      gosu \
      tzdata \
    && rm -rf /var/lib/apt/lists/*

# Create app user/group
RUN groupadd -g ${PGID} app && useradd -u ${PUID} -g ${PGID} -d /home/app -m -s /usr/sbin/nologin app

# Create dirs
RUN mkdir -p /app /config /downloads && chown -R app:app /app /config /downloads

# Fetch NZBGet prebuilt binary (official static build)
WORKDIR /app
RUN curl -fsSL "https://github.com/nzbget/nzbget/releases/download/v${NZBGET_VERSION}/nzbget-${NZBGET_VERSION}-bin-linux.run" -o nzbget.run \
 && chmod +x nzbget.run \
 && ./nzbget.run --destdir /app \
 && rm nzbget.run

# Preseed a default config if none exists at runtime
COPY nzbget.conf /defaults/nzbget.conf

# Healthcheck: UI should be reachable
HEALTHCHECK --interval=30s --timeout=5s --retries=5 CMD curl -fsS "http://127.0.0.1:${NZBGET_PORT}/" >/dev/null || exit 1

EXPOSE 6789
VOLUME ["/config", "/downloads"]

# Entrypoint script to drop privileges and ensure config exists
COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["/usr/bin/tini","--","/usr/local/bin/docker-entrypoint.sh"]

# Default: run NZBGet in daemonized server mode bound to 0.0.0.0
CMD ["nzbget","-s","-c","/config/nzbget.conf","-o","WebDir=/app/webui","-o","ControlIP=0.0.0.0","-o","ControlPort=6789"]
