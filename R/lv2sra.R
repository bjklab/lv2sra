#' Prepare NCBI BioSample and SRA metadata from a biobank sample report
#'
#' Reorganizes a biobank sample report (e.g. `IDSampleByStudy_*.xlsx`) into
#' the two tables needed for an NCBI SRA submission:
#' \enumerate{
#'   \item BioSample attributes, laid out in the column order of an NCBI
#'     BioSample package template (`Metagenome.environmental.1.0.xlsx` or
#'     `Microbe.1.0.xlsx`).
#'   \item SRA metadata, one row per sample, linking each sample to its two
#'     paired-end read files, `<Sample>_R1.fastq.gz` and `<Sample>_R2.fastq.gz`.
#' }
#' Both tables share `sample_name` (the report's "Sample" column), which the
#' NCBI Submission Portal uses to join SRA runs to BioSamples.
#'
#' @param input_xlsx Path to the sample report. Must contain the columns
#'   "Sample", "Sample Type" and "Collection Date"; "External Participant ID"
#'   and "Microbial Species" are used when present.
#' @param package BioSample package to target: `"metagenome"`
#'   (Metagenome.environmental.1.0) or `"microbe"` (Microbe.1.0).
#' @param template_xlsx Path to the matching NCBI BioSample template (.xlsx).
#'   Its `*sample_name` header row defines the output columns and their order.
#'   If `NULL`, the template is looked for in the same directory as
#'   `input_xlsx`.
#' @param output_dir Directory to write the outputs to (two .tsv files and one
#'   .xlsx with both tables). Created if needed. If `NULL`, nothing is written.
#' @param bioproject_accession BioProject accession (e.g. `"PRJNA123456"`).
#'   Leave blank if it is not yet assigned.
#' @param geo_loc_name Mandatory geographic location, using the INSDC country
#'   vocabulary, e.g. `"USA: Pennsylvania, Philadelphia"`.
#' @param lat_lon Latitude and longitude, e.g. `"39.95 N 75.19 W"`. Mandatory
#'   for the metagenome package; optional (left blank if `"missing"`) for the
#'   microbe package.
#' @param host Natural host organism, as a full taxonomic name.
#' @param metagenome_organism For the metagenome package: either a named
#'   character vector mapping "Sample Type" values to NCBI metagenome organism
#'   names, or a single string applied to every sample. Unmapped sample types
#'   get `"missing"`. The default maps axilla and groin swabs to
#'   "human skin metagenome" and perirectal and stool swabs to
#'   "human gut metagenome".
#' @param microbe_organism For the microbe package: organism name applied to
#'   every sample (or a vector with one value per sample). If `NULL`, the
#'   report's "Microbial Species" column is used; samples with no organism get
#'   `"missing"` and a warning.
#' @param microbe_sample_type For the microbe package: value of the mandatory
#'   `sample_type` attribute, e.g. `"cell culture"` or `"mixed culture"`.
#' @param body_site Named character vector mapping "Sample Type" values to the
#'   body site written to `host_tissue_sampled` (microbe package only).
#' @param include_subject_id If `TRUE`, the report's "External Participant ID"
#'   is added as the custom BioSample attribute `host_subject_id`. The internal
#'   "Participant" ID is never exported.
#' @param fastq_dir Optional directory of FASTQ files. If given, samples whose
#'   R1 or R2 file is not found there are dropped with a warning.
#' @param library_strategy SRA library strategy (e.g. `"WGS"`, `"AMPLICON"`).
#' @param library_source SRA library source. If `NULL`, `"METAGENOMIC"` for the
#'   metagenome package and `"GENOMIC"` for the microbe package.
#' @param library_selection SRA library selection method (e.g. `"RANDOM"`,
#'   `"PCR"`).
#' @param platform Sequencing platform (e.g. `"ILLUMINA"`).
#' @param instrument_model Sequencing instrument, using SRA's controlled
#'   vocabulary (e.g. `"Illumina NovaSeq 6000"`, `"Illumina NovaSeq X"`).
#' @param design_description Free-text description of library preparation.
#'   If `NULL`, a description is generated from the package and sample type.
#'
#' @return A list with two data frames: `biosample` (BioSample attributes, in
#'   template column order) and `sra` (SRA metadata, with `filename` and
#'   `filename2` for the R1 and R2 reads). Returned invisibly when
#'   `output_dir` is not `NULL`.
#'
#' @examples
#' \dontrun{
#' prepare_sra_metadata(
#'   "IDSampleByStudy_brendank_Oct-28-2026-06-43-49.xlsx",
#'   package = "metagenome",
#'   geo_loc_name = "USA: Pennsylvania, Philadelphia",
#'   lat_lon = "39.95 N 75.19 W"
#' )
#' }
#'
#' @importFrom readxl read_excel
#' @importFrom writexl write_xlsx
#' @export
prepare_sra_metadata <- function(input_xlsx,
                                 package = c("metagenome", "microbe"),
                                 template_xlsx = NULL,
                                 output_dir = dirname(input_xlsx),
                                 bioproject_accession = "",
                                 geo_loc_name = "missing",
                                 lat_lon = "missing",
                                 host = "Homo sapiens",
                                 metagenome_organism = c(
                                   "Axilla Swab"     = "human skin metagenome",
                                   "Groin Swab"      = "human skin metagenome",
                                   "Perirectal Swab" = "human gut metagenome",
                                   "Stool Swab"      = "human gut metagenome"
                                 ),
                                 microbe_organism = NULL,
                                 microbe_sample_type = "missing",
                                 body_site = c(
                                   "Axilla Swab"     = "axilla",
                                   "Groin Swab"      = "groin",
                                   "Perirectal Swab" = "perirectal region",
                                   "Stool Swab"      = "feces"
                                 ),
                                 include_subject_id = TRUE,
                                 fastq_dir = NULL,
                                 library_strategy = "WGS",
                                 library_source = NULL,
                                 library_selection = "RANDOM",
                                 platform = "ILLUMINA",
                                 instrument_model = "Illumina NovaSeq 6000",
                                 design_description = NULL) {
  package <- match.arg(package)

  # ---- Template columns -------------------------------------------------------
  # The header row is the first row whose first cell is "*sample_name"; the
  # leading "#" rows are instructions. Asterisks mark mandatory fields.
  if (is.null(template_xlsx)) {
    template_name <- switch(package,
                            metagenome = "Metagenome.environmental.1.0.xlsx",
                            microbe    = "Microbe.1.0.xlsx")
    template_xlsx <- file.path(dirname(input_xlsx), template_name)
  }
  template_raw <- readxl::read_excel(template_xlsx, col_names = FALSE,
                                     .name_repair = "minimal")
  hdr_row <- which(template_raw[[1]] %in% c("*sample_name", "sample_name"))[1]
  if (is.na(hdr_row)) {
    stop("Could not find the '*sample_name' header row in ", template_xlsx)
  }
  template_cols <- unlist(template_raw[hdr_row, ], use.names = FALSE)
  template_cols <- template_cols[!is.na(template_cols) & nzchar(template_cols)]

  # ---- Read and validate the sample report ----------------------------------
  report <- readxl::read_excel(input_xlsx)
  required <- c("Sample", "Sample Type", "Collection Date")
  missing_cols <- setdiff(required, names(report))
  if (length(missing_cols)) {
    stop("Input is missing required column(s): ",
         paste(missing_cols, collapse = ", "))
  }
  report <- report[!is.na(report$Sample) & nzchar(report$Sample), ]
  if (anyDuplicated(report$Sample)) {
    dups <- unique(report$Sample[duplicated(report$Sample)])
    stop("Duplicate Sample IDs in input: ", paste(head(dups, 10), collapse = ", "))
  }

  # ---- Paired-end read files: <Sample>_R1.fastq.gz / <Sample>_R2.fastq.gz ---
  report$filename  <- paste0(report$Sample, "_R1.fastq.gz")
  report$filename2 <- paste0(report$Sample, "_R2.fastq.gz")

  if (!is.null(fastq_dir)) {
    has_r1 <- file.exists(file.path(fastq_dir, report$filename))
    has_r2 <- file.exists(file.path(fastq_dir, report$filename2))
    incomplete <- !(has_r1 & has_r2)
    if (any(incomplete)) {
      warning(sum(incomplete), " sample(s) lack an R1 and/or R2 file in ",
              fastq_dir, " and were dropped: ",
              paste(head(report$Sample[incomplete], 10), collapse = ", "),
              if (sum(incomplete) > 10) ", ..." else "", call. = FALSE)
    }
    report <- report[!incomplete, ]
  }

  n <- nrow(report)
  sample_type <- report$`Sample Type`

  # ---- Collection date -> ISO 8601 (YYYY-MM-DD) ------------------------------
  # The report stores Excel serial numbers; also handle dates and text.
  raw_date <- report$`Collection Date`
  if (inherits(raw_date, c("POSIXct", "Date"))) {
    collection_date <- as.Date(raw_date)
  } else {
    num_date <- suppressWarnings(as.numeric(raw_date))
    collection_date <- as.Date(num_date, origin = "1899-12-30")
    text_date <- is.na(num_date) & !is.na(raw_date)
    collection_date[text_date] <- as.Date(raw_date[text_date], optional = TRUE)
  }
  collection_date <- format(collection_date, "%Y-%m-%d")
  collection_date[is.na(collection_date)] <- "missing"

  subject_id <- if ("External Participant ID" %in% names(report)) {
    report$`External Participant ID`
  } else {
    rep(NA_character_, n)
  }
  title <- paste0(ifelse(is.na(subject_id), "", paste0(subject_id, " ")),
                  sample_type, " ", collection_date)

  # Look up sample types in a named vector, with a fallback for unmapped ones.
  lookup <- function(map, default) {
    out <- unname(map[sample_type])
    out[is.na(out)] <- default
    out
  }

  # ---- Package-specific attribute values -------------------------------------
  # Keys are harmonized attribute names (without the template's "*" marker).
  if (package == "metagenome") {
    organism <- if (length(metagenome_organism) == 1 && is.null(names(metagenome_organism))) {
      rep(metagenome_organism, n)
    } else {
      lookup(metagenome_organism, "missing")
    }
    values <- list(
      sample_name          = report$Sample,
      sample_title         = title,
      bioproject_accession = bioproject_accession,
      organism             = organism,
      host                 = host,
      isolation_source     = sample_type,
      collection_date      = collection_date,
      geo_loc_name         = geo_loc_name,
      lat_lon              = lat_lon,
      samp_collect_device  = "swab",
      source_material_id   = report$Sample
    )
    if (is.null(library_source)) library_source <- "METAGENOMIC"
  } else {
    organism <- if (!is.null(microbe_organism)) {
      rep(microbe_organism, length.out = n)
    } else if ("Microbial Species" %in% names(report)) {
      as.character(report$`Microbial Species`)
    } else {
      rep(NA_character_, n)
    }
    no_organism <- is.na(organism) | !nzchar(organism)
    if (any(no_organism)) {
      warning(sum(no_organism), " sample(s) have no organism (the 'Microbial ",
              "Species' column is empty). Supply `microbe_organism`; NCBI ",
              "requires a valid taxonomic name.", call. = FALSE)
      organism[no_organism] <- "missing"
    }
    values <- list(
      sample_name          = report$Sample,
      sample_title         = title,
      bioproject_accession = bioproject_accession,
      organism             = organism,
      isolate              = report$Sample,
      host                 = host,
      isolation_source     = sample_type,
      collection_date      = collection_date,
      geo_loc_name         = geo_loc_name,
      sample_type          = microbe_sample_type,
      host_tissue_sampled  = lookup(body_site, ""),
      lat_lon              = if (identical(lat_lon, "missing")) "" else lat_lon
    )
    if (is.null(library_source)) library_source <- "GENOMIC"
  }

  # ---- Assemble BioSample table in template column order ---------------------
  biosample <- as.data.frame(
    lapply(template_cols, function(col) {
      v <- values[[sub("^\\*", "", col)]]
      if (is.null(v)) v <- ""
      v <- rep_len(as.character(v), n)
      v[is.na(v)] <- ""
      v
    }),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  names(biosample) <- template_cols

  # Custom attribute (NCBI allows extra columns after the template ones).
  if (include_subject_id && !all(is.na(subject_id))) {
    biosample$host_subject_id <- ifelse(is.na(subject_id), "", subject_id)
  }

  # NCBI rejects BioSamples whose attributes (other than name/title/
  # description) are identical; flag any so they can be distinguished.
  attr_cols <- setdiff(names(biosample),
                       c("*sample_name", "sample_title", "description"))
  dup_attrs <- duplicated(biosample[attr_cols]) |
    duplicated(biosample[attr_cols], fromLast = TRUE)
  if (any(dup_attrs)) {
    warning(sum(dup_attrs), " BioSamples share identical attributes and ",
            "will be rejected by NCBI; add a distinguishing attribute.",
            call. = FALSE)
  }

  # ---- SRA metadata table (one row per sample, R1 + R2 files) ---------------
  seq_label <- if (package == "metagenome") "shotgun metagenomic" else "whole-genome"
  if (is.null(design_description)) {
    design_description <- paste("Paired-end", seq_label,
                                 "sequencing of DNA extracted from",
                                 tolower(sample_type))
  }
  sra <- data.frame(
    sample_name        = report$Sample,
    library_ID         = report$Sample,
    title              = paste0(toupper(substr(seq_label, 1, 1)),
                                substring(seq_label, 2), " sequencing of ",
                                tolower(sample_type), " (", report$Sample, ")"),
    library_strategy   = library_strategy,
    library_source     = library_source,
    library_selection  = library_selection,
    library_layout     = "paired",
    platform           = platform,
    instrument_model   = instrument_model,
    design_description = rep_len(design_description, n),
    filetype           = "fastq",
    filename           = report$filename,
    filename2          = report$filename2,
    stringsAsFactors   = FALSE
  )

  result <- list(biosample = biosample, sra = sra)

  # ---- Write outputs ---------------------------------------------------------
  if (!is.null(output_dir)) {
    dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
    stem <- file.path(output_dir, sub("\\.xlsx$", "", basename(template_xlsx)))
    bs_tsv  <- paste0(stem, "_biosample_attributes.tsv")
    sra_tsv <- paste0(stem, "_sra_metadata.tsv")
    xlsx    <- paste0(stem, "_submission.xlsx")
    utils::write.table(biosample, bs_tsv, sep = "\t", quote = FALSE,
                       row.names = FALSE, na = "")
    utils::write.table(sra, sra_tsv, sep = "\t", quote = FALSE,
                       row.names = FALSE, na = "")
    writexl::write_xlsx(list(BioSample = biosample, SRA_data = sra), xlsx)
    message("Wrote ", n, " samples (", 2 * n, " FASTQ files) for package '",
            package, "':\n  ", bs_tsv, "\n  ", sra_tsv, "\n  ", xlsx)
    return(invisible(result))
  }
  result
}

