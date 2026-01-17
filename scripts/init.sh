#!/bin/sh
set -e

SERVER_FILES="/home/hytale/server-files"
MACHINE_ID_DIR="$SERVER_FILES/.machine-id"

# Generate persistent machine ID for Hytale auth
setup_machine_id() {
    if [ ! -f "$MACHINE_ID_DIR/machine-id" ]; then
        mkdir -p "$MACHINE_ID_DIR"
        UUID=$(cat /proc/sys/kernel/random/uuid)
        MACHINE_ID=$(echo "$UUID" | tr -d '-')

        echo "$MACHINE_ID" > "$MACHINE_ID_DIR/machine-id"
        echo "$UUID" > "$MACHINE_ID_DIR/uuid"
    fi

    cp "$MACHINE_ID_DIR/machine-id" /etc/machine-id
    mkdir -p /var/lib/dbus
    cp "$MACHINE_ID_DIR/machine-id" /var/lib/dbus/machine-id
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

# Setup
setup_machine_id

# Fix ownership only if needed (volume may be mounted with wrong permissions)
if [ "$(stat -c %u "$SERVER_FILES")" != "1000" ]; then
    chown -R hytale:hytale "$SERVER_FILES"
fi

# Start server as hytale user
cd "$SERVER_FILES"
su -s /bin/sh hytale -c "/home/hytale/scripts/start.sh" &
CHILD_PID=$!

wait $CHILD_PID
