#!/usr/bin/env bash
# Portfolio 5 - Streaming replica setup on port 5433 (Ubuntu, PostgreSQL 16)
# Student: Chiamaka Ozurumba (2026/A/MIT/1005)
# Builds a hot-standby replica of the primary cluster in one script.
set -euo pipefail

PG_BIN=/usr/lib/postgresql/16/bin
REPLICA_DATA=/var/lib/postgresql/16/replica
REPL_PORT=5433
REPL_USER=replicator
REPL_PASSWORD=repl_pwd_change_me
HBA=/etc/postgresql/16/main/pg_hba.conf

echo "[replica] create replication role on primary (idempotent)"
sudo runuser -u postgres -- psql -d postgres -v ON_ERROR_STOP=1 <<SQL
DO \$\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${REPL_USER}') THEN
      CREATE ROLE ${REPL_USER} LOGIN REPLICATION PASSWORD '${REPL_PASSWORD}';
   END IF;
END \$\$;
SQL

echo "[replica] write replication wal settings to a conf.d snippet"
sudo tee /etc/postgresql/16/main/conf.d/replication.conf >/dev/null <<EOF
wal_level = replica
max_wal_senders = 10
max_replication_slots = 10
listen_addresses = 'localhost'
EOF

echo "[replica] insert replication/trust lines at TOP of pg_hba.conf (idempotent)"
sudo sed -i '/replicator/d' ${HBA}
sudo sed -i '1i local   replication    replicator                     trust' ${HBA}
sudo sed -i '1i host    replication    replicator    127.0.0.1/32    trust' ${HBA}
sudo sed -i '1i host    replication    replicator    ::1/128         trust' ${HBA}

echo "[replica] restart primary to apply wal/hba settings"
sudo pg_ctlcluster 16 main restart

echo "[replica] stop any running replica on ${REPLICA_DATA}"
sudo runuser -u postgres -- ${PG_BIN}/pg_ctl -D ${REPLICA_DATA} stop -m fast || true

echo "[replica] recreate replica data directory and chmod 700"
sudo rm -rf ${REPLICA_DATA}
sudo mkdir -p ${REPLICA_DATA}
sudo chown postgres:postgres ${REPLICA_DATA}
sudo chmod 700 ${REPLICA_DATA}

echo "[replica] run pg_basebackup (PGPASSWORD passed, trust auth in effect)"
sudo runuser -u postgres -- env PGPASSWORD=${REPL_PASSWORD} ${PG_BIN}/pg_basebackup \
    -h 127.0.0.1 -p 5432 -U ${REPL_USER} -D ${REPLICA_DATA} -Fp -Xs -P -R

echo "[replica] write minimal postgresql.conf for the replica"
sudo tee ${REPLICA_DATA}/postgresql.conf >/dev/null <<EOF
# Minimal replica config (Portfolio 5)
listen_addresses = 'localhost'
port = ${REPL_PORT}
hot_standby = on
wal_level = replica
max_wal_senders = 10
EOF

echo "[replica] copy pg_hba.conf and pg_ident.conf from primary into replica data dir"
sudo cp /etc/postgresql/16/main/pg_hba.conf   ${REPLICA_DATA}/pg_hba.conf
sudo cp /etc/postgresql/16/main/pg_ident.conf ${REPLICA_DATA}/pg_ident.conf
sudo chown postgres:postgres ${REPLICA_DATA}/pg_hba.conf ${REPLICA_DATA}/pg_ident.conf

echo "[replica] start replica on port ${REPL_PORT} with pg_ctl"
sudo runuser -u postgres -- ${PG_BIN}/pg_ctl -D ${REPLICA_DATA} -o "-p ${REPL_PORT}" -l ${REPLICA_DATA}/replica.log start

echo "[replica] wait for replica to accept connections"
for i in $(seq 1 20); do
    if sudo runuser -u postgres -- psql -p ${REPL_PORT} -d postgres -tAc "SELECT 1" 2>/dev/null | grep -q 1; then
        echo "[replica] is up on port ${REPL_PORT}"
        break
    fi
    sleep 1
done

echo "[replica] done. primary=5432 replica=${REPL_PORT}"
