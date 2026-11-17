-- Portfolio 1 - Indexes (33 indexes, each with a reason)
-- Student: Chiamaka Ozurumba (2026/A/MIT/1005)
\set ON_ERROR_STOP on

-- users
CREATE INDEX idx_users_role           ON users(role_id);                 -- FK join role -> users
CREATE INDEX idx_users_created        ON users(created_at);              -- chronological "recent users" report
CREATE UNIQUE INDEX ux_users_email_lc ON users (lower(email));            -- case-insensitive email uniqueness
CREATE INDEX idx_users_active         ON users(user_id) WHERE is_active;-- partial: list only active users fast

-- role
CREATE INDEX idx_role_name            ON role(name);                     -- enum lookup by name

-- archive_collection
CREATE INDEX idx_collection_parent    ON archive_collection(parent_collection_id); -- recursive hierarchy walk
CREATE INDEX idx_collection_name      ON archive_collection(name);       -- name search
CREATE INDEX idx_collection_active    ON archive_collection(collection_id) WHERE is_active; -- active only

-- creator
CREATE INDEX idx_creator_type         ON creator(creator_type);          -- PERSON vs ORGANISATION filter
CREATE INDEX idx_creator_name         ON creator(full_name);             -- name search
CREATE UNIQUE INDEX ux_creator_email  ON creator (lower(email)) WHERE email IS NOT NULL; -- partial unique email

-- asset_format
CREATE INDEX idx_format_medium        ON asset_format(medium);           -- list formats per medium
CREATE INDEX idx_format_obsolete      ON asset_format(format_id) WHERE is_obsolete; -- partial: obsolete formats

-- media_asset
CREATE INDEX idx_asset_collection     ON media_asset(collection_id);     -- FK join
CREATE INDEX idx_asset_format         ON media_asset(format_id);         -- FK join
CREATE INDEX idx_asset_status         ON media_asset(status);            -- status filter
CREATE INDEX idx_asset_medium         ON media_asset(medium);            -- medium filter
CREATE INDEX idx_asset_created        ON media_asset(created_at);        -- chronological report
CREATE INDEX idx_asset_title          ON media_asset(title);             -- title search
CREATE INDEX idx_asset_acquired       ON media_asset(acquired_at);       -- acquired-date range queries
CREATE UNIQUE INDEX ux_asset_checksum ON media_asset(checksum) WHERE checksum IS NOT NULL; -- partial unique checksum
CREATE INDEX idx_asset_archived       ON media_asset(asset_id) WHERE status = 'ARCHIVED'; -- partial: archived set

-- asset_contributor
CREATE INDEX idx_ac_asset             ON asset_contributor(asset_id);    -- list contributors of an asset
CREATE INDEX idx_ac_creator           ON asset_contributor(creator_id);  -- list assets by a creator

-- subject_tag
CREATE UNIQUE INDEX ux_tag_name       ON subject_tag (lower(name));        -- case-insensitive unique tag

-- asset_tag
CREATE INDEX idx_at_asset             ON asset_tag(asset_id);            -- tags of an asset
CREATE INDEX idx_at_tag               ON asset_tag(tag_id);              -- assets with a tag

-- storage_location
CREATE INDEX idx_loc_site             ON storage_location(site);         -- filter by site
CREATE INDEX idx_loc_city             ON storage_location(city);         -- filter by city

-- asset_copy
CREATE INDEX idx_copy_asset           ON asset_copy(asset_id);           -- copies of an asset
CREATE INDEX idx_copy_location        ON asset_copy(location_id);        -- copies at a location
CREATE INDEX idx_copy_kind            ON asset_copy(kind);               -- PHYSICAL vs DIGITAL
CREATE INDEX idx_copy_available       ON asset_copy(copy_id) WHERE is_available; -- partial: available copies

-- licence_holder
CREATE INDEX idx_holder_country       ON licence_holder(country);        -- filter by country

-- licence
CREATE INDEX idx_lic_asset            ON licence(asset_id);              -- licences of an asset
CREATE INDEX idx_lic_holder           ON licence(holder_id);             -- licences by a holder
CREATE INDEX idx_lic_window           ON licence(start_date, end_date);  -- date-window overlap queries
CREATE INDEX idx_lic_type             ON licence(licence_type);          -- filter by licence type

-- loan
CREATE INDEX idx_loan_asset           ON loan(asset_copy_id);            -- loans of a copy
CREATE INDEX idx_loan_user            ON loan(user_id);                  -- loans by a user
CREATE INDEX idx_loan_status          ON loan(status);                   -- status filter
CREATE INDEX idx_loan_window          ON loan(start_at, end_at);         -- date-window overlap queries
CREATE UNIQUE INDEX ux_loan_active    ON loan(asset_copy_id) WHERE status IN ('APPROVED','ACTIVE'); -- partial unique active loan

-- preservation_event
CREATE INDEX idx_pe_asset             ON preservation_event(asset_id);   -- events for an asset
CREATE INDEX idx_pe_action            ON preservation_event(action);     -- filter by action
CREATE INDEX idx_pe_date              ON preservation_event(event_date); -- date range queries
CREATE INDEX idx_pe_outcome           ON preservation_event(outcome);    -- filter by outcome

-- Summary report
SELECT 'indexes_created=' || count(*) FROM pg_indexes WHERE schemaname='public';
