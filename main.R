library(tercen)
library(dplyr)
library(processx)
# library(progressr)
# library("future.apply")

## Get input from context
ctx <- tercenCtx()

folder <- ctx$cselect()[[1]][[1]]
parts <- unlist(strsplit(folder, '/'))
volume <- parts[[1]]
input_folder <- paste(parts[-1], collapse = "/")
# input_folder <- "test"
# volume <- "read"

## Define IO paths
input_path <- paste0("/var/lib/tercen/share/", volume, "/",  input_folder)

if(!dir.exists(input_path)) {
  stop(paste("ERROR:", input_folder, "folder does not exist in project volume", volume))
}
if(length(dir(input_path)) == 0) {
  stop(paste("ERROR:", input_folder, "folder is empty  in project volume", volume))
}

output_volume = "write"
output_folder <- paste0(
  output_volume, "/",
  # format(Sys.time(), "%Y_%m_%d_%H_%M_%S_),
  "blast_output"
)
output_path <- paste0("/var/lib/tercen/share/", output_folder, "/")
system(paste("mkdir -p", output_path))

## Define pipeline inputs
query = paste0(input_path, "/*.fa")
db = paste0(input_path, "/blast-db/pdbaa")
out = paste0(output_path, "result.txt")
chunkSize = 100

## Run nextflow
p <- processx::process$new(
  "./nextflow",
  c(
    "./pipeline.nf",
    "--query", query,
    "--db", db,
    "--out", out,
    "--chunkSize", 10
  ),
  echo = TRUE, stdout = "|", stderr = "|"
)

## Capture output and send back to tercen
while(p$is_alive()) {
  p$poll_io(1000) # 1s timeout
  outln <- p$read_output_lines()
  # outerr <- p$read_error_lines()
  if(length(outln) > 0) print(outln)
  # if(length(outerr) > 0) print(outerr)
}

## Return output
tibble(.ci = 0,
       blast_results_folder = output_folder) %>%
  ctx$addNamespace() %>%
  ctx$save()
