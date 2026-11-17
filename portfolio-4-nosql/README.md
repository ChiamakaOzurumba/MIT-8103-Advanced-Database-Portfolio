# Portfolio 4 — NoSQL / MongoDB (7 marks)

**Student:** Chiamaka Ozurumba (2026/A/MIT/1005)

## Files

| File | Purpose |
| --- | --- |
| `01_setup_collections.js` | Drops and recreates three collections with `$jsonSchema` validators |
| `02_bulk_data.js` | Loads 53,000 documents (42,000 catalogue + 5,000 access_logs + 6,000 preservation_logs) |
| `03_aggregations.js` | Five aggregation pipelines |
| `04_index_demo.js` | Before/after index demo printing stage, `docsExamined`, `executionTimeMillis` |

## Run

```bash
mongosh mediaarchive --quiet portfolio-4-nosql/01_setup_collections.js
mongosh mediaarchive --quiet portfolio-4-nosql/02_bulk_data.js
mongosh mediaarchive --quiet portfolio-4-nosql/03_aggregations.js
mongosh mediaarchive --quiet portfolio-4-nosql/04_index_demo.js
```

Every script begins with `db = db.getSiblingDB("mediaarchive")`. The `use` helper is never used.

## Collections and validators

- **catalogue** — catalogue documents with `assetId`, `title`, `medium`, `status`, `collectionCode`, `acquiredAt`, `checksum`, `durationSec`, `contributors`. A `oneOf` validator requires `checksum` only when `status` is `ARCHIVED` (no `if/then/else`).
- **access_logs** — loan records with `copyBarcode`, `userId`, `status`, `startAt`, `endAt`. A `oneOf` validator requires `notes` only when `status` is `REJECTED`.
- **preservation_logs** — preservation events with `assetId`, `action`, `eventDate`, `operator`, `outcome`, `notes`. A `oneOf` validator requires `notes` only when `action` is `DISPOSAL`.

All validators use `oneOf` rather than `if/then/else`, as required.

## Bulk data

42,000 catalogue documents plus 5,000 access logs and 6,000 preservation logs (53,000 total, well above the 40,000 minimum, well below the 100,000 portfolio cap). Documents are inserted in 5,000-doc batches with `insertMany({ ordered: false })`. `NumberLong` values are constructed with string arguments, e.g. `NumberLong("42000")`. ARCHIVED catalogue docs and DISPOSAL preservation logs carry the fields required by the `oneOf` validators, so every document passes validation.

## Aggregation pipelines

1. **A1** — assets per collection with archived count (`$group` + `$cond`).
2. **A2** — top 5 assets by preservation event count (`$group` + `$lookup` join to `catalogue` + `$project`).
3. **A3** — monthly preservation event counts (`$dateToString` + `$group`).
4. **A4** — access log status distribution (`$group` + `$sort`).
5. **A5** — outcome breakdown per preservation action (compound `_id` group).

## Index demo

`04_index_demo.js` runs `db.runCommand({ explain: { find: "catalogue", filter: { collectionCode: "NOLLY" } }, verbosity: "executionStats" })` once with no index on `collectionCode` (COLLSCAN, ~42,000 docs examined) and again after `db.catalogue.createIndex({ collectionCode: 1 })` (IXSCAN, far fewer docs examined). The script prints `stage`, `docsExamined` and `executionTimeMillis` for each. Any prior index is dropped inside a `try/catch` so the BEFORE plan is reproducible.

## Note

Drafted with AI assistance and will be tested and corrected before submission.
