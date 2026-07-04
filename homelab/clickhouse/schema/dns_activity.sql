CREATE TABLE ocsf.dns_activity
(
    `activity_id`   Nullable(Int64),
    `activity_name` Nullable(String),
    `class_name`    Nullable(String),
    `class_uid`     Nullable(Int64),
    `count`         Nullable(Int64),
    `metadata` Tuple(
        product Tuple(
            name        Nullable(String),
            vendor_name Nullable(String)),
        profiles Array(Nullable(String)),
        version  Nullable(String)),
    `query` Tuple(
        class    Nullable(String),
        hostname Nullable(String),
        type     Nullable(String)),
    `src_endpoint` Tuple(ip Nullable(IPv6)),
    `time` DateTime64(9)
)
ENGINE = ReplacingMergeTree
PARTITION BY toYYYYMM(time)
ORDER BY (time, query.hostname, query.type, src_endpoint.ip)
TTL toDateTime(time) + INTERVAL 365 DAY
SETTINGS allow_nullable_key = 1;
