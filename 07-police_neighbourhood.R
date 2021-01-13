#################################################
# UK GEOGRAPHY * 16- BUILD POLICE NEIGHBOURHOOD #
#################################################

# load packages ---------------------------------
message('Loading packages...')
pkg <- c('dmpkg.funs', 'data.table', 'fst', 'jsonlite', 'maptools', 'rgdal', 'rvest')
invisible(lapply(pkg, require,  char = TRUE))

# set constants ---------------------------------
out_path <- file.path(ext_path, 'uk', 'geography')
pfo_path <- file.path(ext_path, 'uk', 'police_neighbourhood')
zfile <- file.path(pfo_path, 'KML.zip')
if(dir.exists(pfo_path)) system(paste('rm -r', pfo_path))
dir.create(pfo_path)

# define functions ------------------------------
convert_KML <- function(fn){
    y <- readOGR(fn$fname) 
    y <- y[, 1]
    colnames(y@data) <- c('id')
    y$id <- fn$PFN # neighs[PFA == fn$PFA & id == fn$id, PFN]
    y <- spChFIDs(y, as.character(y$id))
    y
}

# load forces PFA data --------------------------
message('Loading data...')
forces <- fread(file.path(out_path, 'locations', 'PFA.csv'))
forces <- forces[substr(PFA, 1, 1) != 'S']

# load neighborhood data ------------------------
neighs <- rbindlist(
    lapply(1:nrow(forces), function(idx){
        message('Adding neighs from: ', forces[idx, name] )
        y <- fromJSON(paste0('https://data.police.uk/api/', forces[idx, id], '/neighbourhoods'))
        data.table(forces[idx, PFA], y)
    })
)
setnames(neighs, c('PFA', 'id', 'PFNn'))
setorderv(neighs, c('PFA', 'id'))

# delete duplicates: one of each of "Gravesham - Pelham" and "Gravesham - Central"                 <================= CHECK BEFORE RUN 
neighs <- neighs[!(PFA == 'E23000032' & id %in% c(179, 187))]

# delete parent areas                                                                              <================= CHECK BEFORE RUN 
sups <- c(
    'Merthyr-Tydfil', 'Neath-Port-Talbot', 'Rhondda-Cynon-Taf', 'Vale-of-Glamorgan', 
    'swpbridgend', 'swpcardiff', 'swpswansea'
) 
neighs <- neighs[!(PFA == 'W15000003' & id %chin% sups)]

# create id and save
neighs[, PFN := paste0(PFA, '_', stringr::str_pad(1:.N, 3, 'left', '0')), PFA]
setcolorder(neighs, c('PFN', 'id', 'PFNn', 'PFA'))
neighs <- rbindlist(list( neighs, data.table( 'E23000001_659', 'SATST9', 'Heathrow NON Terminals', 'E23000001') ))
fwrite(neighs[order(PFN)], file.path(out_path, 'locations', 'PFN.csv'))

# load neighborhood PFN boundaries --------------
message('Loading last neighbourhoods boundaries zip file...')
wp <- read_html('https://data.police.uk/data/boundaries/') %>% 
        html_nodes('.neighbourhood_kmls a') %>% 
        html_attr('href') 
download.file(paste0('https://data.police.uk', wp[1]), zfile)

message('Extracting KML files...')
unzip(zfile, exdir = pfo_path)

message('Fixing file names and location codes...')
# retrieve filenames of all unzipped files, and extract force and neigh
fnames <- data.table(fname = dir(pfo_path, full.names = TRUE, recursive = TRUE))
fnames[, `:=`( force = sub(".*/(.*)/.*", "\\1", fname), id = sub(".*/(.*)\\.kml", "\\1", fname) )]
fnames <- forces[, .(PFA, PFAid = id)][fnames, on = c(PFAid = 'force')][!is.na(PFA)]
fnames <- fnames[neighs[, .(PFA, id, PFN)], on = c('PFA', 'id')][order(PFA, PFN)]
fnames <- fnames[!is.na(PFAid)]

message('Converting KML files into one single sp Polygon ...')
nbnd <- convert_KML(fnames[1])
for(idx in 2:nrow(fnames)){
    message('Adding polygon ', idx, ' out of ', nrow(fnames))
    y <- convert_KML(fnames[idx])
    nbnd <- spRbind(nbnd, y)
}
message('Changing coordinates system...')
nbnd <- spTransform(nbnd, crs.wgs)

message('Fixing holes...')
# basemap(bnd = nbnd)     <================= CHECK BEFORE FIXING HOLES
# holes <- data.table(
#     'outer' = c(
#         'E23000021_036', 'E23000001_142', 'E23000022_007', 'E23000022_011', 
#         'E23000004_005', 'E23000030_077', 'E23000028_029', 'E23000032_073'
#     ),
#     'hole'  = c(
#         'E23000032_041', 'E23000001_654', 'E23000022_006', 'E23000022_010', 
#         'E23000004_006', 'E23000030_076', 'E23000028_028', 'E23000032_259'
#     )
# )
# fix_holes(nbnd, holes)

message('Saving boundaries as shapefile...')
save_bnd(nbnd, 'PFN', rds = FALSE, bpath = file.path(ext_path, 'uk', 'geography', 'boundaries'), pct = NULL)

# clean and Exit --------------------------------
message('Clean and Exit...')
system(paste('rm -R', pfo_path))
rm(list = ls())
gc()
