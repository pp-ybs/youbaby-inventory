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
- **Item** = an individual physical thing. **Kinds:**
  - Outfit · Prop · Backdrop/Background · Wrap · Accessory
  - **Electronics** (e.g. camera, lens)
  - **Reusable** (consumables Leah uses/tracks daily)
  - Other

## 3. Entry hierarchy (what Leah picks, in order)
```
Type            → Theme | Item
 └ (if Item) Kind → Outfit | Prop | Backdrop | Electronics | Reusable | Accessory | Other
Location(s)     → Dubai | Abu Dhabi | Doha | Al Quoz   (multi-select, qty per branch)
Category        → Newborn | Infant | Sitter | Cake Smash | Maternity | (seasonal e.g. Christmas)
Gender          → Girl | Boy | Twins | Neutral
Size            → One size | (pick from size list)
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

## 8. Open points to confirm
1. Item kinds list (Outfit / Prop / Backdrop / Wrap / Electronics / Reusable / Accessory / Other) — complete?
2. Size — fixed picklist (per kind/category) or free text?
3. Are **Themes** also branch-specific (theme exists at certain studios), or are themes global and only Items carry locations?
4. Do reusables/electronics need a daily **usage log** (each use recorded), or just a running counter?

## 9. Build order (once approved)
1. Create schema (`item`, `item_location`, `theme_item`; extend `popularity` locations).
2. Rebuild the **Add wizard** in the exact hierarchy above.
3. QR/barcode generation + printable label.
4. Dynamic New/Popular + static tags in browse.
5. Migrate existing themes + Doha inventory into the new model.
6. One-page guide for Leah.
