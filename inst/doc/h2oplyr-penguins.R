## ----setup, include=FALSE-----------------------------------------------------
library(h2oplyr)
port <- Sys.getenv("H2OPLYR_VIGNETTE_PORT")
if (nzchar(port)) {
  h2o::h2o.init(ip = "127.0.0.1", port = as.integer(port), startH2O = FALSE)
}
connected <- h2o_available()
knitr::opts_chunk$set(collapse = TRUE, comment = "#>", eval = connected)
if (connected) h2o::h2o.no_progress()

## ----connect-instructions, eval=FALSE-----------------------------------------
# # Run this yourself, once per session. Loading h2oplyr never starts a server.
# h2o::h2o.init(nthreads = 2, max_mem_size = "2G")
# library(h2oplyr)

## ----display-helpers----------------------------------------------------------
# Escape labels before placing them inside HTML.
html_text <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  gsub(">", "&gt;", x, fixed = TRUE)
}

# Show bounded remote values without creating a local data.frame.
preview_h2o <- function(x, title, columns = names(as_h2o(x)), rows = 4L) {
  frame <- as_h2o(x)
  stopifnot(inherits(frame, "H2OFrame"), rows >= 1L, rows <= 6L,
            all(columns %in% names(frame)))
  types <- unlist(h2o::h2o.getTypes(frame[, columns]), use.names = FALSE)
  shown <- min(rows, nrow(frame))
  cat('\n<div class="result"><h3>', html_text(title), '</h3>', sep = "")
  cat('<p class="result-meta">H2OFrame · ', nrow(frame), ' rows × ',
      ncol(frame), ' columns · showing ', shown, ' rows and ',
      length(columns), ' columns</p><div class="table-scroll"><table><thead><tr>',
      sep = "")
  for (j in seq_along(columns)) {
    alignment <- if (types[j] %in% c("int", "real")) ' class="num"' else ""
    cat('<th scope="col"', alignment, '>', html_text(columns[j]), '</th>', sep = "")
  }
  cat('</tr></thead><tbody>')
  for (i in seq_len(shown)) {
    cat('<tr>')
    for (j in seq_along(columns)) {
      # Two-step indexing keeps the cell as a remote frame in H2O.
      cell <- frame[i, ][, columns[j]]
      stopifnot(inherits(cell, "H2OFrame"))
      numeric_column <- types[j] %in% c("int", "real")
      alignment <- if (numeric_column) ' class="num"' else ""
      if (h2o::h2o.sum(is.na(cell)) == 1) {
        value <- '<span class="missing">NA</span>'
      } else if (numeric_column) {
        number <- h2o::h2o.sum(cell)
        value <- if (number == floor(number)) sprintf("%.0f", number) else sprintf("%.2f", number)
      } else {
        # Re-encode in H2O so the domain contains only this cell's label.
        label <- h2o::h2o.levels(h2o::h2o.asfactor(h2o::h2o.ascharacter(cell)))
        stopifnot(length(label) == 1L)
        value <- html_text(as.character(label[[1L]]))
      }
      cat('<td', alignment, '>', value, '</td>', sep = "")
    }
    cat('</tr>')
  }
  cat('</tbody></table></div></div>\n\n')
  invisible(NULL)
}

# Only a successful, evaluated assertion receives a green check.
verify_output <- function(condition, label) {
  stopifnot(isTRUE(condition))
  cat('\n<p class="check"><strong>Verified.</strong> ', html_text(label), '</p>\n\n', sep = "")
}

## ----import-------------------------------------------------------------------
# Import the bundled CSV and confirm its dimensions.
penguins <- h_penguins()
stopifnot(nrow(as_h2o(penguins)) == 344)


## ----import-output, echo=FALSE, results="asis"--------------------------------
preview_h2o(penguins, "The imported penguins", c("species", "island", "bill_length_mm", "body_mass_g"))
verify_output(nrow(as_h2o(penguins)) == 344 && ncol(as_h2o(penguins)) == 8, "344 observations and 8 variables imported into H2O.")

## ----select-------------------------------------------------------------------
# Keep relevant columns, then rename and order the bill measurements.
bills <- h_select(penguins, species, starts_with("bill_"))
measurements <- h_select(penguins, where(is.numeric))
renamed <- h_rename(bills, bill_length = bill_length_mm)
relocated <- h_relocate(renamed, species, .before = bill_length)

## ----select-output, echo=FALSE, results="asis"--------------------------------
preview_h2o(bills, "Selected bill measurements")
preview_h2o(measurements, "Numeric variables", rows = 3)
preview_h2o(relocated, "Renamed and relocated columns")
verify_output(identical(names(as_h2o(bills)), c("species", "bill_length_mm", "bill_depth_mm")) &&
  identical(names(as_h2o(relocated)), c("species", "bill_length", "bill_depth_mm")),
  "Selection, renaming and final column order match the requested schema.")

## ----missing------------------------------------------------------------------
# Compare complete-case filtering with two measurement thresholds.
complete_penguins <- h_drop_na(penguins)
stopifnot(nrow(as_h2o(complete_penguins)) == 333)
cat("Complete observations:", nrow(as_h2o(complete_penguins)), "\n")
large <- h_filter(penguins, body_mass_g >= 5000)
cat("Penguins weighing at least 5000 g:", nrow(as_h2o(large)), "\n")
bill_range <- h_filter(penguins, h_between(bill_length_mm, 40, 50))
cat("Penguins with bill length from 40 to 50 mm:", nrow(as_h2o(bill_range)), "\n")

## ----missing-output, echo=FALSE, results="asis"-------------------------------
preview_h2o(complete_penguins, "Complete cases", c("species", "bill_length_mm", "body_mass_g", "sex"))
preview_h2o(large, "Body mass of at least 5,000 g", c("species", "body_mass_g"))
preview_h2o(bill_range, "Bill length between 40 and 50 mm", c("species", "bill_length_mm"))
verify_output(nrow(as_h2o(complete_penguins)) == 333 &&
  h2o::h2o.min(as_h2o(large)[, "body_mass_g"]) >= 5000 &&
  h2o::h2o.min(as_h2o(bill_range)[, "bill_length_mm"]) >= 40 &&
  h2o::h2o.max(as_h2o(bill_range)[, "bill_length_mm"]) <= 50,
  "Complete-case count and both filter boundaries checked over the full remote results.")

## ----missing-explicit---------------------------------------------------------
# Select the missing body masses explicitly.
missing_mass <- h_filter(penguins, is.na(body_mass_g))
stopifnot(nrow(as_h2o(missing_mass)) == 2)

## ----missing-explicit-output, echo=FALSE, results="asis"----------------------
preview_h2o(missing_mass, "The two missing body masses", c("species", "bill_length_mm", "body_mass_g"))
verify_output(h2o::h2o.sum(is.na(as_h2o(missing_mass)[, "body_mass_g"])) == 2,
  "Both retained rows have a missing body mass.")

## ----mutate-------------------------------------------------------------------
# Drop only missing mass, then derive units and a mass category.
prepared <- penguins |>
  h_drop_na(body_mass_g) |>
  h_mutate(
    mass_kg = body_mass_g / 1000,
    mass_band = h_case_when(
      body_mass_g >= 5000 ~ "large",
      body_mass_g >= 3500 ~ "medium",
      TRUE ~ "small"
    )
  )
stopifnot(nrow(as_h2o(prepared)) == 342)
cat("Total measured mass (kg):",
    h2o::h2o.sum(as_h2o(prepared)[, "mass_kg"]), "\n")

## ----mutate-output, echo=FALSE, results="asis"--------------------------------
preview_h2o(prepared, "Mass in grams, kilograms and bands", c("species", "body_mass_g", "mass_kg", "mass_band"))
verify_output(nrow(as_h2o(prepared)) == 342 &&
  h2o::h2o.max(abs(as_h2o(prepared)[, "mass_kg"] * 1000 - as_h2o(prepared)[, "body_mass_g"])) < 1e-8,
  "342 measured masses retained; the kg-to-g conversion agrees for every row.")

## ----summaries----------------------------------------------------------------
# Compute counts and means inside H2O, grouped by species.
by_species <- h_summarize(
  penguins,
  observations = n(),
  mean_mass_g = mean(body_mass_g, na.rm = TRUE),
  mean_bill_mm = mean(bill_length_mm, na.rm = TRUE),
  .by = species
)

## ----summary-results, echo=FALSE, results="asis"------------------------------
preview_h2o(h_arrange(by_species, species), "Species-level summary", rows = 3)
verify_output(nrow(as_h2o(by_species)) == 3 &&
  h2o::h2o.sum(as_h2o(by_species)[, "observations"]) == 344,
  "Three groups account for all 344 observations.")

## ----across-------------------------------------------------------------------
# Apply unit conversion and grouped means to multiple columns.
scaled <- h_mutate(
  bills,
  h_across(starts_with("bill_"), list(cm = function(z) z / 10))
)
average_bills <- bills |>
  h_drop_na() |>
  h_group_by(species) |>
  h_summarize_across(starts_with("bill_"), list(average = mean))

## ----across-output, echo=FALSE, results="asis"--------------------------------
preview_h2o(scaled, "Millimetres converted to centimetres", c("species", "bill_length_mm", "bill_length_mm_cm", "bill_depth_mm_cm"))
preview_h2o(h_arrange(average_bills, species), "Mean bill measurements by species", rows = 3)
verify_output(h2o::h2o.max(abs(as_h2o(scaled)[, "bill_length_mm_cm"] * 10 - as_h2o(scaled)[, "bill_length_mm"]), na.rm = TRUE) < 1e-8 &&
  nrow(as_h2o(average_bills)) == 3, "Across conversion and the three grouped summaries checked.")

## ----joins--------------------------------------------------------------------
# Attach a unique species summary to each observed mass.
enriched <- h_left_join(
  prepared, by_species,
  by = "species", relationship = "many-to-one"
)
stopifnot(nrow(as_h2o(enriched)) == nrow(as_h2o(prepared)))
enriched <- h_mutate(enriched, mass_minus_species_mean = body_mass_g - mean_mass_g)

## ----joins-output, echo=FALSE, results="asis"---------------------------------
preview_h2o(h_arrange(enriched, species, body_mass_g), "Observed mass versus its species mean",
  c("species", "body_mass_g", "mean_mass_g", "mass_minus_species_mean"))
verify_output(nrow(as_h2o(enriched)) == 342 &&
  h2o::h2o.sum(is.na(as_h2o(enriched)[, "mean_mass_g"])) == 0,
  "The join preserves all 342 measured penguins and matches a species mean to each.")

## ----reshape------------------------------------------------------------------
# Use species-level summaries so the ID is naturally unique.
wide <- h_summarize(
  penguins,
  bill_length_mm = mean(bill_length_mm, na.rm = TRUE),
  bill_depth_mm = mean(bill_depth_mm, na.rm = TRUE),
  .by = species
)
long <- h_pivot_longer(
  wide, starts_with("bill_"),
  names_to = "measurement", values_to = "mean_mm"
)
stopifnot(nrow(as_h2o(long)) == 6)
restored <- h_pivot_wider(long, measurement, mean_mm)
stopifnot(nrow(as_h2o(restored)) == 3)

## ----reshape-output, echo=FALSE, results="asis"-------------------------------
preview_h2o(h_arrange(wide, species), "Before pivoting: one row per species", rows = 3)
preview_h2o(h_arrange(long, species, measurement), "Long format: one row per measurement", rows = 6)
preview_h2o(h_arrange(restored, species), "Back to wide format", rows = 3)
wide_sorted <- as_h2o(h_arrange(wide, species))
restored_sorted <- as_h2o(h_arrange(restored, species))
verify_output(nrow(as_h2o(long)) == 6 && nrow(restored_sorted) == 3 &&
  h2o::h2o.max(abs(wide_sorted[, "bill_length_mm"] - restored_sorted[, "bill_length_mm"])) < 1e-8 &&
  h2o::h2o.max(abs(wide_sorted[, "bill_depth_mm"] - restored_sorted[, "bill_depth_mm"])) < 1e-8,
  "Wide → long → wide preserves both mean measurements for every species.")

## ----sampling-----------------------------------------------------------------
# Sample reproducibly, retain tied maxima and compute a sorted lag.
sample_penguins <- h_slice_sample(prepared, n = 12, seed = 2026)
stopifnot(nrow(as_h2o(sample_penguins)) == 12)
heaviest <- h_slice_max(prepared, body_mass_g, n = 3, with_ties = TRUE)
cat("Rows among the three heaviest positions, including ties:",
    nrow(as_h2o(heaviest)), "\n")
ordered <- h_arrange(prepared, body_mass_g)
ordered <- h_mutate(ordered, previous_mass = h_lag(body_mass_g))

## ----sampling-output, echo=FALSE, results="asis"------------------------------
preview_h2o(sample_penguins, "A seeded sample of 12 penguins", c("species", "body_mass_g", "bill_length_mm"))
preview_h2o(h_arrange(heaviest, desc(body_mass_g)), "The heaviest positions, including ties", c("species", "body_mass_g"), rows = 6)
preview_h2o(ordered, "Previous mass after sorting", c("species", "body_mass_g", "previous_mass"))
ordered_frame <- as_h2o(ordered)
first_lag <- ordered_frame[1, ][, "previous_mass"]
verify_output(nrow(as_h2o(sample_penguins)) == 12 && h2o::h2o.sum(is.na(first_lag)) == 1 &&
  h2o::h2o.max(abs(ordered_frame[2:nrow(ordered_frame), ][, "previous_mass"] -
    ordered_frame[1:(nrow(ordered_frame)-1), ][, "body_mass_g"])) < 1e-8,
  "Sample size is 12; the first lag is missing and every later lag matches the preceding mass.")

## ----species-windows----------------------------------------------------------
# Number the input rows before sorting, then use that position to break ties.
species_order <- penguins |>
  h_filter(!is.na(body_mass_g)) |>
  h_mutate(input_row = h_row_number()) |>
  h_arrange(species, body_mass_g, input_row)
species_windows <- species_order |>
  h_group_by(species) |>
  h_mutate(previous_mass = h_lag(body_mass_g),
           mean_last_three = h_roll_mean(body_mass_g, k = 3),
           mass_rank = h_min_rank(desc(body_mass_g)),
           position = h_row_number())
# Grouping persists until removed explicitly.
stopifnot(identical(h_group_vars(species_windows), "species"))
first_in_species <- species_windows |> h_ungroup() |> h_filter(position == 1)

## ----species-windows-output, echo=FALSE, results="asis"-----------------------
preview_h2o(species_windows, "Windows within species",
  c("species", "body_mass_g", "previous_mass", "mean_last_three", "mass_rank", "position"))
verify_output(nrow(as_h2o(first_in_species)) == 3 &&
  h2o::h2o.all(is.na(as_h2o(first_in_species)[, "previous_mass"])) &&
  h2o::h2o.all(as_h2o(first_in_species)[, "body_mass_g"] ==
    as_h2o(first_in_species)[, "mean_last_three"]),
  "Each species starts with a missing lag and a one-row partial mean.")

## ----window-boundaries--------------------------------------------------------
reference <- h2o::h2o.uploadFile(
  system.file("extdata", "windows.csv", package = "h2oplyr"),
  na.strings = "NA",
  col.types = c("numeric", "enum", "enum", rep("numeric", 15)))
observations <- h2o_tbl(reference[, c("id", "group", "subgroup", "amount")])
windows <- h_mutate(observations,
  prev = h_lag(amount), next_amount = h_lead(amount),
  roll = h_roll_mean(amount, k = 3),
  roll_rm = h_roll_mean(amount, k = 3, na.rm = TRUE),
  full = h_roll_mean(amount, k = 3, partial = FALSE),
  rank_desc = h_min_rank(desc(amount)), row = h_row_number(),
  .by = c(group, subgroup))
# .by does not attach grouping to the result.
stopifnot(length(h_group_vars(windows)) == 0)
example_group <- h_filter(windows, group == "A", subgroup == "x")

## ----window-boundaries-output, echo=FALSE, results="asis"---------------------
preview_h2o(example_group, "Ties and lags in one group",
  c("id", "amount", "prev", "roll", "rank_desc", "row"), rows = 5)
preview_h2o(example_group, "Three rolling-mean policies",
  c("id", "amount", "roll", "roll_rm", "full"), rows = 5)
window_frame <- as_h2o(windows)
for (column in c("prev", "roll", "roll_rm", "full", "rank_desc", "row")) {
  stopifnot(h2o::h2o.all(is.na(window_frame[, column]) == is.na(reference[, column])),
    h2o::h2o.sum(abs(window_frame[, column] - reference[, column]), na.rm = TRUE) < 1e-8)
}
verify_output(h2o::h2o.all(window_frame[, "id"] == reference[, "id"]),
  "All six window columns match the independent reference, including missing values; input order is unchanged.")

## ----transaction-windows------------------------------------------------------
transactions <- observations |>
  h_select(id, group, amount) |>
  h_rename(txn_id = id, customer_id = group) |>
  h_mutate(txn_time = txn_id) |>
  h_filter(!is.na(amount)) |>
  h_arrange(customer_id, txn_time, txn_id)
transaction_windows <- h_mutate(transactions,
  prev_amount = h_lag(amount),
  roll_mean = h_roll_mean(amount, k = 3, partial = TRUE),
  rank_amount = h_min_rank(desc(amount)),
  .by = customer_id)
customer_summary <- h_summarize(transaction_windows,
  observations = n(), average_window = mean(roll_mean), .by = customer_id)

## ----transaction-windows-output, echo=FALSE, results="asis"-------------------
preview_h2o(customer_summary, "Aggregate after customer windows")
verify_output(h2o::h2o.sum(as_h2o(customer_summary)[, "observations"]) ==
  nrow(as_h2o(transactions)), "Every retained transaction contributes to a customer summary.")

## ----testing-instructions, eval=FALSE-----------------------------------------
# h2o::h2o.init(nthreads = 2, max_mem_size = "2G")
# library(h2oplyr)
# source(system.file("examples", "examples.R", package = "h2oplyr"))
# for (nm in names(examples)) eval(examples[[nm]])
# source(system.file("examples", "regressions.R", package = "h2oplyr"))

## ----execution-summary, echo=FALSE, results="asis", eval=TRUE-----------------
if (connected) {
  cat('<p class="check"><strong>Executed with H2O.</strong> R ',
      as.character(getRversion()), '; h2oplyr ', as.character(packageVersion("h2oplyr")),
      '; h2o ', as.character(packageVersion("h2o")),
      '. All tutorial assertions completed during rendering.</p>\n', sep = "")
} else {
  cat('<p class="caja-aviso"><strong>Code-only rebuild.</strong> No H2O server was connected. ',
      'The transformation chunks and their previews were skipped; no successful execution is claimed.</p>\n')
}

