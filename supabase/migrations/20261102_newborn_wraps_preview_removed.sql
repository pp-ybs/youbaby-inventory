-- The "· Newborn · Wraps" review pages are withdrawn (owner, 2 Nov 2026: the
-- hanger photos of the fabric are not what clients should see — wraps are to be
-- shown in the newborn setup picker as wrapped babies, in many colours and
-- poses). Removes what 20261102_newborn_wraps_preview.sql made (and the Abu
-- Dhabi / Doha copies applied the same day). Idempotent.
delete from showcase_section_item where section_id in (select id from showcase_section where board like '% · Newborn · Wraps');
delete from showcase_section where board like '% · Newborn · Wraps';
