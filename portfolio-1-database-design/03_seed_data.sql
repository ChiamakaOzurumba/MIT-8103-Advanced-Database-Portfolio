-- Portfolio 1 - Seed data (realistic Nigerian setting)
-- Student: Chiamaka Ozurumba (2026/A/MIT/1005)
-- All rows pass every constraint (enums, CHECKs, UNIQUEs, partial indexes, trigger).
\set ON_ERROR_STOP on
BEGIN;

-- roles
INSERT INTO role (name, description) VALUES
 ('ARCHIVIST','Catalogues and preserves assets'),
 ('LIBRARIAN','Handles loans and access requests'),
 ('ADMIN','System administrator'),
 ('RESEARCHER','External borrower');

-- users (password_hash from pgcrypto crypt(); never plain text)
INSERT INTO users (role_id, full_name, email, password_hash) VALUES
 (1,'Chiamaka Ozurumba','chiamaka.ozurumba@ndma.ng',  crypt('archivist-2026', gen_salt('bf'))),
 (1,'Emeka Nwosu',       'emeka.nwosu@ndma.ng',        crypt('archivist-2026', gen_salt('bf'))),
 (2,'Ngozi Okoye',       'ngozi.okoye@ndma.ng',        crypt('librarian-2026', gen_salt('bf'))),
 (2,'Tunde Bakare',      'tunde.bakare@ndma.ng',       crypt('librarian-2026', gen_salt('bf'))),
 (3,'Adaeze Eze',        'adaeze.eze@ndma.ng',         crypt('admin-2026',     gen_salt('bf'))),
 (3,'Musa Abdullahi',    'musa.abdullahi@ndma.ng',     crypt('admin-2026',     gen_salt('bf'))),
 (4,'Folake Adeyemi',    'folake.adeyemi@unilag.edu.ng', crypt('researcher-2026', gen_salt('bf'))),
 (4,'Segun Adeyemi',     'segun.adeyemi@unilag.edu.ng',  crypt('researcher-2026', gen_salt('bf'))),
 (4,'Aisha Mohammed',    'aisha.mohammed@buk.edu.ng',    crypt('researcher-2026', gen_salt('bf'))),
 (4,'Chidi Obi',         'chidi.obi@ui.edu.ng',          crypt('researcher-2026', gen_salt('bf'))),
 (1,'Zainab Bello',      'zainab.bello@ndma.ng',         crypt('archivist-2026', gen_salt('bf'))),
 (2,'Daniel Okafor',     'daniel.okafor@ndma.ng',        crypt('librarian-2026', gen_salt('bf')));

-- archive_collection (self-referencing hierarchy)
INSERT INTO archive_collection (collection_id, parent_collection_id, name, code) VALUES
 (1, NULL, 'NDMA Master Archive',          'NDMA-ROOT'),
 (2, 1,    'NTA Lagos Broadcasts',         'NTA-LAG'),
 (3, 1,    'Nollywood Film Collection',    'NOLLY'),
 (4, 1,    'Afrobeat and Highlife Audio',  'AFRO-HL'),
 (5, 2,    'NTA News Bulletins',           'NTA-NEWS'),
 (6, 2,    'NTA Drama Series',             'NTA-DRAMA'),
 (7, 4,    'Fela Kuti Catalogue',          'FELA'),
 (8, 4,    'Sunny Ade Catalogue',          'SUNNY-ADE')
ON CONFLICT (collection_id) DO NOTHING;
SELECT setval(pg_get_serial_sequence('archive_collection','collection_id'), 8, true);

-- asset_format
INSERT INTO asset_format (name, medium, is_obsolete) VALUES
 ('MP4-H264',       'VIDEO', false),
 ('ProRes 422',     'VIDEO', false),
 ('Betacam SP',     'VIDEO', true),
 ('WAV 24bit 96kHz','AUDIO', false),
 ('FLAC',           'AUDIO', false),
 ('Reel-to-Reel',   'AUDIO', true),
 ('TIFF 16bit',     'PHOTO', false),
 ('JPEG',           'PHOTO', false);

-- creators
INSERT INTO creator (creator_type, full_name, nationality, email) VALUES
 ('PERSON','Tunde Kelani','Nigeria',NULL),
 ('PERSON','Funke Akindele','Nigeria','funke.akindele@example.ng'),
 ('PERSON','Genevieve Nnaji','Nigeria','genevieve.nnaji@example.ng'),
 ('PERSON','Fela Anikulapo-Kuti','Nigeria',NULL),
 ('PERSON','King Sunny Ade','Nigeria',NULL),
 ('PERSON','Buchi Atuonwu','Nigeria',NULL),
 ('PERSON','Yemi Alade','Nigeria','yemi.alade@example.ng'),
 ('PERSON','Don Jazzy','Nigeria','don.jazzy@example.ng'),
 ('PERSON','Joke Silva','Nigeria','joke.silva@example.ng'),
 ('PERSON','Kunle Afolayan','Nigeria','kunle.afolayan@example.ng'),
 ('PERSON','TY Bello','Nigeria','ty.bello@example.ng'),
 ('PERSON','Burna Boy','Nigeria',NULL),
 ('ORGANISATION','NTA Lagos','Nigeria','studio@nta.ng'),
 ('ORGANISATION','Mavin Records','Nigeria','info@mavinrecords.com'),
 ('ORGANISATION','Surulere Film House','Nigeria','office@surulerefilm.ng'),
 ('ORGANISATION','Cool FM Lagos','Nigeria','studio@coolfm.ng'),
 ('ORGANISATION','Wazobia FM','Nigeria','studio@wazobiafm.ng'),
 ('PERSON','Ramsey Nouah','Nigeria','ramsey.nouah@example.ng'),
 ('PERSON','Omotola Jalade-Ekeinde','Nigeria','omotola.je@example.ng'),
 ('PERSON','Asa Bukola Elemide','Nigeria','asa.elemide@example.ng');

-- storage_location (Lagos districts)
INSERT INTO storage_location (code, site, city, capacity) VALUES
 ('IKEJA-1','Ikeja Main Vault','Lagos',5000),
 ('VI-1',   'Victoria Island Cold Store','Lagos',2000),
 ('SURU-1', 'Surulere Digital Library','Lagos',3000),
 ('YABA-1', 'Yaba Backup Site','Lagos',4000),
 ('IKEJA-2','Ikeja Offsite Mirror','Lagos',8000);

-- licence_holder
INSERT INTO licence_holder (name, country, contact_email) VALUES
 ('Nigeria Copyright Commission','Nigeria','info@ncc.gov.ng'),
 ('NTA Lagos Rights Office','Nigeria','rights@nta.ng'),
 ('Mavin Records Legal','Nigeria','legal@mavinrecords.com'),
 ('COSON (Copyright Society of Nigeria)','Nigeria','info@coson.gov.ng'),
 ('Surulere Film House','Nigeria','office@surulerefilm.ng'),
 ('Creative Commons Nigeria','Nigeria','info@creativecommons.ng');

-- subject_tag
INSERT INTO subject_tag (name) VALUES
 ('News'),('Drama'),('Music Documentary'),('Independence Day'),('Election'),
 ('Football'),('Lagos'),('Highlife'),('Afrobeat'),('Nollywood'),
 ('Documentary'),('Children'),('Religion'),('Education'),('Comedy');

-- media_asset (40 assets; ARCHIVED ones carry a checksum to satisfy the trigger)
INSERT INTO media_asset (collection_id, format_id, title, medium, status, duration_sec, checksum, acquired_at)
SELECT
   CASE (g % 7) + 2   -- parent collection ids 2..8
     WHEN 2 THEN 2 WHEN 3 THEN 3 WHEN 4 THEN 4 WHEN 5 THEN 5 WHEN 6 THEN 6 WHEN 7 THEN 7 ELSE 8 END,
   (g % 8) + 1,       -- format_id 1..8 (medium must match)
   CASE (g % 8) + 1
     WHEN 1 THEN 'News Bulletin ' || g
     WHEN 2 THEN 'Drama Episode ' || g
     WHEN 3 THEN 'Music Documentary ' || g
     WHEN 4 THEN 'Independence Footage ' || g
     WHEN 5 THEN 'Election Coverage ' || g
     WHEN 6 THEN 'Football Highlights ' || g
     WHEN 7 THEN 'Highlife Session ' || g
     ELSE 'Afrobeat Live ' || g END,
   CASE (g % 8) + 1
     WHEN 1 THEN 'VIDEO'::asset_medium WHEN 2 THEN 'VIDEO' WHEN 3 THEN 'VIDEO'
     WHEN 4 THEN 'AUDIO'::asset_medium WHEN 5 THEN 'AUDIO' WHEN 6 THEN 'AUDIO'
     WHEN 7 THEN 'PHOTO'::asset_medium ELSE 'PHOTO' END,
   CASE WHEN g % 3 = 0 THEN 'ARCHIVED'::asset_status
        WHEN g % 3 = 1 THEN 'CATALOGUED'::asset_status
        ELSE 'DRAFT'::asset_status END,
   600 + (g % 1800),
   CASE WHEN g % 3 = 0 THEN 'sha256-' || lpad(to_hex(g), 8, '0') || repeat('a',55) ELSE NULL END,
   DATE '2024-01-01' + (g % 700)
FROM generate_series(1, 40) AS g;

-- asset_contributor (link assets to creators with varied roles)
INSERT INTO asset_contributor (asset_id, creator_id, role)
SELECT a.asset_id, ((a.asset_id + g) % 20) + 1,
       (CASE (a.asset_id + g) % 6
          WHEN 0 THEN 'CREATOR' WHEN 1 THEN 'DIRECTOR' WHEN 2 THEN 'PRODUCER'
          WHEN 3 THEN 'PERFORMER' WHEN 4 THEN 'EDITOR' ELSE 'CINEMATOGRAPHER' END)::contributor_role
FROM media_asset a
CROSS JOIN generate_series(1, 2) g
ON CONFLICT DO NOTHING;

-- asset_tag (2 tags per asset)
INSERT INTO asset_tag (asset_id, tag_id)
SELECT a.asset_id, ((a.asset_id + g) % 15) + 1
FROM media_asset a
CROSS JOIN generate_series(1, 2) g
ON CONFLICT DO NOTHING;

-- asset_copy (60 copies: half PHYSICAL, half DIGITAL)
INSERT INTO asset_copy (asset_id, location_id, kind, barcode, is_available)
SELECT a.asset_id, (g % 5) + 1,
       CASE WHEN g % 2 = 0 THEN 'PHYSICAL'::copy_kind ELSE 'DIGITAL'::copy_kind END,
       'NDMA-' || lpad(a.asset_id::text,5,'0') || '-' || lpad(g::text,2,'0'),
       (g % 5 <> 0)
FROM media_asset a
CROSS JOIN generate_series(1, 3) g
LIMIT 60;

-- licence (one per archived/catalogued asset that is not draft)
INSERT INTO licence (asset_id, holder_id, licence_type, start_date, end_date, fee_naira)
SELECT a.asset_id, ((a.asset_id % 6) + 1),
       (CASE a.asset_id % 4 WHEN 0 THEN 'EXCLUSIVE' WHEN 1 THEN 'NON_EXCLUSIVE'
        WHEN 2 THEN 'CREATIVE_COMMONS' ELSE 'PUBLIC_DOMAIN' END)::licence_type,
       DATE '2024-01-01', DATE '2027-12-31',
       (a.asset_id % 20) * 50000
FROM media_asset a
WHERE a.status IN ('ARCHIVED','CATALOGUED')
LIMIT 25;

-- loan (a few loans; respect the partial unique index ux_loan_active)
INSERT INTO loan (asset_copy_id, user_id, status, start_at, end_at)
SELECT c.copy_id, ((c.copy_id % 8) + 5),
       (CASE c.copy_id % 4 WHEN 0 THEN 'RETURNED'::loan_status WHEN 1 THEN 'RETURNED'
        WHEN 2 THEN 'REQUESTED' ELSE 'APPROVED' END)::loan_status,
       now() - make_interval(days => (c.copy_id % 30)::int),
       now() + make_interval(days => (c.copy_id % 14)::int)
FROM asset_copy c
WHERE c.copy_id <= 15;

COMMIT;

SELECT 'role=' || count(*) FROM role;
SELECT 'users=' || count(*) FROM users;
SELECT 'collections=' || count(*) FROM archive_collection;
SELECT 'creators=' || count(*) FROM creator;
SELECT 'formats=' || count(*) FROM asset_format;
SELECT 'assets=' || count(*) FROM media_asset;
SELECT 'copies=' || count(*) FROM asset_copy;
SELECT 'licences=' || count(*) FROM licence;
SELECT 'loans=' || count(*) FROM loan;

-- Seed rows use explicit ids, so move every identity sequence past the largest id used.
DO $$
DECLARE r RECORD; m BIGINT;
BEGIN
  FOR r IN SELECT c.table_name, c.column_name, pg_get_serial_sequence(quote_ident(c.table_name), c.column_name) AS seq
           FROM information_schema.columns c
           WHERE c.table_schema = 'public' AND c.is_identity = 'YES' LOOP
    EXECUTE format('SELECT COALESCE(MAX(%I), 0) FROM %I', r.column_name, r.table_name) INTO m;
    PERFORM setval(r.seq, GREATEST(m, 1), m > 0);
  END LOOP;
END $$;
