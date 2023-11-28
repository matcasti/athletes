## code to prepare `DATASET` dataset goes here


# Prepare workspace -------------------------------------------------------

## Load libraries
library(data.table)

## Load the dataset
raw_dat <- fread(input = "data-raw/raw_data.csv")

# Explore the dataset -----------------------------------------------------

str(raw_dat)
## - There is multiple missing (>90% of the variables) values from a few subjects (remove them).
## - Adapt the format of the variables (string numbers to numbers, lowercase strings, etc).

# Data treatment ----------------------------------------------------------

## Overall view of character variables
raw_dat[, sapply(raw_dat, is.character), with = FALSE]

## Transform age into a number format
raw_dat[, edad := as.numeric(edad)]

## Change variables with a comma (",") as a decimal separator to a dot (".")
## and then into a number format
comma_vars <- sapply(X = raw_dat,
                     FUN = function(i) {
                       any(grepl(pattern = "\\,", x = i))
                       }) |> which(useNames = TRUE)

raw_dat[, (comma_vars) := lapply(.SD, function(i) {
  gsub("\\,", "\\.", i) |> as.numeric()
}), .SDcols = comma_vars]


## Remove records with large number of missing values
exclude_ids <- raw_dat[, list(remove = sum(is.na(.SD))/ncol(raw_dat) > .9), record_id
                       ][which(remove), record_id]

raw_dat <- raw_dat[!record_id %in% exclude_ids]

## Transform character vectors into factors
raw_dat[, deporte := factor(deporte)]
raw_dat[, dominancia_mmii := factor(dominancia_mmii)]
raw_dat[, dominancia_mmss := factor(dominancia_mmss)]

## Había una categoría de N/A que se le asigna NA
raw_dat[posicion == "N/A", posicion := NA]
raw_dat[, posicion := factor(x = trimws(posicion))]

## Anonymize record ids
raw_dat[, id := rleid(record_id)]
raw_dat[, record_id := NULL]

# Prepare to shape to long format (for HRV measurements) ------------------

## Identify the outcome variables
ind <- grep("_pre$|_post$", names(raw_dat), value = TRUE)
raw_dat[, (ind) := lapply(.SD, as.numeric), .SDcols = ind]

## Melt into long format
raw_long <- melt.data.table(raw_dat, measure.vars = ind)

## Create a time (factor) variable to identify pre and post
raw_long[, time := fcase(
  grepl("_pre$", variable), "Pre",
  grepl("_post$", variable), "Post"
)]
raw_long[, time := factor(time, levels = c("Pre", "Post"))]

## Remove pre/post end-tag from the variable label
hrv_long <- raw_long[, variable := gsub("_pre$|_post$", "", variable)]

## Back to wide format (but keeping a row for each time point of HRV assessment)
## (i.e., basically, two rows per subject, so 31 subjects times 2 assessments are
## equals to 62 observations in total).
hrv_long <- dcast.data.table(raw_long, id + time ~ variable, value.var = "value")

## Now back to merge the newly two-observations per subject with the wide format
## (excluding, of course, the original HRV variables).
ind <- merge.data.table(hrv_long, raw_dat[, .SD, .SDcols = !ind], by = "id")


# Minor details -----------------------------------------------------------

## Líbero to Libero (without accent)
ind[posicion == "Líbero", posicion := "Libero"]
ind[, posicion := factor(trimws(posicion))]

# Export the dataset ------------------------------------------------------

str(ind)

fwrite(ind, file = "inst/extdata/ind.csv")
usethis::use_data(ind, overwrite = TRUE)
