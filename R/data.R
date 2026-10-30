#' NCBI BioSample templates
#'
#' Zero-row data frames holding the attribute columns of two NCBI BioSample
#' package templates, in template order. [prepare_sra_metadata()] uses their
#' column names to lay out the BioSample attributes table. A leading asterisk
#' marks a mandatory attribute (e.g. `*sample_name`).
#'
#' @format
#' `Metagenome_environmental`: a tibble with 0 rows and 16 columns, from the
#' Metagenome.environmental.1.0 package (`*sample_name` through
#' `description`).
#'
#' `Microbe`: a tibble with 0 rows and 30 columns, from the Microbe.1.0
#' package (`*sample_name` through `description`).
#'
#' @source NCBI BioSample submission templates,
#'   <https://submit.ncbi.nlm.nih.gov/biosample/template/>
#' @name biosample_templates
#' @aliases Metagenome_environmental Microbe
#' @keywords datasets
NULL

#' @rdname biosample_templates
"Metagenome_environmental"

#' @rdname biosample_templates
"Microbe"
