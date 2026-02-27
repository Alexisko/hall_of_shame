# 🎯 Emilien Jacquelin — Hall of Misses

A fun, ironic, and affectionate website celebrating Emilien Jacquelin's missed shots
and penalty loops across his World Cup career. Think ESPN drama meets French absurdist humor.
He's a champion — but his shooting is a national sport in itself.

---

## Tech Stack

- Pure HTML/CSS/JS — NO frameworks, NO npm, NO build steps
- Chart.js via CDN for all charts
- Tailwind CSS via CDN for styling
- Papa Parse via CDN to read the CSV file
- Everything in a single `index.html` unless a feature requires separation
- Must work when served over HTTP — **GitHub Pages is the deployment target**
- Local dev: use a simple HTTP server (Python or similar); the CSV cannot be loaded via `file://`

---

## Deployment

- Target: **GitHub Pages** (static hosting from the repo root or `/docs` folder)
- The `data/penalty_loop.csv` file must be committed to the repo — it is fetched at runtime
- No build step, no CI pipeline needed — push `index.html` + `data/` and it works
- Keep all asset paths **relative** (never absolute or localhost URLs)
- Test locally with an HTTP server before pushing; `file://` will block CSV fetching

---

## Data

- File: `data/penalty_loop.csv`
- **Always read and inspect this file before writing any code**
- Filter all data on `FullName == "Emilien JACQUELIN"`
- Key columns:
  - `Season` — e.g. 2021, 2122, 2223, 2324, 2425, 2526
  - `StartDate` — ISO date of the race
  - `Location` — venue name
  - `DisciplineLabel` — Individual, Sprint, Pursuit, Relay, Mass Start
  - `IsRelay` — TRUE/FALSE
  - `NrShootings` — number of shooting stages in the race (2 or 4)
  - `Shootings` — string like "1+0+2+1" showing misses per stage
  - `RankInt` — finish position of the athlete in that race (integer; may be NA)
  - `total_misses` — total misses in the race
  - `total_penalties` — total penalty loops in the race
  - `total_spares` — extra bullets used (relay only)
  - `miss_1` to `miss_4` — misses per shooting stage
  - `penalty_1` to `penalty_4` — penalty loops per shooting stage

- Known totals (use as **sanity check only — never hardcode these**):
  - 172 races total
  - 481 career misses
  - 321 career penalty loops = **48,150 meters = ~48 km** of penalty loops run

---

## Tone & Design

- Dark background (#0a0a0a or similar), like a dramatic late-night sports broadcast
- Red (#ef4444) for misses and shame, gold (#f59e0b) for rare good moments
- Typography: bold, oversized numbers — make the stats feel monumental
- French humor welcome in titles and labels
- Affectionate mockery only — he's still a legend

---

## Features to Build (in this order)

### 1. Hero Section
- Giant animated miss counter: computed from CSV (`total_misses` sum)
- Subtitle: "tirs manqués en carrière sur le circuit IBU World Cup"
- Secondary stat: penalty loop km — computed as `total_penalties * 150 / 1000`
- Dramatic tagline (e.g. "Quand le génie rencontre la gâchette")

### 2. Career Overview Stats Bar
- Total races: `COUNT(rows)`
- Total misses: `SUM(total_misses)`
- Total penalty loops: `SUM(total_penalties)`
- Average misses per race: computed
- Miss rate % (total misses / total shots possible): computed from `NrShootings * 5`
- Worst season by miss rate: computed

### 3. Misses Per Season Chart (bar chart)
- X-axis: seasons (formatted as "2020-21", "2021-22", etc.)
- Y-axis: total misses
- Highlight the worst season in red

### 4. Hall of Shame — Top 5 Worst Races
- Table sorted by total_misses descending
- Columns: Date, Location, Discipline, Misses, Penalty Loops
- Style the top row like a trophy of shame 🏆❌

### 5. Athlete comparison
- Show a graph of the total cumulative shot miss by Emilien Jacquelin vs Sturla Laegrid. 
- Legend the graph with Emilien Jacquelin quote "Om my god! I've been beaten by an unfaithful guy."

### 6. Miss Streak Finder
- Find the longest streak of shooting events without cleaning all 5 targets

### 7. Hall of Glory — The Bright Side (Light Mode)
- A toggle button (sun/moon icon) in the header switches the entire site between dark "Hall of Misses" mode and light "Hall of Glory" mode
- Light theme: warm cream background (`#fafaf7`), French blue (`#1d4ed8`) + gold (`#d97706`) accents, no red
- In glory mode, a full-width scroll-story article section replaces the shame narrative with an editorial timeline of his greatest moments
- **Content source**: `GLORY.md` — race narratives are editorial text and may be hardcoded (exception to the no-hardcoding rule); this is the only feature where hardcoded content is allowed
- Each story card in the timeline shows:
  - Date + location + discipline + medal emoji (🥇🥈🥉)
  - A 1–2 sentence editorial narrative (from GLORY.md)
  - CSV-derived shooting stat for that specific race (e.g., "20/20 — clean shoot" or misses count), fetched by matching `StartDate` + `DisciplineLabel`
  - A visual medal badge / ribbon decoration
- Races to feature (from GLORY.md, in chronological order):
  1. 2020-02-16 — Pursuit, Worlds Antholz-Anterselva 🥇 (perfect 20/20)
  2. 2020-02 — Relay + Mass Start bronze, Worlds Antholz 🥇🥉
  3. 2021-02-14 — Pursuit, Worlds Pokljuka 🥇 (back-to-back world title, 20/20)
  4. 2021-02 — Sprint bronze, Worlds Pokljuka 🥉
  5. 2021-12-19 — Mass Start, Le Grand-Bornand 🥇 (first regular WC win, 19/20)
  6. 2022-02 — Beijing Olympics: Mixed Relay silver 🥈 + Men's Relay silver 🥈
  7. 2023-02 — Men's Relay gold, Worlds Oberhof 🥇
  8. 2025 — Mixed Relay gold, Worlds Lenzerheide 🥇
  9. 2026-02 — Milan-Cortina: Pursuit bronze 🥉 (first individual Olympic medal, Pantani tribute) + Relay gold 🥇
- CSS custom properties drive the theme; all existing features adapt their colors via those variables
- Toggle state persists in `localStorage`
- On mobile, the toggle is accessible and the story cards stack vertically

---

## Code Rules

- Always check `data/penalty_loop.csv` structure before coding
- Parse CSV with Papa Parse; filter on `FullName === "Emilien JACQUELIN"` in JS
- Handle `NA` values gracefully (treat as 0 or skip)
- Season formatting: convert "2122" → "2021-22", "2021" → "2020-21" etc.
- **Never hardcode stats** — every number displayed (totals, averages, records, chart values) must be computed from the CSV at runtime. No magic numbers.
- All charts must be fully data-driven: labels, datasets, and colors derived from parsed CSV data
- Mobile-friendly layout (responsive grid)
- Keep all asset paths relative (for GitHub Pages compatibility)
- Comment the code clearly
- After each feature, verify it renders correctly before moving to the next