# PROJECT BRIEF — "People Map": a private, offline relationship map

> Paste this whole document into Claude. Build it in the order given in section 14, one small step at a time, and show me the working file after each step. Do not skip ahead and do not invent features that are not in this brief. Where this brief gives an exact value (hex, pixel size, number, wording), use it exactly.

---

## 1. Goal

I (Georgia) want a personal "people map": one picture of everyone I know and how they connect to me and to each other. I want to:

- see my whole network as a web, with every line a different colour for the kind of relationship;
- see at a glance how I rate each person's character (the circle colour);
- find who I should introduce to whom (one person offers what another needs);
- never lose touch (fading circles, a "drifting" list), and never miss a birthday or key date;
- remember gifts, how I met people, who introduced whom, favours owed either way, and event/interest tags (to copy a guest list);
- **new:** keep a character profile for each person and get a plain-English **risk level** for the connection (how much it could hurt me if this person turned out to be untrustworthy).

**Privacy is the whole point.** This file will hold sensitive opinions about real people. Nothing may leave my computer, and no AI may ever see the data. Treat section 2 as non-negotiable.

Deliverable: **one single self-contained file `people-map.html`** (HTML + CSS + JS inline). Vanilla JS only. No libraries, no frameworks, no build step, no CDN, no web fonts, no images from the internet.

## 2. Privacy and security requirements (non-negotiable)

1. **Single file, fully offline.** It must work when opened by double-click (`file://`) with Wi-Fi off. No `fetch`, no `XMLHttpRequest`, no `WebSocket`, no `<link>`/`<script src>`/`<img src>` to anything external, no service worker, no manifest, no analytics, no telemetry, no `eval`/`new Function`.
2. **Strict Content Security Policy** as the first thing in `<head>`:
   ```html
   <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data: blob:; connect-src 'none'; form-action 'none'; base-uri 'none'">
   <meta name="referrer" content="no-referrer">
   ```
   (`'unsafe-inline'` is needed only because everything is in one file.)
3. **Storage:** `localStorage` only, key `peoplemap.v1`. Data stays in this browser on this computer. A small badge in the toolbar says **"Saved only on this computer"** (with the prefix **"Locked with a password · "** when a password is set). If saving fails, the badge turns red: **"!! Can't save in this browser — use 'Save backup'"**.
4. **Optional password lock** using WebCrypto only:
   - Key derivation: PBKDF2, SHA-256, **300000 iterations**, random 16-byte salt.
   - Cipher: **AES-GCM 256**, fresh random 12-byte IV on every save.
   - What is stored when locked is only this envelope (all binary fields base64): `{"peoplemapEnc":1,"kdf":"PBKDF2-SHA256","iter":300000,"salt":"…","iv":"…","ct":"…"}`. No names, counts or anything readable may sit next to it in `localStorage`.
   - Password rules: at least 8 characters, typed twice, plus an "I understand" checkbox. The warning text must say plainly: **a forgotten password cannot be recovered.**
   - **Lock now** (button + key `L`): save, then wipe the in-memory data and clear the map and side panel from the DOM, and show a full-screen lock screen (password box, error line, Unlock button). Wrong password shows "Wrong password." and stays locked. A closed `<details>` named "I forgot my password" explains it can't be recovered and offers "Erase the locked copy" behind two confirmations.
   - Settings has Change password and Remove password (both ask for the current password first).
   - Starting the page when the stored data is an encrypted envelope must go straight to the lock screen, never render anything first.
5. **Backups:** "Save backup" downloads a JSON file named `people-map-backup-YYYY-MM-DD.json` (plain) or `people-map-backup-YYYY-MM-DD-encrypted.json` (same envelope as above, with its own backup password typed twice, min 8 chars). "Load backup" detects an envelope and asks for its password; asks for confirmation before replacing current data. The plain-backup dialog must say: *"This file contains your notes and character ratings in plain text. Use the encrypted option unless you keep it somewhere very safe."*
6. **No AI, no sharing.** No feature may call, suggest or integrate any AI. The birthday importer and everything else is plain code. No "share", "send", "sync" or "export to cloud".
7. **Never build the DOM from user text with `innerHTML`.** Use `textContent`/`createElement` (or escape every string). Loaded backups are untrusted input and must go through a `sanitize()` (section 4) before use.
8. **Corrupt data safety:** if the stored JSON can't be parsed, copy the raw text to `peoplemap.v1.broken`, start fresh, and tell me with a toast. Never silently overwrite.
9. **Saving:** debounce 250 ms after any change, plus immediate save on `visibilitychange` (hidden), `pagehide` and `beforeunload`. When locked, saves go through encryption (serialised, so two saves can't interleave).
10. "Copy guest list" and any other copy/export must **never** include ratings, risk, evidence or notes — names only.
11. Hover tooltips (`<title>`) on map circles must show the name only — no character or risk text (people can see my screen).

## 3. Tech and delivery notes for Claude

- Build as a downloadable `.html` file, not only as an in-chat preview. Previews inside chat apps often run in a sandbox with their own CSP and without `localStorage`; the app must still start and show the "can't save" badge instead of crashing if `localStorage` throws.
- Wrap all JS in one IIFE with `'use strict'`. Keep it readable: sections with comment headers (core/state, graph, panels, dialogs, boot, parser, risk).
- Map = one `<svg>`; layout = a small custom force simulation (no library).
- Test in a normal desktop browser (Chrome/Safari/Firefox, latest) and a phone-width window (breakpoint 820 px).

---

## 4. Data model (JSON)

One root object `S`, saved as JSON (this is also the plain backup format). Everything not listed here is dropped by `sanitize()`.

```jsonc
{
  "app": "people-map",
  "version": 3,
  "people": [Person, ...],            // people[0] is always "me"
  "links": [Link, ...],
  "types": [RelType, ...],            // relationship kinds (line colours)
  "hidden": { "family": true },       // line-type ids hidden by legend toggle
  "hiddenRatings": { "2": true },     // character ratings hidden by legend toggle
  "ratingLabels": { "0":"Not rated","1":"Can't trust","2":"Careful","3":"Okay","4":"Good","5":"Excellent person" },
  "favours": [Favour, ...],
  "customFlags": [ { "id":"cf1", "label":"Flaky with plans", "kind":"red" } ],
  "settings": {
    "myName": "Georgia",
    "accent": "amber",               // "amber" (#ffb000) | "cyan" (#00d1ff)
    "showRiskRings": true,
    "circleColourFrom": "rating",    // "rating" | "traitAverage"
    "birthdayOrder": "DMY"           // "DMY" | "MDY"  (last choice in the importer)
  },
  "lastBackup": "2026-10-20",         // ISO date or ""
  "nextCode": 20,                     // next P-code number
  "view": { "x":0, "y":0, "k":1 }     // pan/zoom
}
```

### Person
```jsonc
{
  "id": "p_ab12cd",                 // unique string
  "name": "Marcus",
  "isMe": false,
  "code": "P08",                    // "ME" for me, otherwise P01, P02…  (never reused)
  "note": "",
  "group": "Finance",               // small free-text tag
  "rating": 2,                      // 0..5  (0 = not rated). Drives circle colour.
  "offers": ["commodities","trading advice"],   // things they can help with
  "needs":  ["hiring"],                          // things they are looking for
  "x": 0, "y": 0, "vx": 0, "vy": 0, "pinned": false,
  "lastTalked": "2026-07-25",       // ISO date or ""
  "bday": { "m": 3, "d": 3, "y": 0 },   // y = 0 when year unknown; m=0 means no birthday
  "dates": [ { "id":"d1", "label":"Anniversary", "m":6, "d":14, "y":2019 } ],  // key dates; y may be 0
  "likes": "wine, linen shirts",
  "gifts": [ { "id":"g1", "date":"2025-12-01", "what":"Scarf" } ],
  "ideas": "a good fountain pen",   // gift ideas
  "metBy": "p_xxxxx",               // id of the person who introduced me ("" = none / met directly)
  "metHow": "Polo club dinner",
  "metDate": "2024-03-14",          // ISO or ""
  "events": ["polo","commodities"], // tags, matched case-insensitively
  "character": Character            // NEW — section 12 (absent on "me")
}
```

### Link (a line)
`{ "id":"l1", "a":"<personId>", "b":"<personId>", "type":"friend", "note":"", "strength":2 }` — `strength` 1 = loosely connected (thin), 2 = good, 3 = very close (thick). Lines are undirected. Two people may have several lines of **different** types, but never two of the same type ("They already have a line of that kind.").

### RelType
`{ "id":"friend", "name":"Friend", "color":"#4a90e2", "style":"solid" | "dashed" | "dotted" }`. Built-ins (colours are exact, see section 11): `family`, `friend`, `work`, `business` ("Investor / business"), `mentor`, `partner` ("Romantic / partner"), `introduced` ("Introduced by <myName>", dashed, can't be deleted), `metvia` ("Met through someone", dotted, can't be deleted, never stored as a real link — see section 6.9). I can add custom kinds, rename, recolour, hide, delete (except `introduced` and `metvia`).

### Favour
`{ "id":"f1", "from":"me", "to":"<personId>", "what":"Intro to bank", "date":"2026-09-01" }` or `from` = person and `to` = `"me"`. One side must always be `"me"`. `from:"me"` means **I** helped them; `to:"me"` means **they** helped me.

### sanitize() rules (run on every load, restore and import)
- Throw `"This does not look like a People Map backup."` if `people` or `links` is not an array.
- Exactly one `isMe` person, first in the array; create one (name = settings.myName) if missing.
- Clamp: rating 0–5, strength 1–3, dates must be valid (drop invalid), bday m 1–12 / d 1–31, strings trimmed and length-limited, arrays of strings de-duplicated.
- Drop links whose people don't exist or whose type is unknown; drop a `metBy` that points to nobody (or to themself); drop favours with a missing person.
- Make sure `introduced` and `metvia` types exist. Assign missing codes (`P01`… using `nextCode`). Fill default `character` (section 12) on every non-me person, clamp its numbers, drop unknown flag ids.
- Old versions (1, 2) must load: missing fields get defaults.

---

## 5. Screen layout

Full-viewport, no page scroll. Flex column:

1. **Header** (`#head`)
   - **Top line** (40 px high): left, a 7 px accent-coloured square then the title **PEOPLE MAP** (mono, 600, 11 px, letter-spacing .2em, uppercase); then the **stats bar**; at the far right a live **clock** (`2 NOV 2026  18:21:49`, mono 11 px, uppercase, updates every second).
   - **Stats bar**: bordered cells (min-width 88 px, 1 px left border `--line`), each with a 9 px uppercase label (letter-spacing .15em, muted) over a 16 px mono value (`#ececec`). Cells in order: **People** (excluding me), **Lines**, **Avg char** (average of ratings 1–5, ignoring unrated, 1 decimal, "–" if none), **Drifting**, **Bdays 30d** (value in accent colour), **Open favours**, **High risk** and **Critical** (new; values in `--danger` colour when > 0).
   - **Toolbar** row: the save badge; search box ("Search people…  ( / )"); flexible spacer; buttons **+ Add person** (primary, accent fill, black text), **Tidy up**, **Save backup**, **Load backup**, **Lock…**, **?**. A hidden `<input type=file accept=".json">` for loading.
2. **Main** = two columns:
   - **Stage** (left, fills remaining width): the SVG map on a near-black dot-grid, with overlays: **legend** (top-left), **readout** box (top-right of the stage, shown for the hovered/selected person), **web growth timeline** (bottom, hidden until it applies), **zoom buttons** (+, −, ⤢ fit; bottom-right) and a faint **hint** line bottom-left: "DRAG A CIRCLE TO MOVE IT · DRAG THE BACKGROUND TO PAN · SCROLL OR PINCH TO ZOOM · CLICK A CIRCLE TO EDIT".
   - **Side panel** `aside#panel` (right, width **450 px**): tab strip then a scrolling body. Tabs, in order: **People**, **Who should meet?** (count badge), **Upcoming** (count badge), **Events**, **Path**, **Favours**, **Risk** (count badge = High + Critical), **Settings**.
3. **Ticker** (footer, 26 px): scrolling line on the left, fixed key hints on the right (`/ Search   N New   Esc Close   ? Help`, keys in small bordered boxes).
4. Overlays: toast (bottom centre), modal (`#modal` with `#mbox`; width min(1040 px, 100%), narrow variant 520 px) and the lock screen.

On widths ≤ 820 px stack the panel under the map and make the stats bar scroll horizontally.

---

## 6. Features — exact behaviour

### 6.1 People
- **+ Add person** (or key `N`) opens the People tab with an add form: name (required; Enter submits), character picker (6 squares: 1–5 plus "Not rated"), group, **how connected** (a relationship-type select; creates a line to me), **how close** (strength select, see below), note, "can offer" and "needs" (comma-separated words). On submit the person appears near me with a gentle push, gets the next code, is selected and focused in the editor.
- Strength select text: `1 – loosely connected (thin line)`, `2 – good connection`, `3 – very close (thick line)`.
- **Person editor** with sub-tabs: **Basics**, **Character** (new, section 12), **Dates**, **Gifts**, **How we met**, **Favours**, **Lines**. "Me" only has Basics and Lines.
  - *Basics*: name, character picker, group, note, events/interest tags, **Last talked** date + **Talked today** button + the sentence "You last talked 3 months ago — drifting." (or "…— all good"), can offer, needs, **Pin in place** / **Unpin**, **Delete person**.
  - Deleting asks for confirmation; it removes the person's lines and favours and clears `metBy` on anyone introduced by them.
  - *Lines*: list of this person's lines (other person, type, strength) with edit/delete, plus an **add line** form (other person, type, strength, note).
- **Back** button returns to the list. The People tab list shows every person as a row: code chip in character colour, name, group, a tiny risk level tag (section 12), sorted by name; clicking selects + opens.
- The **me** circle is never deletable and has the code `ME`.

### 6.2 Typed, coloured lines with strength
- Each line is drawn in its type's colour. Width = `(1.5 + strength × 1.8) × 0.5` px (so ~1.65 / 2.55 / 3.45 px). Style: `dashed` → dash array `5 4`; `dotted` → `1 4`.
- If two people have several lines, draw them as gently curved parallel arcs, each offset ~22 px so none hides another.
- **Click a line** (invisible 14 px hit stroke) → opens an edit dialog (type, strength, note, delete). Click on a person → opens the editor. Click empty space → clears selection.
- Line colour guidance (warn, don't block): in Settings > Line colours, show a small warning when a chosen colour is within an RGB distance of 70 of any character-rating colour ("This looks like a character colour. Pick another so you don't confuse them.").

### 6.3 Character rating → circle colour
Each person has `rating` 0–5. In the terminal theme the circle is a **square** (corner radius 0) filled with the rating colour:

| rating | label (renamable) | fill |
|---|---|---|
| 0 | Not rated | `#5c5c5c` |
| 1 | Can't trust | `#c0504d` |
| 2 | Careful | `#c98a3a` |
| 3 | Okay | `#c9b84a` |
| 4 | Good | `#8cbf6a` |
| 5 | Excellent person | `#1f8f55` |

- "Me" is filled `#262626` with the label `ME`, stroke `#e8e8e8`.
- The code (e.g. `P08`) is drawn inside the square, bold, white (`#fff`) on dark fills; on ratings 3 and 4 use `#111`.
- Square size: half-width = `min(26, 16 + degree × 1.6) × 0.56`, where `degree` is the number of lines; "me" = `30 × 0.56`.
- Name below, mono 9.5 px, uppercase, `#b4b4b4`, with a 3 px dark halo (`#080808`) so it stays readable over lines; group below that, 8.5 px `#6c6c6c`.
- Settings > Character labels lets me rename the six labels.
- Setting "Circle colour from": **My rating** (default) or **Trait average** (rounded from the six trait scores when ≥ 3 traits are rated, else falls back to my rating).

### 6.4 Legend (top-left of stage)
- Title `★ KEY (CLICK TO HIDE)`. One row per relationship type: a 24 px × 2 px swatch in the line colour (dashed/dotted as the type), the name and a count `(5)`. Click = toggle that type hidden (row dims with strikethrough; lines disappear; people with no remaining visible line stay).
- A second block **CIRCLE COLOUR = CHARACTER**: one row per rating (small square swatch, `5 · Excellent person (4)` etc.). Click = hide/show all people with that rating (hidden people vanish with their lines).
- A third block **RISK** (section 12.9) with the **Show risk** toggle.
- A "show web growth slider" chip (6.12) and the small note: `FADED = NOT TALKED TO FOR 3+ MONTHS · PULSE = BIRTHDAY SOON / DRIFTING`.
- Legend background `rgba(10,10,10,.92)`, mono 11 px.

### 6.5 Click highlight
Click a person: that person and their direct neighbours stay at full strength, everyone else drops to opacity **.10** (`.dim`), the readout box shows, and the editor opens. Click a line: only that line and its two people stay lit. Esc or click on empty space clears it.

**Focus priority** (when several apply): search > selected event tag > path result > selected person > selected line.

### 6.6 Search
`/` focuses the search box. Matches (case-insensitive substring) on: name, code, note, group, offers, needs, event tags, likes, how-we-met. Matching circles get a dashed outline; all others dim to .10. **Enter** flies the view to the first match and selects it; **Esc** clears and blurs.

### 6.7 Drag, zoom, pan, tidy up, fit
- Drag a circle to move it; it becomes **pinned** (shows a tiny pin mark; stays put). Drag background to pan. Mouse wheel zooms around the cursor; pinch zooms on touch. Zoom limits **0.15 – 3.5**. A click is a drag only after moving > 4 px.
- Zoom buttons: `+` ×1.25, `−` ×0.8, `⤢` Fit.
- **Fit** (button, key `F`): fit all visible people into view with 5% padding, scale clamped 0.25–1.6, leaving a 230 px left margin for the legend on wide screens.
- **Tidy up** (button): **unpin everyone except me and re-run the layout** so the web re-spreads itself after I have dragged things around. (It never deletes or edits anything.)
- Force layout (tune, don't fancy): repulsion `70000 × spread² / d²` between all pairs (spread = 0.82), extra push when closer than `110 × spread`; spring length `(230 if the line touches me else 170) × spread − (strength−1) × 14`; damping 0.78; max speed 60 px/step; "me" pinned at the origin; a gentle pull to the centre; `alpha` decays ×0.985 per frame and the simulation sleeps below 0.03 (restart on drag/add/tidy). Run 500 silent steps on load so the map appears settled.

### 6.8 Who should meet? (offer/needs matching)
- Normalise words: lowercase, trim, and drop one trailing "s" if the word is longer than 4 letters (so "sponsors" = "sponsor").
- For every ordered pair (A, B) where A's `offers` share a word with B's `needs` and A and B are **not already connected by any line**, create a suggestion. Merge A→B and B→A for the same pair into one card listing both directions. Sort by the number of matching reasons, then by name.
- Card: `Alex  can offer: polo ⟶ Wei  needs: polo` with the matched words highlighted, a risk tag for each person (section 12.10 for the warning), and a **Mark introduced** button. Clicking either name selects that person on the map.
- **Mark introduced** adds an `introduced` line (strength 2, note `Introduced by <myName> (polo)`), and the pair disappears from the list. The tab badge shows the number of open suggestions.
- Empty state: "No obvious introductions yet. Add what people can offer and what they need."

### 6.9 How we met + introduced-by lines
- In *How we met*: "Introduced by" select (any other person), "How" free text, "Date met".
- If `metBy` is set, draw a **virtual** dotted `metvia` line (colour `#2bb3c0`, strength 1, spring +25 px longer) from the introducer to the person with the hover/click note `<introducer> introduced <myName> to <person>`. It is derived, not stored in `links`, and not directly editable (clicking it opens the person).
- The readout box and editor show "Met via Dr Lim (mentor)".

### 6.10 Last talked, fading, drifting list
- `days = today − lastTalked`. **Opacity:** 1 until 90 days; then it fades linearly down to **0.35** at 365 days (stays 0.35 after). No `lastTalked` = no fade, not counted as drifting.
- **Drifting** = `days ≥ 90`. A drifting circle gets a very slow grey pulse (`#8a8a8a`, 4.2 s).
- Header stat **Drifting** counts them. The Upcoming tab has a **Drifting** table (Name, Last talked as "3 mo", button **Talked today**) sorted longest first.
- Short time wording: `agoShort`: `Nd` under 100 days, `Nmo` under 700 days, otherwise `N.Ny`. Long: today / yesterday / `N days ago` (<14 d) / `N weeks ago` (<60 d) / `N months ago` (<700 d) / `N.N years ago`.

### 6.11 Birthdays and key dates, Upcoming 30/60/90
- Each person has one birthday (`bday`) plus any number of **key dates** (anniversary, "started company", etc.).
- **Upcoming tab:** range select **30 / 60 / 90 days** (default 30) and a table: **In** (`TODAY`, `TOMORROW`, `12d`), **Who**, **Detail** (`Birthday · turns 41` if year known, else `Birthday`; key dates show the ordinal `3rd Anniversary`). Under a birthday, show one muted line: the gift **idea** (first 70 chars) or else **likes**. Rows within 7 days are bold. Sorted by days then name. Click a row → opens that person (Gifts tab for birthdays, Dates tab for key dates).
- Next occurrence rule: today counts as 0 days; a **Feb 29** date falls on **Feb 28** in non-leap years.
- A birthday within **7 days** makes that circle pulse once every 2.6 s with an outline in the accent colour. Header stat **Bdays 30d** counts birthdays in the next 30 days.
- Top of the Upcoming tab: button **Paste birthdays from Notes…** (opens the importer, 6.18). Tab badge = number of items in the next 30 days.
- **Backup reminder** (a calm bar at the top of the People tab): shown when there are ≥ 4 people and no backup in the last 30 days: "You haven't saved a backup in N days. [Save backup]".

### 6.12 Gift notes
*Gifts* sub-tab: **Likes** (free text), **Gift ideas** (free text), and a gift log (date + what) with add/delete: "What I gave and when", newest first, so I never repeat a gift. The Upcoming birthday rows show the idea/likes line.

### 6.13 Web growth slider
- Needs at least 2 people with `metDate`. A chip in the legend ("show web growth slider") reveals a timeline bar at the bottom of the stage: a range 0–100 mapping the earliest `metDate` → today, a label showing the date (label "all time" at 100), and **Play** (steps +2 every 120 ms until 100).
- People with `metDate` after the cut-off hide (with their lines); people without `metDate` are always shown. Fits the view while playing is optional.

### 6.14 Path finder
*Path* tab: "From me to…" select (anyone). Compute the **shortest introduction chain** with Dijkstra from "me", using all lines **plus virtual `metvia` lines**; edge cost = `1 + (3 − strength) × 0.05` (so equally long paths prefer stronger lines). Result: summary `3 steps to reach Ana`, the names joined by ` → `, the sentence **"Ask Marcus to introduce you to Kenji, then Kenji to Ana."**, and a step list showing each hop with its relationship type label. Highlight the path on the map (dim everything else). "No route yet — add a line." if unreachable.

### 6.15 Favour balance
- *Favours* tab: a table per person: **They helped** (count of favours from them to me), **I helped** (count from me to them), **Balance**: `They owe you 2` / `You owe them 1` / `Even` / `No favours logged`. Net = I helped − they helped (positive → they owe me). "Open favours" = number of people with net ≠ 0 (header stat).
- Below: a log form (person, direction "I helped them" / "They helped me", what, date) and the list of all favours (newest first, each deletable). Same form lives in the person's *Favours* sub-tab.

### 6.16 Events and tags
- Each person's *events/interest tags* (comma-separated, e.g. `polo, gala 2026`). Case-insensitive.
- *Events* tab: tag chips with counts (click to select; click again or **Clear** to deselect). Selecting a tag dims everyone without it on the map and shows a table of the people who have it. **Copy guest list** puts the sorted plain names, one per line, on the clipboard (use `navigator.clipboard`, falling back to a hidden textarea + `execCommand('copy')`) and shows a toast "Copied 7 names". Guest list = **names only**.

### 6.17 Lock screen
Covered in section 2.4. Add: an optional "auto-lock after N minutes idle" setting (off by default; 1/5/15/30).

### 6.18 Birthday paste importer (plain code, no AI)
Purpose: I paste a messy list from Apple Notes and the app reads it without me retyping.

**Entry points:** Upcoming tab button and Settings > "Import birthdays". Opens a wide modal (sticky: clicking outside doesn't close it).

**Step 1 — paste:** a large textarea; a button **Try a messy example** (fills the `IMPORT_SAMPLE` below); radio **Day/month order: ● DMY (14/1 = 14 January)  ○ MDY (1/14 = 14 January)** (default from settings); button **Read my list**.

**Step 2 — review table** (nothing is saved yet): top summary `14 entries found · 11 look fine · 3 need a look · 2 lines skipped`; a day/month switch (re-reads the list; confirm first if I've edited rows); `Connect new people to <myName> as:` select (a relationship type, or "Don't connect"). Columns:

| Include | Original line | Name | Day | Month | Year | Match to | Status |
|---|---|---|---|---|---|---|---|

- Name, Day, Month, Year are editable. Editing a flagged row re-validates it live.
- **Match to**: a select with `+ New person`, or an existing person. Auto-match rule below. Ambiguous rows show `— pick one —` and cannot be included until picked. If matched, show `now: 3 Mar` or `same as saved` beneath.
- **Status** pill: `ok` (green) or `check` (red) with the reasons in plain words. **Flagged rows are tinted `rgba(229,100,92,.07)` and the Include box is disabled until fixed.**
- Button **Confirm import (N)** (N = included rows). Cancel discards everything.

**Commit:** matched person → update the birthday (if the new line has no year, keep the old year); `+ New person` → create a person at a random position near the centre, rating 0, with a strength-2 line to me of the chosen type. Then open the Upcoming tab and toast **"Imported: N updated, M new"**.

**Parsing rules (implement as a pure function `parseBirthdays(text, {order, today})` and test it):**

*Cleaning each line:* remove emoji; turn NBSP and tabs into spaces; collapse spaces; convert smart quotes to plain; en/em dashes between digits → `-`; strip ordinal suffixes (`3rd` → `3`, `1st`, `22nd`, `11th`); strip leading list markers (`-`, `–`, `—`, `•`, `*`, `+`, `>`, `#`, ✓ ✅ ☐ ☑, `1.` `2)` `(3)` `14.` — but only treat `N.`/`N)` as a marker if what is left still parses; "3. Mum 5 May" works, "14.1.2003 Wei" is a date).

*Skipped lines (not counted as entries):* empty lines; headings such as `Birthdays`, `BIRTHDAYS`, `List of birthdays`, `Bdays`, `Dates`, `Important dates`, `Name`/`Names`; bare 4-digit years.

*Month headings:* a line that is just a month (`March`, `March:`, `– March 2024`) sets a **context month** for the lines under it; there `14 Sam` or `Sam 14th` means 14 March. If such a line contains several numbers, flag it: "Several numbers: which one is the day?". A new heading replaces the context.

*Multiple entries on one line:* split on `;` or `|`; else on commas if **every** part has a date; else on `&`/`and`/`+` if every part has a date. (`Mum 3/3, Dad 5/4, Sam 12/6` = 3 entries; `Sam, Saturday 12th February` = 1.)

*Noise words stripped from the name:* `birthday`, `birthdays`, `bday`, `b-day`, `b'day`, `born`, `dob`, `date of birth`, `turns`, `turning`, weekday names (`Mon`…`Sunday`, `Sat`), parentheticals like `(turning 36)` / `(colleague)`, and connective words at the ends (`on`, `is`, `the`, `of`, `at`, `his`, `her`, trailing `'s`/`’s` possessive). Trailing/leading punctuation (`: - – — ( ) , .`) is trimmed. If the name is all lower-case, Title Case it (`sam tan` → `Sam Tan`); otherwise keep it as typed (`MUM`, `SAM`). Names keep accents and non-Latin text (`José`, `李明`). A leftover "Dr." stays (`Dr. Lim`). "Mark" must not become March ("Mar" inside a word is not a month); "Jan Smith", "Augustine", "Decker" are names, not months, when another month/number is present.

*Date patterns (try in this order, pick the best-scoring candidate: +4 if a name remains, +2 if a year is present):*
1. ISO `yyyy-mm-dd` (also with `/` or `.`).
2. Numeric `d/m`, `d/m/y` with separators `/ . -`. Year: 4 digits as is; 2 digits → `20yy` if ≤ the current 2-digit year, else `19yy` (so `/26` = 2026, `/27` = 1927, `/90` = 1990).
3. Day + month name: `14 jan`, `14-jan`, `14th of January`, `3rdmarch`, `3mar`, `march3`, `Sept.`; optional year as `'03`, `03`, `1990`, `, 1990`, or in brackets `Sam (1990) 12 Feb`.
4. Month name + day: `Jan 14`, `Feb 12th`, `Jan the 14th`, `December 3rd`.
Month names accepted: jan/january, feb/february, mar/march, apr/april, may, jun/june, jul/july, aug/august, sep/sept/september, oct/october, nov/november, dec/december.

*Day/month order for numeric dates:* default per the radio. If one number is > 12, swap automatically and note "Read as 14 Jan (the other order is not a real date)". If both ≤ 12 and unequal, note "Read as day/month" (or "month/day"). **Count evidence** across the whole list (lines where a number > 12 proves DMY or MDY). If the list **mixes** both styles the ambiguous rows are flagged: "Day/month order unclear: your list mixes styles". If the evidence points the other way from the radio, show a hint above the table: "Your list looks like month/day (for example 1/14). Try switching the order." Equal numbers (`7/7`) are never ambiguous.

*Validation (any failure → status `check`, with these messages):* "No date found", "No name found", "Month is not valid", "Day is not valid", "<Month> does not have N days" (Feb 29 allowed when the year is unknown or is a leap year), "Year N looks too early" (< 1900), "Year N is in the future", "That date is in the future" (full date later than today). Names with no date or dates with no name are shown (flagged) rather than silently dropped; lines with no letters and no digits (`??`) are skipped.

*Auto-match to existing people:* compare after lower-casing, stripping a leading `Example: `, titles ignored for scoring only, and these **synonyms** → mom/mother/mummy/mama/ma → `mum`; father/papa/daddy/pa/pop → `dad`; granny/grandma/nan/nana → `gran`; grandad/granddad/grandfather → `grandpa`; bro → `brother`; sis → `sister`. Score: exact 1.0; all tokens of the shorter name are in the longer 0.92 (0.88 if the *imported* name is the longer); per-token fuzzy: prefix (≥3 chars) 0.82, edit distance 1 on words ≥ 4 chars 0.80, distance 2 on words ≥ 7 chars 0.75; same first name only 0.70. Candidates = score > 0.5 sorted desc. **Auto-select** the best if ≥ 0.75; **ambiguous** (force a manual pick) if the top two are both ≥ 0.75 and within 0.10 of each other.

**`IMPORT_SAMPLE` (the "Try a messy example" text):**
```
🎂 Birthdays
- Mum - 3rd March
jan 14
14/1
• Sam bday 12 Feb
jess: 5/6
14.1.2003  Wei
3 mar Priya
march3 Nina
Ken 14/01/03
Dr lim — 8 Sept
Uncle Raj 22 Nov 1958
Ivy ?? sometime in spring
12) Omar 12/10
Tara 25/12
```
Expected read: heading skipped; Mum 3 Mar ok; `jan 14` and `14/1` → date but **no name → check**; Sam 12 Feb ok; Jess 5/6 → 5 Jun ok (note "Read as day/month"); Wei 14 Jan 2003 ok; Priya 3 Mar ok; Nina 3 Mar ok; Ken 14 Jan 2003 ok; Dr Lim 8 Sep ok; Uncle Raj 22 Nov 1958 ok; Ivy → **check: No date found**; Omar 12 Oct ok; Tara 25 Dec ok.

**Parser test table (default order DMY, "today" = 2 Nov 2026). Format: input → name, day, month, year, status.** Claude must make all of these pass.

| input | name | d | m | y | status |
|---|---|---|---|---|---|
| `Mum - 3rd March` | Mum | 3 | 3 | – | ok |
| `jan 14` / `14/1` / `3 mar` / `march3` | (none) | | | | check (no name) |
| `Sam bday 12 Feb` | Sam | 12 | 2 | – | ok |
| `jess: 5/6` | Jess | 5 | 6 | – | ok |
| `🎂 Sam 12/2` | Sam | 12 | 2 | – | ok |
| `• Priya - 1 Sept` / `- Priya 1st sept` | Priya | 1 | 9 | – | ok |
| `Tom's birthday 25 Dec` / `Chris’s birthday: 25 Dec` | Tom / Chris | 25 | 12 | – | ok |
| `Birthday: Tom 25 Dec` / `Tom BDAY 25/12` / `Tom b'day 25 Dec` | Tom | 25 | 12 | – | ok |
| `12 Feb Sam` / `12 Feb - Sam` / `Feb 12: Sam` / `Feb 12th Sam` / `12/02 Sam` / `Sam (12 Feb)` | Sam | 12 | 2 | – | ok |
| `Sam – 12 Feb` / `Sam — 12 Feb` / `Sam\t12 Feb` / `Sam    12    Feb` | Sam | 12 | 2 | – | ok |
| `sam tan 12 feb` | Sam Tan | 12 | 2 | – | ok |
| `Anne-Marie 3/5` / `Anne-Marie - 3 May` | Anne-Marie | 3 | 5 | – | ok |
| `Dr. Lim 5 May` | Dr. Lim | 5 | 5 | – | ok |
| `Auntie Lin - 1st of Sept` / `Auntie Lin on the 1st of September` | Auntie Lin | 1 | 9 | – | ok |
| `José 7 Aug` / `李明 7 Aug` | José / 李明 | 7 | 8 | – | ok |
| `Sam on 12 Feb` / `Sam is 12 Feb` | Sam | 12 | 2 | – | ok |
| `Mark 3 May` (not March) | Mark | 3 | 5 | – | ok |
| `Jan Smith 3 March` | Jan Smith | 3 | 3 | – | ok |
| `Jun 3 Sam` | Sam | 3 | 6 | – | ok |
| `Augustine 3 Aug` / `Decker 3 Dec` | Augustine / Decker | 3 | 8 / 12 | – | ok |
| `Sam 3rdmarch` / `Sam 3-mar` / `Sam march3` / `Sam 3mar` | Sam | 3 | 3 | – | ok |
| `Sam 3-mar-1990` | Sam | 3 | 3 | 1990 | ok |
| `Sam 12 Feb, 1990` / `Sam Feb 12, 1990` / `Sam Feb 12 1990` | Sam | 12 | 2 | 1990 | ok |
| `Sam 12 Feb '90` / `Sam 12 Feb 90` / `Sam (1990) 12 Feb` | Sam | 12 | 2 | 1990 | ok |
| `Sam 12 Feb '03` | Sam | 12 | 2 | 2003 | ok |
| `Sam 12 Feb (turning 36)` / `Sam 12 Feb - loves wine` / `Sam 12 Feb (colleague)` | Sam | 12 | 2 | – | ok |
| `Sam 12/02/90` / `Sam 12-02-90` / `Sam 12.2.90` / `Sam 12/02/1990` | Sam | 12 | 2 | 1990 | ok |
| `Sam 12/02/26` / `Sam 12/02/27` | Sam | 12 | 2 | 2026 / 1927 | ok |
| `Sam 1990-02-12` / `Sam 1990/02/12` | Sam | 12 | 2 | 1990 | ok |
| `Sam 14/1` and `Sam 1/14` (14 can't be a month, swapped) | Sam | 14 | 1 | – | ok |
| `Sam 12/13` (13 can't be a month) | Sam | 13 | 12 | – | ok |
| `Sam 29/2` (leap day, no year) / `Sam 29/2/1992` | Sam | 29 | 2 | – / 1992 | ok |
| `Sam 7/7` / `Sam 01/01` | Sam | 7 / 1 | 7 / 1 | – | ok |
| `Sam 5/6` (DMY) → 5 Jun; with order MDY → 6 May | Sam | 5 / 6 | 6 / 5 | – | ok |
| `Sam 31/2`, `Sam 30 Feb`, `Sam 31 Apr`, `Sam 31/11` | Sam | | | | **check** (month doesn't have that many days) |
| `Sam 29/2/1993` | Sam | 29 | 2 | 1993 | check (not a leap year) |
| `Sam 32/1`, `Sam 0/5` | Sam | | | | check (day not valid) |
| `Sam 12 Feb 2031`, `Sam 3 Nov 2026` | Sam | | | 2031 / 2026 | check (future) |
| `Sam 12 Feb 2026` | Sam | 12 | 2 | 2026 | ok |
| `Sam 40/50` | `Sam 40/50` | – | – | – | check (no date found) |
| `Sam`, `Just some words` | as typed | – | – | – | check (no date found) |
| `12 Feb` | (none) | 12 | 2 | – | check (no name) |
| `??` | skipped | | | | – |
| `1. Mum 3 March` / `2) Dad 5 April` / `(3) Dad 5 April` / `14. Sam 12 Feb` | Mum / Dad / Dad / Sam | | | – | ok |
| `✅ Sam 12 Feb` / `☐ Sam 12 Feb` / `👉 Sam 12 Feb 🎉` / `> Sam 12 Feb` / `   • Sam 12 Feb   ` | Sam | 12 | 2 | – | ok |
| `Sam Sat 12 Feb` / `Sam, Saturday 12th February` | Sam | 12 | 2 | – | ok |
| `Sam born 12 Feb 1990` / `Sam DOB 12/02/1990` / `Sam date of birth: 12/02/1990` | Sam | 12 | 2 | 1990 | ok |
| `Sam turns 12 Feb` / `Sam bday: 12 Feb` / `Sam - bday - 12 Feb` / `Sam birthday on 12 Feb` | Sam | 12 | 2 | – | ok |
| `mum 3/3` / `MUM 3/3` (case) / `Mom - 3 Mar` | Mum / MUM / Mom | 3 | 3 | – | ok |
| `Dad: 14 Jan 1960` | Dad | 14 | 1 | 1960 | ok |
| `Mum 3/3, Dad 5/4, Sam 12/6` (comma list) / `Mum 3/3; Dad 5/4` / `Mum 3/3 & Dad 5/4` | 3 entries / 2 / 2 | | | | ok |
| Month headings: `January`, `Kai 14`, `Lena 20`, `May Tan 3`, `February`, `Leo 2`, `Mia 3`, `March`, `Noor 9` | Kai 14 Jan, Lena 20 Jan, May Tan 3 Jan, Leo 2 Feb, Mia 3 Feb, Noor 9 Mar | | | | ok |
| Consistent list `14/1` + `3/5` + names (all DMY-compatible) | | | | | ok, no hint |
| Mixed list (`14/1 Sam` and `1/14 Tom`) | | | | | the opposite-style row = check "Day/month order unclear…" + hint |

### 6.19 Keyboard shortcuts
Disabled while typing in any input; Esc blurs the input. `/` search · `N` new person · `U` Upcoming tab · `F` fit · `L` lock · `?` help dialog (lists these) · `Esc`: close modal, else clear selection, else clear event tag. The ticker footer shows the hints.

### 6.20 Ticker
A one-line scrolling strip, mono 10.5 px uppercase, content duplicated for a seamless loop (animation `pm-tick`, 75 s linear, infinite):
`NEXT BDAY SAM IN 12D // DRIFTING BEN 13MO · CHLOE 10MO · HELEN 7MO // LAST ADDED ANA P19 // OPEN FAVOURS 4 // HIGH RISK 2 // / SEARCH  N NEW  U UPCOMING  F FIT  L LOCK  ? HELP`. Pauses on hover. Respects reduced motion (static, shows only the first item).

### 6.21 Settings tab
Collapsible `<details>` sections, in order: **Lock screen**, **Backups**, **Import birthdays**, **Line colours and kinds** (per kind: show checkbox, colour input, name, delete except `introduced`/`metvia`; "add a kind"), **Character labels** (rename 1–5), **Flags** (custom green/red flags: add, rename, delete), **Appearance** (accent amber/cyan, circle colour from, show risk rings), **Example data and clearing** (Load example people — confirm; Clear everything — double confirm).

---

## 7. Readout box (top-right of the stage)

Shown for the hovered person (preview) or the selected one. Width ~300 px, background `rgba(10,10,10,.94)`, 1 px border `--line2`, **1 px top border in the accent colour**. Header: `NAME (GROUP/ROLE)` left, code right in accent. Then label/value rows (label 9.5 px uppercase muted, value mono right-aligned):
`CHARACTER  2 / 5` · `RISK  [HIGH]` (coloured tag, "OVR" mark if overridden) · `LINES  5` · `LAST TALKED  3mo` · `BIRTHDAY  in 12d` · `FAVOURS  owes you 2` · `MET VIA  Dr Lim (mentor)` · `EVENTS  commodities`. Rows with no data are omitted.

## 8. Example data (fake) — "Load example people"

Everything fake, every name prefixed **`Example: `**, dates **relative to today** (so Upcoming always has content): birthdays between 1 and ~300 days ahead, last-talked from 1 to 400 days ago, met-dates spread over ~3 years. Loading replaces current data after a confirmation. Must produce **19 people**, **~25 lines** (all relationship kinds used, strengths 1–3, a couple of pairs with two kinds), **8 favours**, a few gift notes/likes/ideas, and a few `metBy` chains.

People (name — group — rating): Mum — Family — 5; Brother Sam — Family — 5; Cousin Ivy — Family — 4; Alex (polo club) — Polo — 4; Wei (polo coach) — Polo — 5; Priya (school friend) — Friends — 5; Nina (student) — Friends — 4; Marcus (commodities trader) — Finance — 2; Helen (angel investor) — Finance — 4; Omar (art gallery owner) — Arts — 3; Tara (event organiser) — Arts — 4; Dr Lim (mentor) — Startups — 5; Chloe (startup founder) — Startups — 3; Ben (recruiter) — Startups — 3; Jordan (partner) — Friends — 5; Raj (polo sponsor) — Polo — 1; Sofia (gallery curator) — Arts — 4; Kenji (commodities broker) — Finance — 2; Ana (fund manager) — Finance — 4.

Word pool for offers/needs (so *Who should meet?* has ≥ 8 matches): hiring, funding, polo, sponsors, commodities, art, event venue, career advice, deal ideas, jobs, design, trading advice, horses, events. Event tags include `polo`, `commodities`, `gallery night`.

**Path test fixture:** the shortest route from me to Ana must be `me → Marcus → Kenji → Ana` (Ana is only reachable through Kenji, Kenji through Marcus).
**Drifting fixture:** at least 5 people with `lastTalked` ≥ 90 days ago (Nina, Ben, Chloe, Helen, Cousin Ivy…), one at ≥ 300 days (fully faded to .35).

Example **character profiles** (so the Risk tab is populated). Traits in order honest / reliable / discreet / generous / steady / boundaries; contacts are derived automatically from the lines. The "expected" level comes from the formula in section 12.5:

| person | traits | red flags | green | evidence (age) | exposure | favours | expected |
|---|---|---|---|---|---|---|---|
| Marcus | 2 3 3 4 3 3 | gossips | – | bad 25d, good 60d | private + money; 3 contacts | I helped him 2 | **High** (53) |
| Raj | 2 2 2 3 2 2 | gossips, lies, pushy about money | – | bad 20d, bad 70d | private + money; 3 contacts | I helped him 3 | **Critical** (83) |
| Kenji | 3 2 3 3 3 3 | only calls when they need something | – | bad 90d | money; 2 contacts | I helped him 1 | **High** (42) |
| Ben | 3 3 3 3 3 3 | gossips | – | – | none; 1 contact | – | **Medium** (24) |
| Helen | 4 4 4 4 4 4 | – | keeps promises, pays back | good 40d | money; 2 contacts | she helped me 2 | **Low** (12) |
| Priya | 5 5 5 4 5 5 | – | keeps promises, introduces, pays back | good 30d | private; 1 contact | she helped me 2 | **Low** (5) |
| Mum | 5 5 5 5 4 4 | – | keeps promises, pays back | – | private; 1 contact | – | **Low** (0) |
| Nina | honest 4 only | – | – | – | – | – | **Not enough info** |

(Scores are for those exact inputs with no override; they are in the acceptance tests.)

## 9. Motion (subtle; Bloomberg-terminal calm)

- `pm-drift`: each circle floats ±1.6 px on both axes, 13 s ease-in-out alternate infinite, with per-circle random delay/duration (9–17 s) so they never move in sync.
- `pm-pulse` birthday: a 1 px accent outline around the square scales 1 → 1.9 while fading out, 2.6 s infinite.
- `pm-pulse` drifting: same, stroke `#8a8a8a`, 4.2 s.
- `pm-tick`: ticker 75 s linear infinite.
- Panel/tab/hover changes: ≤ 120 ms colour/border transitions only. No bounce, no slide-ins, no springy easing, no parallax, no confetti.
- `@media (prefers-reduced-motion: reduce){ *{animation:none !important; transition:none !important} }` and the ticker becomes static.

## 9b. Opening animation (intro visuals)

About 2 seconds, terminal style, pure CSS/SVG/JS (no libraries, no network). Any key or click skips it. With prefers-reduced-motion it is instant (no animation).

Options (build all four, pick in Settings; default = 4 when a password is set, 2 otherwise):
1. **Boot sequence**: mono system text types out line by line, e.g. `DECRYPTING…`, `LOADING 19 PROFILES…`, `MAPPING 38 LINKS…` (real counts), then the map snaps in.
2. **Constellation build**: Georgia's node lights up first in the centre, people fly in one by one, and the lines draw themselves between them.
3. **Scan line**: a thin accent-colour line sweeps down the black screen, revealing the map behind it like a scanner.
4. **Vault unlock** (when locked): a thin spinning ring around the password field, `ACCESS GRANTED` flashes on success, then the view expands into the map.

## 10. Misc behaviour

- Toast: bottom centre, `--toastbg`/`--toastfg`, auto-hides after 3 s; error toasts 6 s.
- Modal: Esc closes (unless sticky); focus is trapped; first field auto-focused.
- Dates are handled as UTC day numbers to avoid timezone/DST off-by-one errors; "today" = local calendar date.
- Everything the user can click has a visible focus ring (1 px accent outline) for keyboard use.
- Clearing everything (Settings) wipes `peoplemap.v1` and restarts with only "me".

---

## 11. Design system — "Bloomberg terminal"

Feel: dense, black, sharp, expensive. **Not** "AI-generated": no gradients, no glassmorphism blur, no rounded pill buttons, no soft shadows, no emoji icons, no purple/blue neon, no big friendly illustrations, no centred hero text, no pastel cards, no rotating spinners. Flat surfaces, hairline borders, monospaced numbers, uppercase micro-labels, amber (or cyan) used sparingly as the single accent.

### 11.1 CSS tokens (use exactly these; `:root`)
```css
:root{
  --bg:#0a0a0a; --bar:#0c0c0c; --panel:#0e0e0e; --card:#111111;
  --text:#d4d4d4; --muted:#7d7d7d;
  --line:#222222; --line2:#343434; --input:#090909; --hover:#171717;
  --accent:#ffb000;                 /* amber variant (default) */
  /* cyan variant: --accent:#00d1ff;  --accentsoft:rgba(0,209,255,.12) */
  --accentfg:#000000; --accentsoft:rgba(255,176,0,.12); --accenttext:#ffb000;
  --danger:#e5645c; --dangerline:#5c2623;
  --ok:#58b27f; --okbg:#0d1a12;
  --warn:#d9a441; --warnbg:#16120a; --warnline:#47381a;
  --stage:#080808; --nodetext:#bdbdbd; --halo:#080808; --ring:#ffffff;
  --toastbg:#1c1c1c; --toastfg:#eeeeee;
  --radius:2px; --radius-sm:1px; --cardradius:2px;
  --lblcase:uppercase; --lblspace:.09em;
  --ptw:450px;                      /* side panel width */
  --font:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;
  --mono:ui-monospace,"SF Mono",SFMono-Regular,Menlo,Consolas,"Liberation Mono",monospace;
}
```
The accent switch (Settings > Appearance) just swaps `--accent`, `--accentsoft` (`rgba(255,176,0,.12)` ↔ `rgba(0,209,255,.12)`) and `--accenttext`.

### 11.2 Character colours, line colours, risk colours
- **Character (fill):** 0 `#5c5c5c` · 1 `#c0504d` · 2 `#c98a3a` · 3 `#c9b84a` · 4 `#8cbf6a` · 5 `#1f8f55` · me `#262626`.
- **Lines:** family `#e6e6e6` · friend `#4a90e2` · work `#2bb3c0` · business "Investor / business" `#8b7bdc` · mentor `#a9b4ff` · partner "Romantic / partner" `#c77dd8` · introduced "Introduced by <myName>" `#e6e6e6` **dashed** · metvia "Met through someone" `#2bb3c0` **dotted**. (Deliberately no reds/oranges/yellows/greens/greys so lines never look like character colours.)
- **Risk (rings, tags, bars):** Critical `#e5484d` · High `#e5845c` · Medium `#d9a441` · Low `#58b27f` · Not enough info `#7d7d7d` (dashed). Risk is shown with **outline rings and tags, never as fill**, so it can't be confused with character fill.

### 11.3 Typography and shape
- Body 13 px / 1.4 `--font`, colour `--text`. **All numbers, codes, dates, clock, stats values: `--mono`.**
- Micro-labels: 9–10.5 px, `text-transform:uppercase`, `letter-spacing:.09em–.15em`, `--muted`.
- Buttons: transparent, 1 px solid `--line2`, radius 2 px, 600 10.5 px uppercase `.1em`; hover bg `--hover`; **primary** = `--accent` fill, black text, same border colour.
- Inputs/selects/textareas: bg `--input`, 1 px `--line2`, 12.5 px; focus → border `--accent`.
- Everything has 1 px borders in `--line`/`--line2`; radius never above 2 px; no shadows (the only exception: toast gets none either).
- Tabs: 9 px uppercase, active tab has a 2 px accent underline and accent text; count badge = bordered accent mono pill (1 px border, 9 px). Sub-tabs 10 px.
- Tables: header row 9 px uppercase muted, 1 px row dividers `--line`, row hover `--hover`, dense (6 px × 8 px padding).
- Checkbox/radio: native with `accent-color:var(--accent)`.
- Panel sections use `.sect` = 1 px `--line2` border, `--panel` bg, header strip in `--bar` with a 10 px uppercase title.

### 11.4 Stage
Background `#080808` with a 32 px dot grid (1 px × 1 px dots, `#262626`; an inline SVG data-URI repeated). Circles are squares (radius 0), stroke `#0a0a0a` (me: `#e8e8e8`), selected = 1 px white ring `--ring`. Search match = dashed ring. Dimmed = opacity .10. Legend bg `rgba(10,10,10,.92)`; zoom buttons are 30 px bordered squares.

### 11.5 Header, ticker, panel specifics
- Header: bg `--bar`, bottom border 1 px `--line`; title square 7 px in accent.
- Ticker: height 26 px, bg `--bar`, top border 1 px `--line`, mono 10.5 px uppercase, `--muted`; key hints with 1 px border boxes (`/`, `N`, `ESC`, `?`) in accent text.
- Review-table flagged rows: `rgba(229,100,92,.07)` background.
- Warning boxes (`.warnbox`): bg `--warnbg`, border 1 px `--warnline`, text `--warn`. Danger text `--danger`.

---

## 12. NEW: Character profile + Risk level

Goal: for each person I record how much I trust their character, with evidence, and the app turns that into a **Risk level for this connection** — Low / Medium / High / Critical (or Not enough info) — explained in plain English. Risk = "how bad would it be for me if this person let me down, weighted by how likely that looks". It is **my private decision aid**, never a verdict, and it lives only inside the encrypted/local data.

### 12.1 Data (`person.character`)
```jsonc
"character": {
  "traits": { "honest":0, "reliable":0, "discreet":0, "generous":0, "steady":0, "boundaries":0 }, // 0 = unrated, else 1..5
  "flags": ["gossips","keeps_promises"],     // ticked built-in flag ids and custom flag ids
  "evidence": [ { "id":"e1", "date":"2026-10-12", "effect":"bad", "text":"Told other people about my plan after I asked him to keep it private" } ],
  "gut": { "text":"Charming but I never feel fully at ease", "confidence":"new" },  // confidence: "" | "new" (just met) | "months" (few months) | "years" (known for years)
  "exposure": { "private": false, "money": false },
  "override": { "level":"", "reason":"" }     // level: "" | "low" | "medium" | "high" | "critical"
}
```
Built-in flags: **green** `keeps_promises` "Keeps promises", `introduces` "Introduces you to people", `pays_back` "Pays back". **red** `gossips` "Gossips", `lies` "Lies", `only_when_need` "Only calls when they need something", `pushy_money` "Pushy about money", `badmouths` "Bad-mouths others". Custom flags (Settings > Flags, or **+ Add flag** in the person's Character tab) live in `S.customFlags` with a `kind` of green or red and count exactly like built-in ones.

### 12.2 The Character sub-tab (person editor), top to bottom
1. **Header strip:** square code chip in the rating colour, name, "Group · Met 14 Mar 2024 · Last talked 41 days ago".
2. **Traits** (right side: `avg 2.8 / 5`): six rows — **Honest, Reliable, Discreet, Generous, Emotionally steady, Respects boundaries**. Each row: label (uppercase 10 px), five numbered 1–5 squares coloured with the character colours (dim to 32% opacity unless chosen; chosen = full opacity + 1 px white outline), and `2 / 5` on the right (mono; `–` if unrated). Click the chosen square again to clear it. The average is the plain mean of rated traits.
3. **Flags:** two columns. Left "GREEN FLAGS" (heading in `--ok`), right "RED FLAGS" with a count (heading `--danger`). Checkbox rows; ticked rows brighten to `#f0f0f0`. **+ Add flag** (inline: text + green/red) below.
4. **Evidence log** (`3 entries`): table Date · What happened · Effect (`GOOD` green mono / `BAD` red mono), newest first, each row deletable. **+ Add entry**: date (default today), good/bad segmented control, one-line text (required).
5. **Gut feel:** a one-line text and a segmented control "How well do you know them?" — `Just met` / `Few months` / `Known for years`. Gut text and confidence **never change the score** (they're opinion; use the override for that), but confidence adds a line to the "why" list (12.6).
6. **Exposure:** checkboxes "Knows private things about me", "Involved in my money or deals", and an auto line `CONNECTED TO 10 OF YOUR PEOPLE · AUTO` (count of distinct other people, excluding me, joined to this person by any line, including met-via links).
7. **Risk readout** (the `riskbox`): see 12.7.

### 12.3 Sub-scores (all 0–100, **higher = riskier**)
- **Character score** `C` — from traits + flags:
  - weighted mean of rated traits, weights: honest **2**, reliable **1.5**, discreet **1.5**, generous 1, steady 1, boundaries 1 → `avg` (1–5);
  - `base = (5 − avg) / 4 × 100`;
  - `C = clamp(round(base + min(32, 8 × redFlags) − min(15, 5 × greenFlags)), 0, 100)`.
- **Exposure score** `E` — how much damage this person could do: `E = clamp((private ? 35 : 0) + (money ? 35 : 0) + min(30, 3 × contacts), 0, 100)`.
- **Track record score** `T` — only when there is at least one evidence entry or favour; else `null`:
  - each evidence entry has a weight by age: ≤ 180 days **1**, ≤ 365 days **0.6**, older **0.35**; `net = Σ(bad weights) − Σ(good weights)`;
  - favour term `fav = clamp((iHelpedThem − theyHelpedMe) × 5, −10, +15)` (one-sided taking raises risk);
  - `T = clamp(round(50 + clamp(net, −3, 3) / 3 × 40 + fav), 0, 100)`.

### 12.4 Combining
`likelihood L = T is null ? C : 0.7·C + 0.3·T`
`score = round( L × (0.4 + 0.6 × E / 100) )`   (so exposure scales the damage; a great person with high exposure stays Low; a poor person with no exposure is only Medium)

**Levels:** `0–19 Low` · `20–34 Medium` · `35–54 High` · `55–100 Critical`.
**Not enough info:** if fewer than **3 traits** are rated, the computed level is "Not enough info" and no score is shown (the bars still show Exposure and any evidence). A manual override still works.

### 12.5 Reference implementation (copy this logic exactly) and test vectors
```js
var TRAIT_W={honest:2,reliable:1.5,discreet:1.5,generous:1,steady:1,boundaries:1};
function clamp(x,lo,hi){return Math.max(lo,Math.min(hi,x))}
// i = { traits:{honest:0..5,...}, red:n, green:n,
//       evidence:[{ageDays:n, effect:'good'|'bad'}], exposure:{priv:bool, money:bool},
//       contacts:n, favThey:n /*they helped me*/, favMine:n /*I helped them*/ }
function riskOf(i){
  var keys=Object.keys(TRAIT_W),sw=0,s=0,rated=0;
  keys.forEach(function(k){var v=i.traits[k]||0;if(v>=1){rated++;sw+=TRAIT_W[k];s+=TRAIT_W[k]*v}});
  var avg=rated?s/sw:null;
  if(rated<3)return {level:'none',score:null,rated:rated,avg:avg};
  var base=(5-avg)/4*100;
  var character=clamp(Math.round(base+Math.min(32,i.red*8)-Math.min(15,i.green*5)),0,100);
  var exposure=clamp((i.exposure.priv?35:0)+(i.exposure.money?35:0)+Math.min(30,i.contacts*3),0,100);
  var track=null,net=0,ev=i.evidence||[];
  ev.forEach(function(e){var w=e.ageDays<=180?1:e.ageDays<=365?0.6:0.35;net+=(e.effect==='bad'?w:-w)});
  var fav=clamp((i.favMine-i.favThey)*5,-10,15);
  if(ev.length||i.favThey||i.favMine){track=clamp(Math.round(50+clamp(net,-3,3)/3*40+fav),0,100)}
  var L=track===null?character:0.7*character+0.3*track;
  var score=Math.round(L*(0.4+0.6*exposure/100));
  var level=score>=55?'critical':score>=35?'high':score>=20?'medium':'low';
  return {level:level,score:score,character:character,exposure:exposure,track:track,avg:avg,rated:rated};
}
```
**Anchors and test vectors (must match exactly; traits order honest, reliable, discreet, generous, steady, boundaries):**

| case | inputs | expected |
|---|---|---|
| **Anchor 1:** low honesty, in deals, knows ~10 contacts | traits 2 3 3 3 3 3; 0 red/green; no evidence; money only; contacts 10 | C 56, E 65, T null → score **44 → HIGH** |
| **Anchor 2:** kind friend, not in money, one red flag | traits 5 4 5 4 4 5; 1 red; contacts 3; no exposure ticks | C 19, E 9 → score **9 → LOW** |
| Everything bad | traits 1 2 2 2 2 2; 3 red; bad 20d + bad 60d; private + money; contacts 12; I helped them 3 | C 100, E 100, T 92 → **98 → CRITICAL** |
| Trusted mentor with huge exposure | traits 5 5 5 4 5 5; 3 green; good 30d; private + money; contacts 10; they helped me 3 | C 0, E 100, T 27 → **8 → LOW** |
| Mediocre, no exposure | traits all 3; nothing else | C 50, E 0 → **20 → MEDIUM** |
| Dishonest, zero exposure | traits 1 2 2 2 2 2; nothing else | C 81, E 0 → **32 → MEDIUM** |
| Decent person in deals | traits 4 4 4 3 4 4; 1 green; money; contacts 4 | C 23, E 47 → **16 → LOW** |
| Only 2 traits rated | honest 2, reliable 3; private + money; contacts 10 | **NOT ENOUGH INFO** |

(The Marcus/Raj/Kenji/Ben/Helen/Priya/Mum/Nina example people in section 8 give 53 / 83 / 42 / 24 / 12 / 5 / 0 / not-enough-info.)

### 12.6 "Why this rating" (plain English)
Show up to 6 lines for what pushes risk **up**, each with its contribution `+N`, biggest first. Contribution = `score − scoreWithThatFactorRemoved` (recompute `riskOf` with that one factor neutralised: trait set to 4, flags removed, an exposure tick unticked, contacts 0, bad evidence removed, favour imbalance 0). Only show factors worth ≥ 2 points. Wording templates:
- trait ≤ 2: `Low honesty (2/5)` — names: honesty, reliability, discretion, generosity, emotional steadiness, respect for boundaries.
- `2 red flags: gossips, only calls when they need something`
- `In your money or deals` · `Knows private things about you` · `Knows 10 of your people`
- `Mostly takes: owes you 2 favours` (when I helped them more)
- `2 bad entries in the log, latest: "Told other people about my plan…"`
- confidence "just met": `You've only just met — treat this as provisional.` (no points)

Then a second, calmer list **"Working in their favour"** (green squares, no points): green flags by name, `N good entries in the log`, `They help you more than you help them`, `No red flags`.
Each "why" bullet has a 5 px square marker: red for large items (≥ 10 points), amber for smaller.

### 12.7 Risk readout box (inside the Character tab and the readout)
`riskbox`: bg `#100c0b`, 1 px `--line2` border with a 1 px **top** border in the level's colour. Contains:
- Left: tiny label `RISK LEVEL` and the level in mono 22 px bold, letter-spacing .14em, in the level colour; right: `71 / 100` with "computed" under it.
- Three bars: **Character**, **Exposure**, **Track record** — each a 6 px high bar (`#1a1a1a` track, 1 px `--line` border) filled with the level colour, plus the 0–100 value in mono on the right (`–` for unknown).
- The "Why this rating" list, then "Working in their favour".
- **Override row:** `COMPUTED High` · `YOUR LEVEL  Same as computed` with a segmented control `Same | Low | Med | High | Crit`. Choosing anything other than "Same" requires a **reason** (one line, ≥ 3 characters; the control stays disabled until typed). The **effective level** (used on the map, header, tags, who-should-meet) = override if set, else computed. The computed level is **always still displayed** next to it, and an amber `OVR ↑ from MED` / `OVR ↓ from HIGH` mark appears wherever the effective level is shown. The reason is shown under the control.
- Level tag styles (`.lv`): mono 700 10 px uppercase, letter-spacing .1em, 1 px border, padding 2 × 7 px. **Critical:** black text on solid `#e5484d`. **High:** `#e5845c` text/border on `rgba(229,132,92,.1)`. **Medium:** `#d9a441`. **Low:** `#58b27f`. **Not enough info:** `#7d7d7d` text, `#444` **dashed** border.
- A collapsible **"How is this calculated?"** under the box prints the formula in words (12.3–12.4).

### 12.8 Risk tab (watchlist)
Tab badge = number of people with effective level High or Critical. Panel body, top to bottom:
1. **Risk watchlist · highest first** (`.sect` header) with a summary: `8 people · 2 critical · 2 high · 2 medium · 1 low · 1 not enough info`.
2. Table: **Risk** (level tag) · **Name** (with a red warning triangle for High/Critical) · **Character** (avg trait score and a mini 56 × 5 px bar) · **Exposure** (value + mini bar) · **Track** (value + mini bar, `–` if null) · **Why** (the top 1–2 "why" items, comma-joined, truncated) · **Last talked** (`41 days`) · **Override** (the OVR mark or `–`). Sorted by effective level (Critical → High → Medium → Low → Not enough info), then by score desc, then name. Row click selects the person and opens their Character tab. Optional filter chips: All / High+ / Overridden.
3. People marked "Not enough info" show a one-line nudge: "Only 1 trait rated — rate at least 3."
4. A small note: "Risk is your private decision aid. It never leaves this computer."

### 12.9 On the map: warning marks and risk rings
- Legend gets a **RISK** block with a **Show risk: ON/OFF** toggle (also Settings > Appearance; default ON; key `R`).
- When ON, every non-me person gets an **outer ring** (1.5 px, 4 px outside the square) in the effective level colour: Critical `#e5484d`, High `#e5845c`, Medium `#d9a441`, Low `#58b27f`, Not enough info dashed `#7d7d7d`. The square's **fill stays the character colour**.
- High and Critical also get a small **red warning triangle** (12 px wide, 10 px tall, fill `--danger`) at the square's top-right corner. An overridden level adds a tiny `OVR` mark in accent.
- Legend note: `RING = RISK LEVEL · TRIANGLE = HIGH / CRITICAL · FILL = CHARACTER`.
- Dimming (click/search/event/path focus) dims rings and triangles with their circle.
- Hover titles stay name-only (section 2.11).

### 12.10 Who-should-meet risk warning
For every suggestion card, look up each person's effective level.
- If **either** is High or Critical: the card gets a red left border (2 px `--danger`), bg `#120d0c`, border `#5c2623`; a `▲ HIGH RISK` / `▲ CRITICAL RISK` badge (mono 700 9.5 px, `#e5845c`, 1 px border, bg `rgba(229,132,92,.08)`); a one-line **heads-up** in `#d9a99e`: `Heads up: Marcus gossips and has shared your private plans before. Priya is one of your closest people (mentor, closeness 3).` — built from the risky person's top red flag/bad evidence **and**, when the other person has a direct line of strength 3 to me, a "closest people" clause naming the line type. The button changes from **Mark introduced** to **Introduce anyway**, which asks `confirm("Marcus is rated High risk. Introduce anyway?")` first.
- If the worst is **Medium**: a small amber `MEDIUM RISK` tag, normal button.
- Otherwise a green `LOW RISK` tag.
- Never suppress a suggestion because of risk — warn, never decide.

### 12.11 Header counts, ticker, encryption, backups
- Stats bar: **High risk** and **Critical** cells (effective levels), value `--danger` when > 0.
- Ticker adds `HIGH RISK n`.
- All character data is inside `person.character`, so it is **included in the encrypted store and in encrypted backups automatically**; plain backups include it (hence the warning in 2.5). `sanitize()` fills defaults for older backups. **Version number goes to 3.**
- Optional (nice to have): key `H` = "hide sensitive" — greys out character colours, risk rings and tags while someone is looking; off by default.

---

## 13. Acceptance checklist (the finished file must pass all of these)

**Privacy**
- [ ] With the network disabled, the file loads and works. DevTools Network shows **zero** requests (other than the file itself).
- [ ] The CSP meta tag is present exactly as in 2.2. No `fetch`/XHR/`eval`/external URL in the source (search for `http` — only allowed inside comments and the SVG namespace string).
- [ ] After setting a password, `localStorage['peoplemap.v1']` contains `peoplemapEnc` and **no** person name or text anywhere in the value. Locking clears all names from the page text. Wrong password rejected; right password restores everything, including character data.
- [ ] Encrypted backup contains `ct` and no readable names; loading it with a wrong password says "Wrong password", with the right one restores 100% of the data.
- [ ] A corrupted `peoplemap.v1` is copied to `peoplemap.v1.broken` and the app starts fresh with a toast.
- [ ] Copy guest list contains only names.

**Features**
- [ ] Load example → 19 people + me = 20 circles; header stats show People 19.
- [ ] Drag a circle, reload the page: position persists (pinned). Tidy up unpins all but me and re-spreads.
- [ ] Legend toggles hide/show line types and rating groups; counts are correct.
- [ ] Click a person: neighbours stay lit, others at opacity .10. Esc clears.
- [ ] Search "polo" dims non-matches; Enter flies to the first match; Esc clears.
- [ ] Faded circles: a person last talked 120 days ago is partly faded; ≥ 365 days is at .35; no `lastTalked` is never faded. Drifting list sorted longest first; **Talked today** fixes it.
- [ ] Upcoming 30/60/90 lists birthdays and key dates correctly; Feb 29 shows on Feb 28 in non-leap years; today = 0.
- [ ] Path finder: from me to Ana returns `Marcus → Kenji → Ana`, and the sentence "Ask Marcus to introduce you to Kenji…".
- [ ] Favour balance text: "They owe you 2", "You owe them 1", "Even"; header Open favours counts non-zero balances.
- [ ] Events: selecting `polo` shows Alex and Raj and dims others; Copy guest list works.
- [ ] Who should meet: matching handles "sponsors" = "sponsor"; **Mark introduced** adds a dashed `introduced` line and removes the card.
- [ ] Web growth slider appears when ≥ 2 people have `metDate`; at 10% fewer circles show; at 100% all do; Play runs.
- [ ] Duplicate line of same type between same pair is refused with the message.
- [ ] Line colour clash warning appears for a colour near a character colour.
- [ ] Keyboard: `/`, `N`, `U`, `F`, `L`, `?`, `Esc` as specified; typing "n" inside the name box doesn't re-trigger.
- [ ] Old (version 1/2) backups load; missing fields default.

**Importer**
- [ ] Every row of the parser test table (6.18) passes in an automated check (run `parseBirthdays` in the console against the table).
- [ ] "Try a messy example" gives the expected read; flagged rows can't be included until fixed; confirm shows "Imported: N updated, M new"; a matched person keeps their old birth year if the new line has none; ambiguous matches force a manual pick.

**Character + Risk**
- [ ] All eight test vectors in 12.5 produce the stated level and score (check in the console with `riskOf`).
- [ ] Anchor 1 ⇒ High; Anchor 2 ⇒ Low.
- [ ] Fewer than 3 traits ⇒ "Not enough info", no score.
- [ ] Override: choosing a level requires a reason; effective level changes everywhere (map ring, tags, header counts, watchlist, who-should-meet) while "COMPUTED …" remains visible; `OVR` marks appear.
- [ ] Risk rings toggle on/off (legend and `R`). High/Critical show the warning triangle.
- [ ] Who-should-meet shows the heads-up and "Introduce anyway" with a confirm when either person is High/Critical.
- [ ] Risk tab watchlist sorted Critical → Low → Not enough info; tab badge = High + Critical; header High risk / Critical cells match.
- [ ] Encrypted store and encrypted backups include character data (verified by a round trip).

**Design**
- [ ] Looks like section 11: black, hairline borders, mono numbers, uppercase micro-labels, 2 px max radius, accent used sparingly; amber and cyan variants both work from Settings.
- [ ] `prefers-reduced-motion` removes all animation (drift, pulses, ticker).
- [ ] Usable at 820 px width and below.

---

## 14. Suggested build order for Claude (small steps — stop after each and show me)

1. **Skeleton + design:** the HTML shell, CSP, CSS tokens, header with stats bar/clock, toolbar, stage with dot grid, side panel with empty tabs, ticker, toast, modal. No data yet. *(Check against screenshot 1.)*
2. **Core state:** the data model, `fresh()`, `sanitize()`, localStorage save/load with debounce, the "saved only on this computer" badge, corrupt-data handling.
3. **Map:** people circles (rating colours, codes, names), force layout, drag/pin, pan/zoom, Fit, Tidy up. "Load example people" to test.
4. **Lines:** types, colours, strength, dashed/dotted, parallel arcs, click-to-edit, legend with toggles and counts.
5. **Person editor:** add form, Basics, Lines sub-tab, delete, search, click highlight, readout box.
6. **Time features:** last talked, fading, drift pulse, drifting list; birthdays/key dates, Upcoming 30/60/90, gifts, Dates sub-tab; header stats and ticker.
7. **Relationship features:** how-we-met + virtual met-via lines, web growth slider, Who should meet?, path finder, favours, events + guest list.
8. **Privacy:** password lock (PBKDF2+AES-GCM), lock screen, plain + encrypted backups, load backup, backup reminder, settings sections.
9. **Birthday importer:** write `parseBirthdays` as a pure function first and run the whole test table in the console; then the modal UI (paste → review → commit).
10. **Character + Risk:** data + `sanitize` defaults, Character tab UI, `riskOf` (test the 8 vectors), readout box, "why" list, override, then map rings/triangles, Risk tab, header counts, who-should-meet warning, legend toggle, encryption round trip.
11. **Polish:** keyboard shortcuts, help dialog, reduced motion, responsive layout, accent switch, the acceptance checklist top to bottom.

Rules while building: keep to one file; don't add libraries; don't rename the localStorage key; after each step tell me exactly what to click to test it; if something in this brief is ambiguous, pick the simplest option and tell me what you chose.

---

## 15. Reference screenshots (from the working prototype; look at these to match the design)

These files are on the machine where this brief was written (Georgia can attach them to the Claude chat):

1. **Main map, amber terminal design:** `/workspace/netmap/options/T1.png` — header stats bar, toolbar, legend (top-left), readout box (top-right of the stage), side panel with the Basics editor, ticker footer. This is the design target for steps 1–5.
2. **Character tab with risk marks on the map:** `/workspace/netmap/preview_character.png` — the new Character sub-tab (trait rows with 1–5 coloured squares, green/red flags, evidence log), risk rings and warning triangles on the map, extra "High risk" and "Critical" header cells, "Risk" tab with its badge.
3. **Risk watchlist tab:** `/workspace/netmap/preview_risk.png` — the watchlist table (level tags, mini bars, why, override mark), the map strip with risk rings, and the risk-checked Who-should-meet cards including the High-risk warning and "Introduce anyway".

Also useful if wanted: `/workspace/netmap/options/T1_upcoming.png` (Upcoming tab), `/workspace/netmap/options/T1_importer_review.png` (importer review table), `/workspace/netmap/preview_character_readout.png` (readout with risk row), `/workspace/netmap/options/T2.png` (cyan variant). Note: in the preview screenshots the sample risk numbers (e.g. Marcus 71) came from an earlier mock; the **formula and test vectors in section 12 are the spec**, not the numbers in those pictures.
