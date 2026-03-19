# Biathlon Results API Client
# Based on: https://github.com/prtkv/biathlonresults

library(httr2)
library(dplyr)
library(purrr)

# Constants ----------------------------------------------------------------

ROOT_API <- "http://biathlonresults.com/modules/sportapi/api/"

# Level types for events
LEVEL_TYPES <- list(
  ALL = "0",
  WORLD_CUP = "1",
  IBU_CUP = "2",
  JUNIOR_CUP = "3"
)

# Analysis types for analytic results
ANALYSIS_TYPES <- list(
  SHOOTING = "SHO",
  COURSE_TIME = "CT",
  RANGE_TIME = "RT"
)

# Helper Functions ---------------------------------------------------------

#' Make API request
#' @param method API endpoint method name
#' @param params Named list of query parameters
#' @return Parsed JSON response (list or data frame)
api_request <- function(method, params = NULL) {
  request(ROOT_API) |>
    req_url_path_append(method) |>
    req_url_query(!!!params) |>
    req_error(is_error = \(resp) FALSE) |>
    req_perform() |>
    resp_body_json(simplifyVector = TRUE)
}

# API Functions ------------------------------------------------------------

#' Get list of organizers
organizers <- function() {
  api_request("Organizers")
}

#' Get list of seasons
seasons <- function() {
  api_request("Seasons")
}

#' Get events (schedule) for a season
#' @param season_id Season identifier (e.g., "2324" for 2023/2024)
#' @param level Level type: "0" (all), "1" (World Cup), "2" (IBU Cup), "3" (Junior Cup)
events <- function(season_id, level = "0") {
  api_request("Events", list(SeasonId = season_id, Level = level))
}

#' Get list of competitions (races) in an event
#' @param event_id Event identifier
competitions <- function(event_id) {
  api_request("Competitions", list(EventId = event_id))
}

#' Get list of cups for a season
#' @param season_id Season identifier (e.g., "1819" for 2018/2019)
cups <- function(season_id) {
  api_request("Cups", list(SeasonId = season_id))
}

#' Get cup results/standings
#' @param cup_id Cup identifier (e.g., "BT1819SWRLCP__SMTS" for Men's WC Total 2018/2019)
cup_results <- function(cup_id) {
  api_request("CupResults", list(CupId = cup_id))
}

#' Search for athletes
#' @param family_name Family name (surname)
#' @param given_name Given name (first name)
athletes <- function(family_name = "", given_name = "") {
  api_request("Athletes", list(FamilyName = family_name, GivenName = given_name))
}

#' Get athlete information by IBU ID
#' @param ibu_id IBU athlete identifier
cisbios <- function(ibu_id) {
  api_request("CISBios", list(IBUId = ibu_id))
}

#' Get all race results for an athlete
#' @param ibu_id IBU athlete identifier
all_results <- function(ibu_id) {
  api_request("AllResults", list(IBUId = ibu_id))
}

#' Get race results
#' @param race_id Race identifier
results <- function(race_id) {
  api_request("Results", list(RaceId = race_id))
}

#' Get analytic results for a race
#' @param race_id Race identifier
#' @param type_id Analysis type: "SHO" (shooting), "CT" (course time), "RT" (range time)
analytic_results <- function(race_id, type_id) {
  api_request("AnalyticResults", list(RaceId = race_id, TypeId = type_id))
}

#' Get statistics
#' @param statistic_id Statistic identifier
#' @param stat_id Stat identifier
#' @param by_what Grouping: "ATH" (athlete), etc.
#' @param gender_id Gender: "M" or "W"
#' @param season_id Optional season identifier
#' @param organizer_id Optional organizer identifier
#' @param ibu_id Optional IBU athlete identifier
#' @param nat Optional nation code
stats <- function(statistic_id, stat_id, by_what, gender_id,
                  season_id = "", organizer_id = "", ibu_id = "", nat = "") {
  api_request("Stats", list(
    StatisticId = statistic_id,
    StatId = stat_id,
    byWhat = by_what,
    SeasonId = season_id,
    OrganizerId = organizer_id,
    GenderId = gender_id,
    IBUId = ibu_id,
    Nat = nat
  ))
}

# Convenience Functions ----------------------------------------------------

#' Get World Cup events for a season
#' @param season_id Season identifier
world_cup_events <- function(season_id) {
  events(season_id, level = LEVEL_TYPES$WORLD_CUP)
}

#' Get all competitions for a season
#' @param season_id Season identifier
#' @param level Optional level filter
season_competitions <- function(season_id, level = "0") {
  season_events <- events(season_id, level)
  
  if (is.null(season_events) || length(season_events) == 0) {
    return(NULL)
  }
  
  # Extract event IDs
  if (is.data.frame(season_events)) {
    event_ids <- season_events$EventId
  } else if (is.list(season_events)) {
    event_ids <- map_chr(season_events, "EventId")
  } else {
    return(NULL)
  }
  
  # Get competitions for each event
  map(event_ids, competitions) |>
    list_rbind()
}

#' Search athlete by full name
#' @param full_name Full name (will split on first space)
search_athlete <- function(full_name) {
  name_parts <- strsplit(full_name, " ", fixed = TRUE)[[1]]
  
  if (length(name_parts) == 1) {
    athletes(family_name = name_parts[1])
  } else {
    given <- name_parts[1]
    family <- paste(name_parts[-1], collapse = " ")
    athletes(family_name = family, given_name = given)
  }
}
