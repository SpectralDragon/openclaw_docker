# MoltBot Deployment Bundle (Formerly ClawdBot)

This repository packages everything you need to run **MoltBot** locally with Docker. It includes a container image build, a Docker Compose definition.

## Contents

- `Dockerfile` — builds a lightweight image that installs the `clawdbot` CLI and runs the gateway service.
- `docker-compose.yaml` — starts the service locally with persistent volumes and health checks.

## Docker

### Build the image

```bash
docker build -t moltbot:local .
```

### Run with Docker

```bash
docker run -it --rm \
  -p 18789:18789 \
  -p 18791:18791 \
  -e CLAWDBOT_GATEWAY_TOKEN="<token>" \
  -v "$(pwd)/data/moltbot-config:/root/.clawdbot" \
  -v "$(pwd)/data/moltbot-workspace:/root/clawd" \
  moltbot:local
```

The image exposes ports `18789` (gateway UI/API) and `18791` (bridge) by default. The data directories are persisted under `./data/` in the example above.

## Docker Compose

Start the service using the published image:

```bash
docker compose up -d
```

The compose file maps the following defaults:

- Gateway: `18789` → `18789`
- Bridge: `18790` → `18790`

You can override the ports with `MOLTBOT_GATEWAY_PORT` and `MOLTBOT_BRIDGE_PORT`, and provide required secrets via environment variables:

- `MOLTBOT_GATEWAY_TOKEN`

Data persists in `./data/moltbot-config` and `./data/moltbot-workspace` by default.

## Notes

- If you use the Dockerfile build, the gateway binds to `lan` by default. The Docker Compose file binds to `loopback`.
- Ensure the gateway token is set before starting the service.

## Troubleshooting

### Control UI Requires HTTPS or localhost
> disconnected (1008): control ui requires HTTPS or localhost (secure context)
Fix:
```
Open the Control UI from either:
- http://localhost:<port>
- https://<your-domain>

Note: non-localhost HTTP URLs (ex: http://192.168.x.x) are not considered a secure context.
```

### Unauthorized: gateway token mismatch
> disconnected (1008): unauthorized: gateway token mismatch (open a tokenized dashboard URL or paste token in Control UI settings)

Fix:
```
This means the Control UI is using a different token than the running gateway.

Fix options:
- Open the tokenized dashboard URL (recommended):
  http://localhost:18789/?token=<your-token>
- Or paste the correct token in: Control UI → Config → Gateway → Gateway Token

Then restart the gateway with the same token:
  export MOLTBOT_GATEWAY_TOKEN="<your-token>"
```

### Pairing Required
> disconnected (1008): pairing required

Fix:
```
List pending device requests:
  clawdbot devices list

Approve a pending request:
  clawdbot devices approve <PENDING_REQUEST_ID>
```