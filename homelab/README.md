# homelab

The same OCSF + Tenzir + ClickHouse pattern, deployed on a real Linux host instead of a
laptop. This is what the [`local_pipeline/`](../local_pipeline/) POC turns into once you're
ready to feed it production-grade log sources.

## What's different from `local_pipeline/`

| Aspect | `local_pipeline/` | `homelab/` |
|---|---|---|
| Layout | One compose file, everything in one project | One compose file per service, shared external Docker network `homelab` |
| Data source | Static log samples in `pipelines/logs/` | Live tail of `/var/log/pihole/pihole.log` |
| Tenzir control plane | Local-only | Connected to managed Tenzir at `wss://ws.tenzir.app/production` |
| Visualization | SQL via `clickhouse-client` | Grafana on `:3000` with ClickHouse datasource + DNS dashboard |
| Storage paths | Bind mounts inside the repo | Bind mounts under `/home/niels/lab/...` (change to your own) |

## Components

- **`clickhouse/`** — ClickHouse server, bind-mounted data and logs.
  - `schema/dns_activity.sql` — DDL for the `ocsf.dns_activity` table.
- **`tenzir/`** — Tenzir node (container name `caliber`).
  - `tenzir.yaml` — declares the pihole → ClickHouse pipeline inline.
  - `pipelines/parse_pihole.tql` — same pipeline as a standalone file.
- **`grafana/`** — Grafana with the ClickHouse datasource plugin pre-installed.
  - `dashboards/dns-dashboard.json` — Pi-hole DNS activity dashboard.
- **`host/crontab.example`** — nightly `docker restart caliber` so Tenzir re-opens the
  rotated `pihole.log`.

## Deploying it

```sh
# 1. Create the shared network once
docker network create homelab

# 2. Edit each compose file to point at your host paths and (in homelab/tenzir/)
#    drop in your TENZIR_TOKEN. Or remove the TENZIR_TOKEN line for a fully local node.

# 3. Bring up each service
docker compose -f clickhouse/docker-compose.yaml up -d
docker compose -f tenzir/docker-compose.yaml up -d
docker compose -f grafana/docker-compose.yaml up -d

# 4. Create the table (one-time)
docker exec -i clickhouse clickhouse-client -u default --password tenzir < clickhouse/schema/dns_activity.sql

# 5. Optional: install the host crontab from host/crontab.example
```

## Notes before you commit your own version

- The `TENZIR_TOKEN=tnz_REPLACE_ME` value in `tenzir/docker-compose.yaml` is a placeholder.
  Move the real token to a `.env` file and reference it as `${TENZIR_TOKEN}` if you intend
  to push this elsewhere.
- The ClickHouse password is `tenzir` everywhere — fine for a homelab behind a firewall,
  not fine for anything internet-reachable.
