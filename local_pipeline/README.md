# local_pipeline

The single-VM POC. Runs a Tenzir node and a ClickHouse server in Docker, with three
working TQL pipelines that parse sample logs into OCSF and write them to ClickHouse.

## Prerequisites

- Docker Desktop (or Docker Engine) with Compose v2

## Run it

```sh
docker compose up -d
```

Two containers come up:

| Container | Purpose | Ports |
|---|---|---|
| `tenzir-node` | Pipeline engine | `5158` (REST), `24224` (Fluent Bit forward) |
| `clickhouse` | Hot store | `8123` (HTTP), `9000` (native) |

ClickHouse credentials are `default` / `tenzir`, default database `ocsf`. Data persists to
`./clickhouse_data/` (gitignored).

## Pipelines that land data in ClickHouse

| Pipeline | Source | OCSF class | ClickHouse table |
|---|---|---|---|
| `pipelines/parse-access-logs-clickhouse.tql` | `pipelines/logs/http-access-logs.txt` | HTTP Activity (4002) | `ocsf.http_activity` |
| `pipelines/parse-cloudtrail.tql` | `pipelines/logs/cloudtrail-record.json` | API Activity (6003) **and** Authentication (3002), routed by event | `ocsf.api_activity`, `ocsf.authentication` |

The CloudTrail pipeline routes events from `signin.amazonaws.com` (ConsoleLogin, SwitchRole, ...)
and `sts.amazonaws.com` (AssumeRole, GetSessionToken, ...) into `ocsf.authentication`;
everything else lands in `ocsf.api_activity`.

Run any of them:

```sh
docker exec tenzir-node tenzir -f /pipelines/parse-access-logs-clickhouse.tql
docker exec tenzir-node tenzir -f /pipelines/parse-cloudtrail.tql
```

Tables are auto-created on first run via `mode="create_append"`.

## WIP pipelines (not wired to ClickHouse yet)

These parse correctly but emit JSON only — left in as exercises:

- `pipelines/parse-access-logs.tql` — same as the ClickHouse version but with `write_json`
- `pipelines/parse-flow-logs.tql`, `parse-flow-v2.tql`, `publish-flow-logs.tql` — VPC flow logs
  via Tenzir's pub/sub. Add a `to_clickhouse` sink to land them in `ocsf.network_activity`.

## Sample queries

```sh
docker exec clickhouse clickhouse-client -u default --password tenzir -q \
  "SELECT activity_name, user.name, src_endpoint.ip, unmapped.eventName
   FROM ocsf.authentication ORDER BY time DESC LIMIT 10"

docker exec clickhouse clickhouse-client -u default --password tenzir -q \
  "SELECT formatReadableSize(sum(data_compressed_bytes))   AS compressed,
          formatReadableSize(sum(data_uncompressed_bytes)) AS uncompressed,
          round(sum(data_uncompressed_bytes) / sum(data_compressed_bytes), 1) AS ratio
   FROM system.parts WHERE database = 'ocsf' AND active"
```

## Stopping / resetting

```sh
docker compose down              # stop, keep data
rm -rf clickhouse_data            # wipe persisted ClickHouse state
```
