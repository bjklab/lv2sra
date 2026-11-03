lv2sra
================

## Package Design

The *lv2sra* package is designed to generate `Microbe` (v1.0) and
`Metagenome or environmental` (v1.0) BioSample submission descriptions
to accompany sequence data submission to the NCBI SRA.

It includes:\
+ functions to read common LIMS system reports + functions to output
BioSample metadata tables, based on a directory containing sequence
files and the LIMS system report matching the sequence filenames

The *lv2sra* package has been used to support multiple submissions to
the NCBI SRA.

## Example Workflow

``` r
#' load libraries

library(lv2sra)
library(readr)
library(readxl)
library(writexl)
library(dplyr)


#' generates error:
prepare_sra_metadata(input_xlsx = "data/IDSampleByStudy_brendank_Nov-02-2026-04-04-43.xlsx", package = "metagenome", output_dir = "tabs/gol_run1", bioproject_accession = "", geo_loc_name = "USA: Philadelphia, PA", lat_lon = "39.95 N 75.19 W", fastq_dir = "/mnt/d/QUO1022280/Illumina DNA Reads/", library_strategy = "WGS", library_selection = "RANDOM", platform = "ILLUMINA", instrument_model = "Illumina NovaSeq 6000")


#' make sure underscores and hyphens align (may be exchanged, for example per filename requirements of sequencing core) 


#' align sample names
read_xlsx("data/IDSampleByStudy_brendank_Nov-02-2026-04-04-43.xlsx") |>
  mutate(Sample = gsub("-","_", Sample)) |> 
  write_xlsx(path = "data/underscore_IDSampleByStudy_brendank_Nov-02-2026-04-04-43.xlsx")


#' no error:
#' run 1
prepare_sra_metadata(input_xlsx = "data/underscore_IDSampleByStudy_brendank_Nov-02-2026-04-04-43.xlsx", package = "metagenome", output_dir = "tabs/gol_run1", bioproject_accession = "", geo_loc_name = "USA: Philadelphia, PA", lat_lon = "39.95 N 75.19 W", fastq_dir = "/mnt/d/QUO1022280/Illumina DNA Reads/", library_strategy = "WGS", library_selection = "RANDOM", platform = "ILLUMINA", instrument_model = "Illumina NovaSeq 6000")

#' run 2
prepare_sra_metadata(input_xlsx = "data/underscore_IDSampleByStudy_brendank_Nov-02-2026-04-04-43.xlsx", package = "metagenome", output_dir = "tabs/gol_run2", bioproject_accession = "", geo_loc_name = "USA: Philadelphia, PA", lat_lon = "39.95 N 75.19 W", fastq_dir = "/mnt/d/QUO1025236/Illumina DNA Reads/", library_strategy = "WGS", library_selection = "RANDOM", platform = "ILLUMINA", instrument_model = "Illumina NovaSeq 6000")


#' combine output files for SRA submission
bind_rows(read_xlsx("tabs/gol_run1/Metagenome.environmental.1.0_submission.xlsx"), read_xlsx("tabs/gol_run2/Metagenome.environmental.1.0_submission.xlsx")) |> 
  write_xlsx(path = "tabs/combined_gol_sra_submission.xlsx")

bind_rows(read_tsv("tabs/gol_run1/Metagenome.environmental.1.0_sra_metadata.tsv"), read_tsv("tabs/gol_run2/Metagenome.environmental.1.0_sra_metadata.tsv")) |> 
  write_tsv(file = "tabs/combined_gol_sra_metadata.tsv")
```
