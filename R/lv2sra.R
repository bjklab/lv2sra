#' @title Read sequence filelist from target upload folder and attach metadata from LIMS report (Excel-format) file
#' @description Recreates a `tibble` containing the target sequence files and associated metadata.
#' @details The output `tibble` contains read filenames and the metadata that will be required for NCBI SRA submission.
#' @import tibble
#' @import dplyr
#' @import readxl
#' @param seq_dir_folderpath string indicating the path to the folder containing sequence files for SRA upload
#' @param seq_metadata_filepath string indicating the path to the file (Excel-format) containing the LIMS reprot data
#' @return `tibble` containing filenames and metadata
#' @seealso \code{\link{write_biosample_metadata}}
#' @export
#' @examples
#' NULL
#' 
read_seqs_metadata <- function(seq_dir_folderpath, seq_metadata_filepath) {
  tibble::tibble(filenames = list.files(path = seq_dir_folderpath, full.names = FALSE), pathnames = list.files(path = seq_dir_folderpath, full.names = TRUE)) |> 
    dplyr::mutate(read_name = gsub(pattern = "\\.fastq.gz", replacement = "", x = filenames)) |> 
    dplyr::mutate(specimen_name = gsub("_R1|_R2", "", read_name)) |> 
    identity() -> seq_dat
  readxl::read_xls(path = seq_metadata_filepath) |> 
    identity() -> meta_dat
  left_join(seq_dat, meta_dat, by = "specimen_name") |> 
    identity() -> dat
  return(dat)
}

