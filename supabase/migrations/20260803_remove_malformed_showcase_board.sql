-- 2026-08-03 — Remove the one malformed showcase board.
--
-- Board names must read "<Studio> · <Session> · <Kind>[ · <Gender>]", where Kind
-- is 'Themes & setups' or 'Outfits'. "Dubai · Newborn · Girls" skipped the Kind
-- segment, so it belonged to no gallery: the public page parses segment 3 as the
-- Kind, read "Girls" as one, and matched nothing. It held a single abandoned stub
-- section (default title "New section", no note, dyn=false, 0 items) created
-- 2026-06-03, so it rendered nothing — but it still prefix-matched the parent
-- scope "Dubai · Newborn" and cluttered the board list.
--
-- A sweep of all 60 boards found this to be the ONLY malformed one.
-- Backed up first; nothing else referenced it (0 item links).

create table if not exists showcase_malformed_bak_20260803 as
  select * from showcase_section
  where board = 'Dubai · Newborn · Girls';

delete from showcase_section_item
where section_id in (select id from showcase_section where board = 'Dubai · Newborn · Girls');

delete from showcase_section where board = 'Dubai · Newborn · Girls';
