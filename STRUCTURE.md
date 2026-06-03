# You Baby Studio — Inventory Structure (PROPOSAL v1)

> Draft for review. This is the target structure for the whole inventory (all branches),
> the order Leah follows when adding, and how it maps to the database.
> Nothing here is built yet — confirm/adjust first.

## 1. Feasibility
Doable on the **current setup** (Supabase + this app) — **not** a new project. The DB already has
unfinished scaffold tables (`items`, `popularity`, `outfit_links`, `audit_log`). We evolve into a
clean schema and migrate existing data in (347 themes + 911 Doha items). Nothing is thrown away.

## 2. Top split: Theme vs Item
- **Theme** = a put-together look/setup we post on the website (e.g. "Jungle Cake Smash").
  A theme can be **composed of items** (this backdrop + this outfit + these props).
- **Item** = an individual physical thing. **Kinds (in scope now):** Outfit · Prop ·
  Backdrop/Background · Wrap · Accessory · Other.
  - **Electronics & Reusable** — same structure, added **later** (not in scope now).
- **Both Theme and Item carry locations** — a theme can exist in several studios too
  (same multi-location logic as items).

## 3. Entry hierarchy (what Leah picks, in order)
```
Type            → Theme | Item
 └ (if Item) Kind → Outfit | Prop | Backdrop | Electronics | Reusable | Accessory | Other
Location(s)     → Dubai | Abu Dhabi | Doha | Al Quoz   (multi-select, qty per branch)
Category        → Newborn | Infant | Sitter | Cake Smash | Maternity | (seasonal e.g. Christmas)
Gender          → Girl | Boy | Twins | Neutral
Size            → free text (e.g. "One size", "M–L", "9–12 months")
Details         → name, photo(s), condition, color/brand, notes
```
One card = one real thing. The **same dress in 3 studios = 1 card**, present in 3 locations
("multiplication presence").

## 4. Labels / QR
- Every item gets a short **code** (e.g. `YBS-000123`) = the value behind an auto-generated
  **QR / barcode**, printable as a sticker for the physical item.

## 5. Display categorization (for website / browsing)
- **Dynamic (system-decided):**
  - **New** — recently added (by `created_at`).
  - **Popular / Trending** — by how many times selected/booked (`times_selected` + monthly `popularity`).
- **Static (manual labels):** collections we assign by hand (e.g. "Editor's pick", "Eid", "Christmas").
- **Usage count** is stored and visible on each card (drives Popular + Leah's daily reusable tracking).

## 6. Database model (target)
- **`item`** — one row per real thing
  `id (uuid)`, `code` (barcode/QR, unique), `type` (theme|item), `kind` (item kinds; null for themes),
  `name`, `session_type` (category), `subcategory`, `gender` (girl|boy|twins|neutral), `size`,
  `color`, `brand`, `photo_url`, `extra_photos (jsonb)`, `condition`, `condition_notes`,
  `needs_attention`, `website_display`, `static_tags (text[])`, `usable_for (text[])`,
  `times_selected (int)`, `notes`, `created_at`, `updated_at`
- **`item_location`** — multi-branch presence (replaces hardcoded qty_dubai/qty_ad)
  `item_id`, `location` (dubai|abudhabi|doha|alquoz), `quantity`, `status`
  (available|booked|needs_attention|transferred), `booked_until` · PK (item_id, location)
- **`theme_item`** — theme composition · `theme_id`, `component_item_id`
- **`popularity`** — `item_id`, `year`, `month`, `location`, `bookings_count` (dynamic Popular)
- **`audit_log`** — `item_id`, `user_name`, `action`, `old_value`, `new_value`, `created_at`

## 7. How existing data folds in (later, after structure is approved)
- `themes` (347) → `type=theme`; `branches[]` → `item_location` rows; `display` → `website_display`;
  `selection_count` → `times_selected`.
- `doha_inventory` (911) → setups → `type=theme` or `item` by meaning; outfits/props/backdrops/
  accessories → `type=item` with `kind`; `location='Doha'` → `item_location`; `usable_for` kept;
  `on_website` → `website_display`; `times_used` → `times_selected`. IDs preserved as `code`.
- `doha_outfit_links` (21) → `theme_item`.

## 8. Decisions (locked)
1. **Kinds now:** setups/themes, outfits, backdrops, accessories, props, wraps. Electronics & Reusable later.
2. **Size = free text.**
3. **Themes are multi-location too** (same "available in these studios" logic as items).
4. **No usage log for now** — just the `times_selected` counter (drives dynamic Popular).

## 9. Build order
1. ✅ **Schema created** — `inv_item`, `inv_item_location`, `inv_theme_item` (RLS: authenticated). Live `themes`/`doha_inventory` untouched.
2. ⏭ **Add wizard** in the exact hierarchy above (Type → Kind → Location(s) → Category → Gender → Size → details) — this is what Leah uses to add.
3. QR/barcode generation + printable label.
4. Browse/edit on the new model; dynamic New/Popular + static tags.
5. Migrate existing themes (347) + Doha inventory (911) into the new model; retire old tables after verifying.
6. One-page guide for Leah.
