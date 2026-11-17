-- Portfolio 1 - Bulk data: 62,000 preservation_event rows (the fact table)
-- Student: Chiamaka Ozurumba (2026/A/MIT/1005)
-- Method: set-based INSERT with generate_series; dates cover history (2024 onwards)
-- through the next 14 days from CURRENT_DATE. Operator names are gender-matched.
\set ON_ERROR_STOP on
BEGIN;

TRUNCATE preservation_event RESTART IDENTITY;

INSERT INTO preservation_event (asset_id, action, event_date, operator, outcome, notes)
SELECT
   (g % 40) + 1,                                  -- cycle through 40 seeded assets
   (CASE g % 5
      WHEN 0 THEN 'INSPECTION'::preservation_action
      WHEN 1 THEN 'MIGRATION'
      WHEN 2 THEN 'RESTORATION'
      WHEN 3 THEN 'REPAIR'
      ELSE 'DISPOSAL' END),
   CURRENT_DATE - 686 + (g % 700)::int,           -- 700-day window incl. next 14 days
   CASE (g % 12)
      WHEN 0 THEN 'Chiamaka Ozurumba'
      WHEN 1 THEN 'Emeka Nwosu'
      WHEN 2 THEN 'Ngozi Okoye'
      WHEN 3 THEN 'Tunde Bakare'
      WHEN 4 THEN 'Adaeze Eze'
      WHEN 5 THEN 'Musa Abdullahi'
      WHEN 6 THEN 'Zainab Bello'
      WHEN 7 THEN 'Daniel Okafor'
      WHEN 8 THEN 'Folake Adeyemi'
      WHEN 9 THEN 'Segun Adeyemi'
      WHEN 10 THEN 'Aisha Mohammed'
      ELSE 'Chidi Obi' END,
   CASE (g % 4)
      WHEN 0 THEN 'PASSED'
      WHEN 1 THEN 'PASSED WITH NOTES'
      WHEN 2 THEN 'FLAGGED'
      ELSE 'COMPLETED' END,
   CASE WHEN g % 9 = 0 THEN 'Re-inspect in 90 days' ELSE NULL END
FROM generate_series(1, 62000) AS g;

COMMIT;

SELECT 'preservation_event=' || count(*) FROM preservation_event;
SELECT 'date_range=' || min(event_date) || ' .. ' || max(event_date) FROM preservation_event;
SELECT 'rows_in_next_14_days=' || count(*) FROM preservation_event WHERE event_date > CURRENT_DATE;
