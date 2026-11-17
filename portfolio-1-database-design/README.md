# Portfolio 1 — Database Design (7 marks)

**Student:** Chiamaka Ozurumba (2026/A/MIT/1005)

A 3NF schema for the National Digital Media Archive (NDMA), Lagos.

## Files

| File | Purpose |
| --- | --- |
| `01_schema.sql` | 15 tables, 10 enums, CHECKs, UNIQUEs, FKs, 3 triggers |
| `02_indexes.sql` | 33 indexes (B-tree, partial, unique) each with a reason |
| `03_seed_data.sql` | Realistic Nigerian seed rows (roles, users, collections, creators, formats, locations, holders, tags, 40 assets, copies, licences, loans) |
| `04_bulk_data.sql` | 62,000 `preservation_event` rows via `generate_series` (history + next 14 days) |
| `05_constraint_tests.sql` | 10 tests that fail on the intended constraint + 1 control |

## Tables (15)

`role`, `users`, `archive_collection`, `creator`, `asset_format`, `media_asset`, `asset_contributor`, `subject_tag`, `asset_tag`, `storage_location`, `asset_copy`, `licence_holder`, `licence`, `loan`, `preservation_event`.

## Constraints used

- Primary keys on every table; composite PKs on junction tables.
- Foreign keys with `ON DELETE CASCADE` where children are owned.
- `CHECK` on regexes (collection code, barcode, email), numeric ranges (`duration_sec > 0`, `capacity > 0`, `fee_naira >= 0`), date order (`end_date >= start_date`, `end_at > start_at`).
- `UNIQUE` on `role.name`, `archive_collection.code`, `asset_format.name`, `licence_holder.name`, `storage_location.code`, `asset_copy.barcode`.
- Partial unique indexes: `ux_asset_checksum` (non-null checksums), `ux_loan_active` (only APPROVED/ACTIVE loans per copy).
- Enumerations for status, medium, role, licence type, loan status, preservation action, contributor role.
- Triggers: `enforce_checksum_for_archived` (asset cannot be ARCHIVED without a checksum), `sync_copy_availability` (copies marked unavailable while loaned), `enforce_asset_format_medium` (asset medium must match its format medium).

## Password handling

User passwords are never stored in plain text. `03_seed_data.sql` hashes each password with `pgcrypto`'s `crypt(pw, gen_salt('bf'))` (Blowfish-based bcrypt).

## Bulk load

`04_bulk_data.sql` truncates `preservation_event` then inserts 62,000 rows in one set-based statement. Dates span `CURRENT_DATE - 686` to `CURRENT_DATE + 13`, covering history plus the next 14 days. Operator names are gender-matched Nigerian names drawn from the seed `users`.

## Constraint tests

Each test wraps its own data creation in a `DO $$ ... EXCEPTION ... $$` block and raises `PASS` when the intended constraint fires, `FAIL` otherwise. No test depends on seed rows the bulk load might remove. Run order: schema, indexes, seed, bulk, tests.

## Note

This portfolio was drafted with AI assistance and will be tested and corrected before submission.
