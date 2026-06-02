# You Baby Studio — Qatar (Doha) Inventory · HANDOFF

> Read this first. Continuation notes for loading the Qatar/Doha inventory into the platform.

## What this project is
- Single-file app: `index.html` (React + Babel + supabase-js via CDN). Deployed via **GitHub Pages from `main`** → https://pp-ybs.github.io/youbaby-inventory/ . Dev branch: `claude/busy-knuth-lawXM` (develop there, then merge to `main` to publish).
- Backend: **Supabase project "Inventory YBS"**, id `ahysgpjnhldhdeinymrd`, URL `https://ahysgpjnhldhdeinymrd.supabase.co`. Use the **Supabase MCP** for all DB work (`execute_sql`, `apply_migration`).
- Two data domains:
  - `themes` table — legacy DXB/AD catalogue (original app screens). Don't touch unless asked.
  - **`doha_inventory` table** — the Qatar/Doha inventory. Shown in the app's **"Doha"** section (opens by clicking **Doha** under LOCATIONS in the sidebar). This is what we're actively building.

## `doha_inventory` schema (text PK)
`id, location('Doha'), category, source_sheet, slot_no, name, item_type, gender, measurement, quantity, remarks, notes, outfit_note, photo, outfit_photo, extra_photos(jsonb [{p,n}]), condition, times_used, on_website, created_at, updated_at`
- `category`: Maternity / Infant / Cake Smash / Newborn (these are the section groups; PLAN order in code).
- `item_type`: setup / outfit / fabric/background / prop / accessory / backdrop / other.
- `photo`, `outfit_photo`, and `extra_photos[].p` are **full Supabase Storage URLs** (`…/storage/v1/object/public/app/qatar/<file>`).
- **`doha_outfit_links(setup_id, outfit_id)`** — M:N links; setup cards show linked outfit thumbnails.
- RLS: `doha_inventory` and `doha_outfit_links` = **authenticated only** (correct, keep).

## ID scheme (continue per category — find current max)
`QA-MA-###` Maternity · `QA-IN-###` Infant · `QA-CS-###` Cake Smash · `QA-NB-###` Newborn · `QA-OF-###` standalone infant outfits. (`QA-BD-*` printed backdrops were merged into Maternity.)

## Data conventions
- **Names → Title Case** (initcap, normalise `-`→` – `). Fix typos `Flappy`/`Fluppy` → `Fluffy`.
- Typical sheet layout: **B = THEME PHOTO (setup)**, **C = OUTFIT** (sometimes a photo, sometimes text), other columns = size/qty/remarks/notes.
  - setup photo ← col B image. outfit photo ← col C image. If C is text → `outfit_note`.
  - A row with **only** an outfit photo (no setup photo) → `item_type='outfit'`.
  - Extra/variant photos (e.g. "basket a bit different" + a photo in the REMARKS column) → append to `extra_photos` as `{p:<url>, n:<comment>}`.
- **gender**: map BOY→Boy, GIRL(S)→Girl, both→Neutral. Newborn sheets usually have **no gender column → leave ''** (owner fills later). Don't invent gender.
- Outfit lists (header `Outfit/Photo/pc/note`): photo in col C; B is a label ("OUTFIT AVAILABLE"=generic → name "… Outfit N"; meaningful labels like "headband"→accessory, "camel/teddy"→prop).

## Parsing workbooks (xlsx)
- A source file is usually a **multi-sheet workbook** — one tab per session type (Maternity / Infant / Cake Smash / Newborn / outfit lists / accessories). **Iterate ALL worksheets**, don't assume one sheet.
  - Map each sheet → category by its **sheet name** (read names from `xl/workbook.xml` + `xl/_rels/workbook.xml.rels`). Show the owner the sheet→category/type mapping and confirm before bulk insert if any tab is ambiguous.
  - Detect layout per sheet from its header row: setups sheet (`THEME PHOTO`/`OUTFIT` cols), outfit list (`Outfit/Photo/pc/note`), accessories/toys (`WRAP/BACKDROP`/`TOYS`...).
- Images are anchored per sheet: worksheet `xl/worksheets/sheetN.xml` → its `_rels` → `xl/drawings/drawingN.xml`; in the drawing, `<xdr:from><xdr:col>/<xdr:row>` (0-indexed: col1=B, col2=C, col5=F…) + drawing `_rels` → media file. Cells via `sharedStrings` + each `sheetN.xml`. (Map each sheet to ITS own drawing/rels — don't hardcode `drawing1`.)

## PHOTOS — direct to Supabase Storage (NEW pipeline)
The environment now has **`SUPABASE_SERVICE_KEY`** (env var) and network allows **`*.supabase.co`**. So:
- **Upload an image straight to Storage** (no repo!):
  ```bash
  curl -sS -X POST \
    "https://ahysgpjnhldhdeinymrd.supabase.co/storage/v1/object/app/qatar/<FILE>" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_KEY" \
    -H "x-upsert: true" \
    -H "Content-Type: image/png" \
    --data-binary @"<localfile>"
  ```
  Public URL to store in DB: `https://ahysgpjnhldhdeinymrd.supabase.co/storage/v1/object/public/app/qatar/<FILE>`
- **Do NOT commit images to the repo anymore.** Repo stays code-only.
- **Source files from the owner**: she uploads the original **xlsx (with photos)** into Storage bucket `app`, folder **`source/`**. To process:
  1. List: `select name from storage.objects where bucket_id='app' and name like 'source/%';` (Supabase MCP).
  2. Download each: `curl -sS "https://…/storage/v1/object/public/app/source/<f>" -o /tmp/x.xlsx` (or add `-H "Authorization: Bearer $SUPABASE_SERVICE_KEY"` if bucket private).
  3. Parse → extract photos → upload photos to `app/qatar/…` (curl above) → insert rows (Supabase MCP) → repoint names/links.

## At session start — verify the new setup
1. `printf %.8s "$SUPABASE_SERVICE_KEY"` → non-empty (key present).
2. `curl -s -o /dev/null -w "%{http_code}\n" https://ahysgpjnhldhdeinymrd.supabase.co/storage/v1/object/public/app/qatar/QA-BD-001.png` → expect **200** (network + storage OK).
3. If either fails → fall back to repo-transit (commit images to `qatar/`, then they're served by Pages) and tell the owner the env settings didn't take effect.

## App behaviour (already built)
- "Doha" section: grouped by category; filters = **search / type / gender / age (Infant only)**. Card click → edit drawer (name, type, gender, size, qty, condition, times-used, **photo upload to Storage**, outfit photo, outfit note, **link outfits↔setups**, attached photos). Card image uses `photo` URL directly; edit modal shows full image.
- In-app **Upload** button already uploads to Storage `app/images/…` (bucket policy: public read, authenticated write).

## Cleanup / housekeeping
- Old bulk photos were migrated from the repo into Storage; repo images removed from the working tree. `.git` history still holds old image blobs (~545MB) — harmless to the live site, under GitHub limits; only do a history purge (force-push) if the owner explicitly asks.
- A temporary edge function `migrate-photos` (verify_jwt=false) was used for the one-time repo→Storage migration. **Delete it** once direct uploads are confirmed working (it's no longer needed).

## Publish flow
Edit `index.html` on `claude/busy-knuth-lawXM` → commit → push → merge to `main` → push `main` (GitHub Pages rebuilds in ~1–5 min; tell owner to hard-refresh / use `?fresh=N`).
