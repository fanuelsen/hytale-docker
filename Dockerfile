FROM eclipse-temurin:25-jre-alpine

LABEL org.opencontainers.image.title="Hytale Server" \
      org.opencontainers.image.description="Minimal Alpine-based Hytale dedicated server" \
      org.opencontainers.image.source="https://github.com/your-repo"

RUN apk add --no-cache curl ca-certificates unzip gcompat libgcc libstdc++ jq \
    && addgroup -g 1000 hytale \
    && adduser -u 1000 -G hytale -h /home/hytale -s /bin/sh -D hytale \
    && mkdir -p /home/container \
    && chown hytale:hytale /home/container

ENV DEFAULT_PORT=5520 \
    SERVER_NAME="Hytale Server" \
    MAX_PLAYERS=20 \
    VIEW_DISTANCE=12 \
    MAX_MEMORY=8G \
    MIN_MEMORY="" \
    JVM_ARGS="" \
    DISABLE_SENTRY=true \
    AUTH_MODE=authenticated \
    ACCEPT_EARLY_PLUGINS=false \
    DOWNLOAD_ON_START=true

COPY --chown=hytale:hytale --chmod=755 ./scripts/*.sh /home/hytale/scripts/

WORKDIR /home/hytale

EXPOSE 5520/udp
VOLUME ["/home/container"]

HEALTHCHECK --start-period=5m \
            --interval=30s \
            --timeout=10s \
            --retries=3 \
            CMD pgrep -f "HytaleServer.jar" || exit 1

ENTRYPOINT ["/home/hytale/scripts/init.sh"]
