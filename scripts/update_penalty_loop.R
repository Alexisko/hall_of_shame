# ============================================================================
# update_penalty_loop.R
# Penalty Loop CSV Incremental Updater
#
# Appends new Men + Mixed races from the current season to
# data/prepared/penalty_loop.csv. Safe to run headlessly (GitHub Actions).
#
# Typical workflow:
#   Rscript scripts/update_penalty_loop.R
# ============================================================================

library(tidyverse)
library(httr2)

source("scripts/biathlon_api.R")

# ── Configuration ─────────────────────────────────────────────────────────────

CSV_PATH   <- "data/penalty_loop.csv"
SLEEP_TIME <- 0.5   # seconds between API calls

ATHLETES   <- c("Emilien JACQUELIN", "Sturla Holm LAEGREID")

# ── Helpers ───────────────────────────────────────────────────────────────────

parse_shooting <- function(shooting, is_relay = FALSE) {
  if (is.na(shooting) || shooting == "") {
    return(list(penalties = NA_real_, spares = NA_real_, misses = NA_real_))
  }
  if (is_relay) {
    legs      <- str_split(shooting, " ")[[1]]
    penalties <- as.numeric(str_extract(legs, "^\\d+"))
    spares    <- as.numeric(str_extract(legs, "\\d+$"))
    list(penalties = penalties, spares = spares, misses = penalties + spares)
  } else {
    misses <- as.numeric(str_split(shooting, "\\+")[[1]])
    list(penalties = misses, spares = rep(0L, length(misses)), misses = misses)
  }
}

# Infer the current IBU season string from today's date.
# Biathlon seasons start in October:
#   Oct–Dec YYYY  →  "YY(Y+1)"  e.g. Oct 2025 → "2526"
#   Jan–Sep YYYY  →  "(Y-1)YY"  e.g. Mar 2026 → "2526"
current_season_id <- function() {
  today <- Sys.Date()
  year  <- as.integer(format(today, "%Y"))
  month <- as.integer(format(today, "%m"))
  start <- if (month >= 10) year else year - 1L
  sprintf("%02d%02d", start %% 100, (start + 1L) %% 100)
}

# Fetch results for one race; returns a tibble with normalised columns or NULL.
safe_results <- function(race_id) {
  Sys.sleep(SLEEP_TIME)
  tryCatch({
    raw  <- results(race_id)
    if (is.null(raw) || length(raw) == 0) return(NULL)
    data <- if (is.list(raw) && "Results" %in% names(raw)) raw$Results
            else if (is.data.frame(raw)) raw
            else NULL
    if (is.null(data) || length(data) == 0) return(NULL)
    data <- as_tibble(data)
    # Normalise: construct FullName (GivenName FAMILYNAME) and RankInt
    if (!"FullName" %in% names(data) && all(c("GivenName", "FamilyName") %in% names(data))) {
      data <- data |> mutate(FullName = paste(GivenName, FamilyName))
    }
    if (!"RankInt" %in% names(data) && "Rank" %in% names(data)) {
      data <- data |> mutate(RankInt = suppressWarnings(as.integer(Rank)))
    }
    data |> mutate(RaceId = race_id)
  }, error = function(e) {
    message("  [API error] ", e$message)
    NULL
  })
}

# Parse shootings and expand to per-shooting columns for one race's result rows.
process_race_results <- function(race_df, comp_row) {
  race_df |>
    filter(!is.na(Shootings), FullName %in% ATHLETES) |>
    select(any_of(c("FullName", "Shootings", "RankInt"))) |>
    mutate(
      RaceId          = comp_row$RaceId,
      Season          = comp_row$Season,
      StartDate       = comp_row$StartDate,
      Location        = comp_row$Location,
      DisciplineId    = comp_row$DisciplineId,
      DisciplineLabel = comp_row$DisciplineLabel,
      GenderLabel     = comp_row$GenderLabel,
      IsRelay         = comp_row$IsRelay,
      NrShootings     = comp_row$NrShootings,
      parsed          = map2(Shootings, IsRelay, parse_shooting),
      total_misses    = map_dbl(parsed, \(x) sum(x$misses)),
      total_penalties = map_dbl(parsed, \(x) sum(x$penalties)),
      total_spares    = map_dbl(parsed, \(x) sum(x$spares)),
      miss_1          = map_dbl(parsed, \(x) x$misses[1]),
      miss_2          = map_dbl(parsed, \(x) if (length(x$misses)    >= 2) x$misses[2]    else NA_real_),
      miss_3          = map_dbl(parsed, \(x) if (length(x$misses)    >= 3) x$misses[3]    else NA_real_),
      miss_4          = map_dbl(parsed, \(x) if (length(x$misses)    >= 4) x$misses[4]    else NA_real_),
      penalty_1       = map_dbl(parsed, \(x) x$penalties[1]),
      penalty_2       = map_dbl(parsed, \(x) if (length(x$penalties) >= 2) x$penalties[2] else NA_real_),
      penalty_3       = map_dbl(parsed, \(x) if (length(x$penalties) >= 3) x$penalties[3] else NA_real_),
      penalty_4       = map_dbl(parsed, \(x) if (length(x$penalties) >= 4) x$penalties[4] else NA_real_),
    ) |>
    select(-parsed) |>
    mutate(
      total_penalties = ifelse(DisciplineLabel %in% c("Individual", "SI"), 0, total_penalties),
      across(starts_with("penalty_"), \(x) ifelse(DisciplineLabel %in% c("Individual", "SI"), 0, x))
    ) |>
    select(
      RaceId, Season, StartDate, Location, DisciplineId, DisciplineLabel,
      GenderLabel, IsRelay, NrShootings, FullName, Shootings, RankInt,
      total_misses, total_penalties, total_spares,
      miss_1, miss_2, miss_3, miss_4,
      penalty_1, penalty_2, penalty_3, penalty_4
    )
}

# ── Main ──────────────────────────────────────────────────────────────────────

message("=======================================================")
message("  PENALTY LOOP CSV UPDATER")
message("=======================================================\n")

# 1. Read existing CSV → extract already-processed RaceIds
if (file.exists(CSV_PATH)) {
  existing     <- read_csv(CSV_PATH, show_col_types = FALSE,
                           col_types = cols(Season = col_character()))
  existing_ids <- unique(existing$RaceId)
  message("Existing CSV: ", nrow(existing), " row(s), ", length(existing_ids), " race(s)")
} else {
  message("No existing CSV found — will create from scratch")
  existing     <- tibble()
  existing_ids <- character(0)
}

# 2. Detect current season
season_id <- current_season_id()
message("Current season: ", season_id, "\n")

# 3. Fetch competitions from API (level = "1" = World Cup)
message("Fetching competitions from API (level 1)...")
comps <- tryCatch(
  season_competitions(season_id, level = "1"),
  error = function(e) { message("[API error] ", e$message); NULL }
)

if (is.null(comps) || nrow(comps) == 0) {
  message("[warn] No competitions returned from API — aborting")
  quit(save = "no", status = 0)
}

# Derive columns not returned by the API
DISCIPLINE_LABELS <- c(
  IN = "Individual", SP = "Sprint", PU = "Pursuit",
  MS = "Mass Start", RL = "Relay", SR = "Single Mixed Relay"
)
GENDER_LABELS <- c(SW = "Women", SM = "Men", MX = "Mixed")

comps <- comps |>
  mutate(
    Season          = season_id,
    StartDate       = as.Date(substr(StartTime, 1, 10)),
    GenderLabel     = GENDER_LABELS[catId],
    DisciplineLabel = DISCIPLINE_LABELS[DisciplineId],
    IsRelay         = DisciplineId %in% c("RL", "SR")
  )

# 4. Filter: Final + not already in CSV + Men or Mixed
new_comps <- comps |>
  filter(
    StatusText == "Final",
    !(RaceId %in% existing_ids),
    GenderLabel %in% c("Men", "Mixed")
  )

message("Competitions in API : ", nrow(comps))
message("New final Men/Mixed : ", nrow(new_comps))

if (nrow(new_comps) == 0) {
  message("\n✓ No new races — penalty_loop.csv is up to date")
  quit(save = "no", status = 0)
}

walk(new_comps$RaceId, \(id) message("  - ", id))
message("")

# 5–6. Fetch results + parse shootings for each new race
new_rows <- map(seq_len(nrow(new_comps)), function(i) {
  comp_row <- new_comps[i, ]
  race_id  <- comp_row$RaceId
  message("Processing ", race_id, "...")

  race_df <- safe_results(race_id)
  if (is.null(race_df)) {
    message("  [warn] No results returned — skipping")
    return(NULL)
  }
  if (!"Shootings" %in% names(race_df)) {
    message("  [warn] No Shootings column — skipping")
    return(NULL)
  }

  processed <- process_race_results(race_df, comp_row)
  message("  ✓ ", nrow(processed), " athlete row(s)")
  processed
}) |>
  list_rbind()

if (nrow(new_rows) == 0) {
  message("\n[warn] No rows parsed — CSV unchanged")
  quit(save = "no", status = 0)
}

# 7. Append + write CSV
updated <- bind_rows(existing, new_rows)
write_csv(updated, CSV_PATH)

message("\n=======================================================")
message("  DONE: appended ", nrow(new_rows), " row(s) from ",
        nrow(new_comps), " race(s)")
message("  CSV now has ", nrow(updated), " total row(s)")
message("=======================================================")
