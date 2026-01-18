# Hytale Server Docker

Minimal Alpine-based Docker container for running a Hytale dedicated server with automated setup and optimal performance.

## Requirements

- Docker & Docker Compose
- 8GB+ RAM (12GB+ recommended)
- 4+ CPU cores (8+ recommended)
- 10GB+ disk space

## Quick Start

```bash
git clone https://github.com/fanuelsen/hytale-docker.git
cd hytale-docker
docker compose up -d --build
```

## First-Time Setup

On first startup, **two authentication steps** are required:

### Step 1: Download Authentication

1. Start the container: `docker compose up -d --build`
2. Watch logs: `docker compose logs -f`
3. The downloader will display an OAuth URL to download server files:
   ```
   Please visit the following URL to authenticate:
   https://oauth.accounts.hytale.com/oauth2/device/verify?user_code=XXXXXX
   ```
4. Visit the URL and authenticate with your Hytale account
5. Server files will download (~1.4GB) - this may take several minutes
6. Download credentials are saved for future updates

### Step 2: Server Authentication

1. After download completes, the server will start and display another OAuth URL:
   ```
   Visit: https://oauth.accounts.hytale.com/oauth2/device/verify?user_code=YYYYYY
   ```
2. Visit this URL and authenticate again (this authorizes the game server)
3. Server credentials are automatically saved with encrypted persistence
4. The server will start and be ready for connections

After initial setup, both authentications persist and the server will start automatically on future restarts with ```bash 
docker compose up -d```

## Configuration

Edit `docker-compose.yml` to configure server settings:

| Variable | Default | Description |
|----------|---------|-------------|
| `DEFAULT_PORT` | `5520` | Server UDP port |
| `SERVER_NAME` | `Hytale Server` | Server display name |
| `MAX_PLAYERS` | `20` | Maximum concurrent players |
| `VIEW_DISTANCE` | `12` | View radius in chunks (12 = 384 blocks) |
| `MAX_MEMORY` | `8G` | Maximum JVM heap size |
| `MIN_MEMORY` | `` | Minimum JVM heap (uses MAX_MEMORY if empty) |
| `JVM_ARGS` | `` | Custom JVM arguments |
| `AUTH_MODE` | `authenticated` | `authenticated` or `offline` |
| `DISABLE_SENTRY` | `true` | Disable crash reporting |
| `ACCEPT_EARLY_PLUGINS` | `false` | Enable experimental plugins |
| `DOWNLOAD_ON_START` | `true` | Auto-download server updates |

Example configuration:
```yaml
environment:
  - SERVER_NAME=My Awesome Server
  - MAX_PLAYERS=50
  - VIEW_DISTANCE=16
  - MAX_MEMORY=16G
  - MIN_MEMORY=12G
```

Restart to apply changes:
```bash
docker compose restart
```

## Usage

### Start and build Server
```bash
docker compose up -d --build
```

### View Logs
```bash
docker compose logs -f
```

### Stop Server
```bash
docker compose down
```

### Access Console
```bash
docker attach hytale-server
# Press Ctrl+P Ctrl+Q to detach
```

### Update Server
Set `DOWNLOAD_ON_START=true` (default) and restart:
```bash
docker compose restart
```

## Port Forwarding

The server uses **UDP port 5520** (QUIC protocol). Ensure your firewall and router forward UDP 5520 to your server.

## Pterodactyl

Import `egg-hytale.json` into your Pterodactyl panel (Admin → Nests → Import Egg). The egg uses the pre-built container from `ghcr.io/fanuelsen/hytale-docker:latest`.

On first start, check the console for OAuth URLs to authenticate the downloader and server.

## Data Persistence

Server files are stored in `./server-files/` which includes:
- Assets (`Assets.zip`)
- Server executable (`Server/HytaleServer.jar`)
- World data (`Server/universe/`)
- Configuration (`Server/config.json`)
- Authentication credentials (`Server/auth.enc`)
- Mods/plugins (`Server/mods/`)

## Performance Tuning

The container uses optimized JVM settings:
- **ZGC Generational GC** - Sub-millisecond pause times
- **Fixed heap allocation** - Prevents GC overhead from resizing
- **Pre-touched memory** - Eliminates lazy allocation stalls
- **Native access enabled** - Removes QUIC library warnings

For better performance:
- Increase `MAX_MEMORY` (16G+ for larger servers)
- Allocate more CPU cores
- Use SSD storage for `./server-files/`

## Troubleshooting

### "Took too long to run pre-load process hook"
This is normal during initial world generation. Increase `MAX_MEMORY` to 12G+ or wait for initial chunks to generate.

### Server won't authenticate
Delete `./server-files/Server/auth.enc` and restart to re-trigger OAuth flow.

### Permission errors
The container runs as UID/GID 1000. Ensure `./server-files/` is writable:
```bash
sudo chown -R 1000:1000 ./server-files
```

### Out of memory errors
Increase `MAX_MEMORY` in docker-compose.yml and ensure Docker has sufficient RAM allocated.

## License

This Docker configuration is provided as-is for running Hytale dedicated servers. Hytale and all related assets are property of Hypixel Studios.
