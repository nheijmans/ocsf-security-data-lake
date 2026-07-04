# ocsf-security-data-lake

A working open-source security data lake built on **OCSF**, **Tenzir**, and **ClickHouse**.
Ingests nginx HTTP logs, AWS CloudTrail, and Pi-hole DNS into one normalized, queryable store
that runs on a single VM — no SIEM license required.

This is a personal experiment — a "what if I just rebuilt this on open tooling?" project.
Feel free to fork it and try the same.

## Why this exists

Most security teams still pay SIEM bills that grow faster than their log volume, while data
engineering quietly solved this problem with columnar storage, open schemas, and cheap object
storage. This repo is a hands-on demonstration that the same building blocks work just as well
for security telemetry.

Three pieces do all the work:

- **[OCSF](https://schema.ocsf.io)** — Open Cybersecurity Schema Framework. One shape for cloud,
  network, and endpoint events, so a single SQL query works across every source.
- **[Tenzir](https://tenzir.com)** — the pipeline layer. A few lines of TQL parse raw logs into
  OCSF, with native `ocsf::derive` / `ocsf::cast` operators and conditional routing
  (e.g. CloudTrail `ConsoleLogin` → `ocsf.authentication`, `StartInstances` → `ocsf.api_activity`).
- **[ClickHouse](https://clickhouse.com)** — the hot store. MergeTree with ZSTD compression gives
  fast SQL over months of data; Parquet on object storage handles the cold tier.

## Architecture

```
┌──────────────┐
│ nginx access │──┐
└──────────────┘  │   ┌────────────────┐    ┌────────────────────────┐    ┌──────────┐
                  ├──▶│     Tenzir     │───▶│   ClickHouse           │───▶│  Grafana │
┌──────────────┐  │   │  TQL pipelines │    │  MergeTree + ZSTD      │    │  / SQL   │
│ AWS          │──┤   │  → OCSF        │    │  ocsf.http_activity    │    └──────────┘
│ CloudTrail   │  │   └────────────────┘    │  ocsf.api_activity     │
└──────────────┘  │                         │  ocsf.authentication   │
                  │                         │  ocsf.dns_activity     │
┌──────────────┐  │                         └────────────────────────┘
│ Pi-hole DNS  │──┘                                     │
└──────────────┘                                        ▼
                                                ┌──────────────┐
                                                │  Parquet/S3  │
                                                │  (cold tier) │
                                                └──────────────┘
```

## Repo layout

| Path | What it is |
|---|---|
| [`local_pipeline/`](local_pipeline/) | The single-VM POC. Start here. Tenzir + ClickHouse, three working pipelines, sample data included. |
| [`homelab/`](homelab/) | The "now do it on a real host" variant. Pi-hole DNS → Tenzir → ClickHouse → Grafana on a homelab server. |

## Quickstart

```sh
cd local_pipeline
docker compose up -d

# Wait for Tenzir to report healthy, then run a pipeline:
docker exec tenzir-node tenzir -f /pipelines/parse-cloudtrail.tql

# Query the result:
docker exec clickhouse clickhouse-client -u default --password tenzir -q \
  "SELECT activity_name, user.name, src_endpoint.ip FROM ocsf.authentication"
```

Full instructions in [`local_pipeline/README.md`](local_pipeline/README.md).

## License

[MIT](LICENSE). This is a POC — the ClickHouse password is `tenzir` in every config file.
Change it before pointing this at anything real.
