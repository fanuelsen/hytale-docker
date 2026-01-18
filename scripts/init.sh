#!/bin/sh
set -e

# Detect Pterodactyl install phase - /mnt/server exists during install, not runtime
if [ -d "/mnt/server" ] && [ -w "/mnt/server" ]; then
    echo "[hytale] Install phase detected, skipping (download happens on first start)"
    exit 0
fi

SERVER_FILES="/home/container"
MACHINE_ID_DIR="$SERVER_FILES/.machine-id"

# Generate persistent machine ID for Hytale auth (optional - may fail without root)
setup_machine_id() {
    # Try to create machine-id, but don't fail if we can't (e.g., in Pterodactyl)
    if [ ! -f "$MACHINE_ID_DIR/machine-id" ]; then
        if mkdir -p "$MACHINE_ID_DIR" 2>/dev/null; then
            UUID=$(cat /proc/sys/kernel/random/uuid)
            MACHINE_ID=$(echo "$UUID" | tr -d '-')
            echo "$MACHINE_ID" > "$MACHINE_ID_DIR/machine-id" 2>/dev/null || true
            echo "$UUID" > "$MACHINE_ID_DIR/uuid" 2>/dev/null || true
        fi
    fi

    # Try to copy to system locations (requires root)
    if [ -f "$MACHINE_ID_DIR/machine-id" ]; then
        cp "$MACHINE_ID_DIR/machine-id" /etc/machine-id 2>/dev/null || true
        mkdir -p /var/lib/dbus 2>/dev/null || true
        cp "$MACHINE_ID_DIR/machine-id" /var/lib/dbus/machine-id 2>/dev/null || true
    fi
}

# Graceful shutdown handler
shutdown() {
    echo "Shutting down server..."
    PID=$(pgrep -f "HytaleServer.jar" 2>/dev/null || true)
    if [ -n "$PID" ]; then
        kill -TERM "$PID" 2>/dev/null || true
        # Wait up to 30s for graceful shutdown
        i=0
        while [ $i -lt 30 ] && kill -0 "$PID" 2>/dev/null; do
            sleep 1
            i=$((i + 1))
        done
        # Force kill if still running
        kill -9 "$PID" 2>/dev/null || true
    fi
    exit 0
}

trap shutdown TERM INT

# Setup (don't fail if permissions don't allow)
setup_machine_id

# Fix ownership only if we have permission and it's needed
if [ "$(id -u)" = "0" ] && [ "$(stat -c %u "$SERVER_FILES" 2>/dev/null)" != "1000" ]; then
    chown -R hytale:hytale "$SERVER_FILES" 2>/dev/null || true
fi

cd "$SERVER_FILES"

# Run start.sh - either as hytale user (if root) or directly (if not root)
if [ "$(id -u)" = "0" ]; then
    su -s /bin/sh hytale -c "/home/hytale/scripts/start.sh" &
    CHILD_PID=$!
    wait $CHILD_PID
else
    exec /home/hytale/scripts/start.sh
fi
