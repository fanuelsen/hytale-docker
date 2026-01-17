#!/bin/sh
set -e

SERVER_FILES="/home/hytale/server-files"
SERVER_DIR="$SERVER_FILES/Server"
SERVER_JAR="$SERVER_DIR/HytaleServer.jar"
DOWNLOADER="$SERVER_FILES/hytale-downloader-linux-amd64"
VERSION_FILE="$SERVER_FILES/.version"

# Defaults
: "${DEFAULT_PORT:=5520}"
: "${SERVER_NAME:=Hytale Server}"
: "${MAX_PLAYERS:=20}"
: "${VIEW_DISTANCE:=12}"
: "${MAX_MEMORY:=8G}"
: "${MIN_MEMORY:=}"
: "${JVM_ARGS:=}"
: "${AUTH_MODE:=authenticated}"
: "${DISABLE_SENTRY:=true}"
: "${ACCEPT_EARLY_PLUGINS:=false}"
: "${DOWNLOAD_ON_START:=true}"

log() { echo "[hytale] $1"; }

download_server() {
    # Skip if server already exists
    if [ -f "$SERVER_JAR" ]; then
        log "Server already installed, skipping download"
        return 0
    fi

    log "Downloading server (authentication may be required)..."

    # Download and extract the downloader tool (junk paths with -j)
    DOWNLOADER_ZIP="$SERVER_FILES/hytale-downloader.zip"
    curl -fsSL "http://downloader.hytale.com/hytale-downloader.zip" -o "$DOWNLOADER_ZIP"
    unzip -oj "$DOWNLOADER_ZIP" -d "$SERVER_FILES"
    rm -f "$DOWNLOADER_ZIP" "$SERVER_FILES"/*.exe "$SERVER_FILES/QUICKSTART.md"
    chmod +x "$DOWNLOADER"

    # Run downloader - will print OAuth URL if auth needed
    "$DOWNLOADER" -download-path "$SERVER_FILES/server.zip"

    # Extract and cleanup
    unzip -o "$SERVER_FILES/server.zip" -d "$SERVER_FILES"
    rm -f "$SERVER_FILES/server.zip"

    log "Server installed"
}

build_jvm_args() {
    # Memory settings
    if [ -n "$MIN_MEMORY" ]; then
        ARGS="-Xms${MIN_MEMORY} -Xmx${MAX_MEMORY}"
    else
        ARGS="-Xms${MAX_MEMORY} -Xmx${MAX_MEMORY}"
    fi

    # Use ZGC for low-latency GC (generational is default in Java 25)
    ARGS="$ARGS -XX:+UseZGC"
    ARGS="$ARGS -XX:ZCollectionInterval=5"
    ARGS="$ARGS -XX:ZAllocationSpikeTolerance=5"

    # Performance flags
    ARGS="$ARGS -XX:+AlwaysPreTouch"
    ARGS="$ARGS -XX:+DisableExplicitGC"
    ARGS="$ARGS -XX:+ParallelRefProcEnabled"

    # Enable native access for netty QUIC without warnings
    ARGS="$ARGS --enable-native-access=ALL-UNNAMED"

    # Add custom JVM args if provided
    [ -n "$JVM_ARGS" ] && ARGS="$ARGS $JVM_ARGS"

    echo "$ARGS"
}

init_config() {
    CONFIG_FILE="$SERVER_DIR/config.json"

    if [ ! -f "$CONFIG_FILE" ]; then
        log "Generating default config.json (starting server briefly)..."

        # Server creates config.json in its working directory
        cd "$SERVER_DIR"

        # Start server in background to generate config
        java $JVM_ARGS -jar "$SERVER_JAR" $SERVER_ARGS 2>&1 &
        INIT_PID=$!

        # Wait for config file to be created
        log "Waiting for server to create config.json..."
        while kill -0 $INIT_PID 2>/dev/null; do
            if [ -f "$CONFIG_FILE" ]; then
                log "Config file detected, sending graceful shutdown..."
                kill -TERM $INIT_PID 2>/dev/null || true
                # Wait for graceful shutdown (server saves config on exit)
                wait $INIT_PID 2>/dev/null || true
                sleep 2
                break
            fi
            sleep 1
        done

        if [ -f "$CONFIG_FILE" ]; then
            log "Setting encrypted persistence in config..."
            TMP_CONFIG=$(mktemp)
            jq '. + {"AuthCredentialStore": {"Type": "Encrypted", "Path": "auth.enc"}}' \
               "$CONFIG_FILE" > "$TMP_CONFIG"
            mv "$TMP_CONFIG" "$CONFIG_FILE"
            log "Config initialized with encrypted auth persistence"
        else
            log "WARNING: config.json not created during initialization"
        fi
    fi
}

update_config() {
    CONFIG_FILE="$SERVER_DIR/config.json"

    if [ ! -f "$CONFIG_FILE" ]; then
        log "Config file not found, skipping update"
        return 0
    fi

    log "Updating config.json with environment variables..."

    # Create temp file for atomic update
    TMP_CONFIG=$(mktemp)

    jq --arg name "$SERVER_NAME" \
       --argjson players "$MAX_PLAYERS" \
       --argjson view "$VIEW_DISTANCE" \
       '.ServerName = $name | .MaxPlayers = $players | .MaxViewRadius = $view' \
       "$CONFIG_FILE" > "$TMP_CONFIG"

    mv "$TMP_CONFIG" "$CONFIG_FILE"
    log "Config updated: MaxPlayers=$MAX_PLAYERS, MaxViewRadius=$VIEW_DISTANCE"
}

build_server_args() {
    ARGS="--assets $SERVER_FILES/Assets.zip"
    ARGS="$ARGS --bind 0.0.0.0:${DEFAULT_PORT}"
    ARGS="$ARGS --auth-mode ${AUTH_MODE}"
    [ "$DISABLE_SENTRY" = "true" ] && ARGS="$ARGS --disable-sentry"
    [ "$ACCEPT_EARLY_PLUGINS" = "true" ] && ARGS="$ARGS --accept-early-plugins"
    echo "$ARGS"
}

# Download if enabled
if [ "$DOWNLOAD_ON_START" = "true" ]; then
    download_server
fi

if [ ! -f "$SERVER_JAR" ]; then
    log "ERROR: Server jar not found at $SERVER_JAR"
    exit 1
fi

JVM_ARGS=$(build_jvm_args)
SERVER_ARGS=$(build_server_args)

init_config
update_config

cd "$SERVER_DIR"

if [ ! -f "$SERVER_DIR/auth.enc" ]; then
    log "=========================================================================="
    log "FIRST-TIME SETUP: Authentication required"
    log "=========================================================================="
    log "1. Server will auto-trigger device auth and display an OAuth URL"
    log "2. Visit the URL in your browser to authenticate"
    log "3. Run '/auth persistence Encrypted' in server console to save credentials"
    log "=========================================================================="
fi

log "Starting Hytale server..."
if [ ! -f "$SERVER_DIR/auth.enc" ]; then
    exec java $JVM_ARGS -jar "$SERVER_JAR" $SERVER_ARGS --boot-command 'auth login device'
else
    exec java $JVM_ARGS -jar "$SERVER_JAR" $SERVER_ARGS
fi
