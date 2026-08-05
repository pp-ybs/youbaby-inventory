-- 2026-08-03 — Remove 23 duplicate "· BoysGirls" showcase boards
--
-- WHAT HAPPENED
-- A customer link ended in "· BoysGirls" (someone building a boy-&-girl twins
-- link by hand). No such board existed — the real boards are "· Boys" and
-- "· Girls" separately — so the public page dead-ended on "This gallery is
-- being prepared". The workaround taken was to CREATE 23 boards literally named
-- "… · BoysGirls" and hand-copy 1226 item links into them.
--
-- WHY THEY HAD TO GO
-- 1. Redundant: the showcase resolver now expands a multi-gender scope onto the
--    real "· Boys" / "· Girls" boards, so twins links work without duplicates.
-- 2. Actively wrong: a parent-scope link (e.g. "Dubai · Newborn") prefix-matches
--    every child board, so customers saw every item TWICE.
-- 3. Guaranteed to drift: a new theme added to "· Boys" would never appear in
--    the hand-made copy, silently going stale.
--
-- SAFETY
-- Verified before deleting: of 1226 links / 771 distinct items in these boards,
-- ZERO existed only here — every one is still present in the real Boys/Girls
-- boards. Full backup kept in:
--   showcase_boysgirls_bak_20260803_sections  (103 rows)
--   showcase_boysgirls_bak_20260803_items     (1226 rows)

create table if not exists showcase_boysgirls_bak_20260803_sections as
  select * from showcase_section where board like '% · BoysGirls';

create table if not exists showcase_boysgirls_bak_20260803_items as
  select i.* from showcase_section_item i
  join showcase_section s on s.id = i.section_id
  where s.board like '% · BoysGirls';

delete from showcase_section_item
where section_id in (select id from showcase_section where board like '% · BoysGirls');

delete from showcase_section where board like '% · BoysGirls';
