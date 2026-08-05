# pangeaConversations — Docker (third Rails microservice)

## Goal

Run **Conversations** (REST chat + Action Cable `/cable`) in Docker. MySQL on the host. **Users** must be reachable on the Mac at **:3000** (Docker Users is fine).

## Important: `USERS_SERVICE_URL`

Inside the container, `http://127.0.0.1:3000` is **the container itself**, not Users.

Compose overrides to:

```text
USERS_SERVICE_URL=http://host.docker.internal:3000
```

So Conversations can fetch supervisor/admin data from Users.

## Prerequisites

1. Docker Desktop  
2. `pangeaConversations/.env` with same `JWT_SECRET_KEY` as Users/Media, plus `INTERNAL_SERVICE_TOKEN` if you use it  
3. MySQL DB `pangea_conversations_development`  
4. Free port **3002**  
5. SPA already uses `ws://localhost:3002` / HTTP on 3002  

## Commands

```bash
cd pangeaConversations
docker compose up --build
# or:
docker compose up --build -d

docker compose logs -f
docker compose down
```

## Verify

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:3002/up
# expect 200

# SPA: open a chat / Let's Talk WebSocket
```

## Hybrid stack after this step

| Port | Service |
|------|---------|
| 3000 | Users — Docker |
| 3001 | Media — Docker |
| 3002 | Conversations — Docker |
| 3003 | Search API — still host |
| worker | Search RQ — still host |
| 5173 | SPA — host |

## Files

| File | Role |
|------|------|
| `Dockerfile.dev` | Image build |
| `docker-compose.yml` | Port 3002, env, host DB + Users URL |
| `.dockerignore` | Keep image lean |

## Next

**pangeaSearch** (API + worker) or SPA static image. Search is heavier (Python/ML).
