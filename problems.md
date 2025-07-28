# Database Monitoring and Remediation Alerts

This document provides a comprehensive list of all database issues that our tool can detect, monitor, and remediate. Each alert comes with a brief description of the problem and is categorized by type. Currently, we support the following database systems:

## Supported Database Systems
- [ClickHouse](#clickhouse)
- [PostgreSQL](#postgresql)

## Table of Contents
- [ClickHouse](#clickhouse)
  - [Query Performance Issues](#clickhouse-query-performance-issues)
  - [Resource Constraints](#clickhouse-resource-constraints)
  - [Table and Data Issues](#clickhouse-table-and-data-issues)
  - [Replication and Cluster Issues](#clickhouse-replication-and-cluster-issues)
  - [Storage and Disk Issues](#clickhouse-storage-and-disk-issues)
  - [System Health](#clickhouse-system-health)
- [PostgreSQL](#postgresql)
  - [Query Performance Issues](#postgresql-query-performance-issues)
  - [Connection and Concurrency Issues](#postgresql-connection-and-concurrency-issues)
  - [Replication and High Availability](#postgresql-replication-and-high-availability)
  - [Security and Compliance](#postgresql-security-and-compliance)
  - [Maintenance and Vacuum Issues](#postgresql-maintenance-and-vacuum-issues)
  - [Data Integrity and Schema](#postgresql-data-integrity-and-schema)
  - [System Configuration and Monitoring](#postgresql-system-configuration-and-monitoring)
  - [Storage and WAL Issues](#postgresql-storage-and-wal-issues)

## ClickHouse

The following sections detail the alerts and problems supported for ClickHouse databases.

### ClickHouse Query Performance Issues

| Alert Name | Description |
|------------|-------------|
| Number of Concurrent Queries Increasing | Detects when the number of running queries exceeds the 99.0 percentile, indicating potential concurrency issues. |
| Query Running Since Minute | Identifies queries that have been running for more than a minute, which could indicate high load or inefficient query design. |
| Total Query Time High | Alerts when queries execute longer than the acceptable threshold, which may lead to performance degradation. |
| High Query Read Bytes | Detects queries that read an excessive amount of data, potentially causing network congestion or slow performance. |
| Query Pressure Building | Alerts when query pressure is building up in the system, indicating potential overload conditions. |
| Query Time High | Notifies when specific queries consistently take longer than expected to execute. |
| Data Changing Queries | Identifies queries that are modifying data at a high rate, which could impact system performance. |
| High QPS (Queries Per Second) | Alerts when the system is experiencing a high rate of queries that could impact performance. |

### ClickHouse Resource Constraints

| Alert Name | Description |
|------------|-------------|
| Low Disk Space | Alerts when available disk space falls below 20%, which could lead to write failures. |
| Low Memory | Detects when the system is experiencing memory pressure, which could lead to query failures or slow performance. |
| OS Wait | Identifies when processes are spending excessive time waiting for OS resources. |

### ClickHouse Table and Data Issues

| Alert Name | Description |
|------------|-------------|
| Large Table with No TTL | Detects tables with approximately 1 million rows without a TTL setting, which could lead to excessive disk usage. |
| Too Many Parts | Alerts when excessive data partitions overwhelm the system, leading to performance degradation and increased resource usage. |
| Data Issues | Identifies various data-related problems that could affect query performance or data integrity. |
| No Activity Table | Detects tables that haven't had any activity for an extended period, which might indicate unused resources. |
| Mutation | Alerts on long-running or stuck mutations that could impact performance. |

### ClickHouse Replication and Cluster Issues

| Alert Name | Description |
|------------|-------------|
| Replica Issues Detected | Identifies problems in ClickHouse replica status, including read-only replicas, expired sessions, or high future parts. |
| Distributed Query Stuck | Detects when distributed queries are stuck and not completing, potentially affecting cluster performance. |
| Read Only Remediation | Provides remediation steps when a ClickHouse node enters read-only mode. |
| Insert Problem Exists | Alerts when there are issues with insert operations that could lead to data inconsistency. |
| Insert Problem Read Only | Identifies insert problems specifically related to read-only mode. |
| Cluster Issues | Identifies various problems affecting the overall ClickHouse cluster health. |

### ClickHouse Storage and Disk Issues

| Alert Name | Description |
|------------|-------------|
| S3 Issues | Detects problems with S3 storage integration, which could affect data availability. |
| Too Many S3 Requests | Alerts when the system is making an excessive number of S3 requests, which could lead to throttling or increased costs. |

### ClickHouse System Health

| Alert Name | Description |
|------------|-------------|
| Collector Error | Identifies errors in the data collection process that could affect monitoring accuracy. |
| MLE (Memory Limit Exceeded) Issues | Detects problems with ClickHouse's Memory Limit Exceeded capabilities. |
| Uptime | Monitors system uptime and alerts on unexpected restarts or downtime. |
| FLW (Four Leter Word) | Keeper server details missing or incomplete. |

## PostgreSQL

The following sections detail the alerts and problems supported for PostgreSQL databases.

### PostgreSQL Query Performance Issues

| Alert Name | Description |
|------------|-------------|
| Long Running Queries | **Major Performance Issue** - Queries active more than the configured threshold may hog resources, block maintenance operations, and degrade overall database performance. |
| High Sequential Scan Ratio | **Minor Performance Issue** - A sequential-to-index scan ratio > 10 indicates queries read tables sequentially instead of by index, wasting I/O and CPU. |
| Temporary File Usage | **Major Performance Issue** - Disk-based temporary files appear when operations exceed work_mem. Large or frequent spills slow queries and risk filling disks. |
| Frequent Temporary Table Creation | **Major Performance Issue** - Excessive creation/drop of temporary tables inflates system catalogs and hammers disk with many small files, causing performance slowdowns. |
| Column Statistics Staleness | **Minor Performance Issue** - Stale column statistics arise when large tables (≥ 1M rows) have not been analyzed in over 24h. This skews the planner, causing inefficient execution plans and slow queries. |
| Buffer Cache Hit Ratio | **Major Performance Issue** - A hit ratio below 90% indicates frequent disk reads instead of memory hits, causing high I/O latency and degraded query performance. |

### PostgreSQL Connection and Concurrency Issues

| Alert Name | Description |
|------------|-------------|
| Connection Pool Exhaustion | **Critical Availability Issue** - Active sessions have reached ≥ 95% of max_connections, blocking new logins and risking outages. Common causes: connection leaks or absent pooling. |
| High Connection Usage | **Major Availability Risk** - Active PostgreSQL connections have exceeded 80% of the configured maximum, putting the system at risk of reaching its connection limit and causing application errors or outages. |
| Connection Usage Stats | Shows current active connections versus max_connections. If active connections approach the limit, new connections will be refused and performance may degrade (each connection uses memory). Excessive connections often indicate lack of pooling or a runaway application. |
| Deadlocks Detected | **Major Concurrency Issue** - A deadlock occurs when two or more transactions each hold a lock that the others need, forming a cycle so none can proceed. PostgreSQL resolves the situation by aborting one transaction, causing errors and rollbacks. |
| Lock Waiters Present | **Major Performance Issue** - Un-granted locks older than 30 seconds indicate blocking that can escalate into deadlocks, causing application timeouts and degraded performance. |
| Idle in Transaction | **Major Locking Issue** - Sessions with open transactions doing nothing hold locks and block vacuum, causing bloat and potential transaction ID wraparound. These can severely impact database performance and maintenance operations. |

### PostgreSQL Replication and High Availability

| Alert Name | Description |
|------------|-------------|
| Replication Lag High | Standby server is significantly behind the primary. Causes stale data reads on replicas and risks data loss during failover. |
| Replication Lag Details | This metric provides detailed replication lag stats from pg_stat_replication, including WAL byte lag and time lag. It is used to diagnose replication delay issues. |
| Standby Not Streaming | Standby is not streaming replication when it is not receiving WAL data from the primary. This might indicate that the standby is down, disconnected, or misconfigured. The standby will fall behind completely, which can threaten failover reliability and increase recovery time. |
| Standby Recovery Status | The function pg_is_in_recovery() indicates if the server is in standby (recovery) mode. If it returns false on a server expected to be a standby, the node is not running as a replica. This can mean the standby has been promoted or misconfigured, breaking replication. |
| Database in Recovery on Primary | **Critical Availability Issue** - A server expected to be primary is stuck in recovery/read-only. Writes fail, causing an outage. |
| Replication Slot WAL Accumulation | Replication slots retain WAL files needed by standby. If a standby is down or not consuming, WAL accumulates on the primary indefinitely. |
| Inactive Replication Slots | Inactive replication slots cause WAL (Write-Ahead Log) accumulation, filling disk space. |
| Hot Standby Feedback Disabled | **Critical Replication Issue** - A standby exists, but `hot_standby_feedback` is off; vacuum on the primary may cancel long-running standby queries. |
| WAL Replay Paused | The standby has been instructed to stop applying WAL records (possibly due to an admin action or conflict). While paused, no further transactions are applied on the standby. This can cause the standby to become stale and cause WAL accumulation. |
| WAL Replay Pause Status | This function returns whether a WAL replay pause is currently requested on a standby. If it returns true, the standby is paused and not applying WAL. Like WAL Replay Paused, this halts updates on standby, causing lag. |

### PostgreSQL Security and Compliance

| Alert Name | Description |
|------------|-------------|
| SSL Disabled | **Security/Compliance Issue** - SSL disabled leaves data in transit unencrypted, risking interception and compliance violations. |
| SSL Configuration | SSL/TLS encryption secures client/server connections. If ssl is disabled (ssl = off), database traffic is unencrypted and vulnerable to eavesdropping. Missing or misconfigured certificates can also prevent SSL connections. |
| Deprecated TLS Version | **Major Security Issue** - Connections using TLS 1.0 or 1.1 weaken encryption and violate modern security standards. |
| Weak Password Encryption | **Critical Security Issue** - When password_encryption is not scram-sha-256, new credentials are hashed with weaker algorithms like MD5, making them susceptible to cracking and credential theft. |
| Password Encryption Method | The password_encryption setting controls how new passwords are hashed. scram-sha-256 is a strong method, whereas md5 is older and less secure. If set to md5, new passwords will be stored with MD5 hashes, which can be vulnerable to cracking. |
| PostgreSQL Version | **Critical Upgrade Required** - Running a PostgreSQL release older than 15 forfeits current security patches, bug fixes, and performance improvements, leaving the database vulnerable to exploits and compliance failures. |

### PostgreSQL Maintenance and Vacuum Issues

| Alert Name | Description |
|------------|-------------|
| Autovacuum Disabled | **Critical System Maintenance Issue** - Autovacuum disabled means PostgreSQL's background vacuum/analyze workers are off. Dead rows accumulate, tables bloat, and transaction-ID wraparound risk rises. Impact ranges from severe performance degradation to database shutdown. |
| Autovacuum Workers Idle | **Major Maintenance Issue** - No autovacuum workers have been active for an extended period, risking table bloat and transaction-ID wraparound. |
| Vacuum Analyze Timing | **Minor Maintenance Issue** - Tables not autovacuumed in 24h risk bloat, stale stats, and transaction ID wraparound. Can escalate from Minor to Critical if left unresolved. |
| Transaction Wraparound Risk | **Critical Data Integrity Issue** - XID counter nearing 2 billion threatens forced shutdown and data loss if tuples aren't frozen. |
| Track Counts Disabled | **Critical Maintenance Issue** - track_counts disabled stops statistics collection, preventing autovacuum from scheduling maintenance. This risks table bloat and transaction-ID wraparound. |
| Track Counts Status | The track_counts setting enables the collection of table and index usage statistics (dead/inserted row counts). If it is disabled (track_counts = off), PostgreSQL will not collect dead row statistics, causing autovacuum to stop working properly. |

### PostgreSQL Data Integrity and Schema

| Alert Name | Description |
|------------|-------------|
| Tables Without Primary Key | **Minor Data Integrity Issue** - Tables lacking a PRIMARY KEY allow duplicates and hinder replication, ORM identity, and query performance. |
| Table Bloat Dead Tuples | **Major Storage Issue** - Table bloat occurs when many dead tuples accumulate, making the table larger than necessary. This wastes disk space, slows scans and index look-ups, and can exhaust storage. |
| Unused Indexes | **Info Efficiency Issue** - Indexes with zero scans waste disk and slow writes. Removing them reclaims space and improves modification speed. |
| Rollback Rate High | **Major Performance Issue** - A rollback rate > 10% signals many transactions are aborting instead of committing. This wastes CPU/I/O, hides application errors, and can stem from deadlocks, timeouts, or logic bugs. |

### PostgreSQL System Configuration and Monitoring

| Alert Name | Description |
|------------|-------------|
| pg_stat_statements Missing | **Info Tuning Issue** - The pg_stat_statements extension is absent, leaving DBAs without detailed query-level performance metrics. Database runs, but tuning is harder. |
| pg_stat_statements Threshold Exceeded | **Minor Performance Issue** - pg_stat_statements is nearing or exceeding its capacity (pg_stat_statements.max). New statements evict old ones, eroding visibility. No runtime failure, but performance insights degrade. |
| Logging Configuration | **Info Observability Issue** - When log_checkpoints is off or log_autovacuum_min_duration is -1, PostgreSQL does not record crucial maintenance activity (checkpoints and autovacuum cycles). This obscures performance diagnostics, delaying issue detection. |

### PostgreSQL Storage and WAL Issues

| Alert Name | Description |
|------------|-------------|
| WAL Archiving Failed | **Critical Backup Issue** - pg_stat_archiver shows recent failures; WAL files aren't archiving, threatening backups and risking disk full. |
| High FPI Ratio | **Major Performance Issue** - Full Page Images (FPI) constitute > 30% of WAL records, inflating WAL traffic, increasing I/O, and potentially causing replication lag on replicas. |
| Checkpoint Flooding Ratio | Checkpoint flooding refers to a situation where the number of WAL-triggered checkpoints (checkpoints_req) is high relative to time-based checkpoints (checkpoints_timed). A high ratio means the system is often forced to checkpoint due to WAL volume, which can cause I/O spikes and performance degradation. |

---

## Future Database Support

This document will be expanded as we add support for additional database systems, such as:
- MySQL
- MongoDB
- Redis
- And more...

Each database system will have its own section with specific alerts and remediation capabilities tailored to that platform.

---

This document provides a high-level overview of the alerts supported by our tool. Each alert includes built-in remediation steps that guide users through the process of resolving the identified issues, often including diagnostic queries, configuration adjustments, and best practices.