#################################################
# UK GEOGRAPHY * 16- BUILD POLICE NEIGHBOURHOOD #
#################################################

# load packages ---------------------------------
message('Loading packages...')
pkg <- c('dmpkg.funs', 'data.table', 'fst', 'jsonlite', 'maptools', 'rgdal', 'rvest')
invisible(lapply(pkg, require,  char = TRUE))

# set constants ---------------------------------
data_path <- file.path(ext_path, 'uk')
pfo_path <- file.path(data_path, 'police_neighbourhood')
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
forces <- fread(file.path(data_path, 'geography', 'locations', 'PFA.csv'))
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
fwrite(neighs[order(PFN)], file.path(data_path, 'geography', 'locations', 'PFN.csv'))

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

# map postcodes and PFN boundaries --------------
message('Mapping postcodes and neighbourhoods...')
message(' - loading postcodes...')
pc <- read_fst(file.path(geouk_path, 'postcodes'), as.data.table = TRUE)
pc[, PCN := NULL]
yn <- names(pc)
message(' - filtering out Scotland...')
pcn <- pc[CTRY != 'SCO', .(PCU, x_lon, y_lat)]
message(' - converting into spatial points...')
coordinates(pcn) <- ~x_lon+y_lat
proj4string(pcn) <- crs.wgs
message(' - performing Points in Polygon...')
y <- over(pcn, nbnd)
message(' - merging into postcodes...')
pc <- setDT(cbind(pcn@data, y))[pc, on = 'PCU']
setnames(pc, 'id', 'PFN')
setcolorder(pc, c(yn[1:(which(yn == 'PFA') - 1)], 'PFN', yn[which(yn == 'PFA'):length(yn)]))

# check voids using a map overlaying MSOA
# bnd <- sp::merge(nbnd, neighs, by.x = 'id', by.y = 'PFN')
# mp <- basemap(bnd = bnd, bndid = 'PFNn') 
# lsoa <- readRDS(file.path(bnduk_spath, 'LSOA'))
# lsoa <- subset(lsoa, substr(lsoa$id, 1, 1) != 'S')
# mp <- mp %>% leaflet::addPolygons(data = lsoa, fillOpacity = 0, color = 'black', label = ~id)
# pcna <- pc[CTRY != 'SCO' & is.na(PFN), .(PCU, x_lon, y_lat, LSOA, MSOA)]
# mp <- mp %>% leaflet::addCircles(data = pcna, lng = ~x_lon, lat = ~y_lat, fillOpacity = 1, color = 'black', label = ~paste(LSOA, MSOA))

# FIX NOVEMBER 2020 
pc[MSOA %in% c('E02003645', 'E02003646', 'E02003647', 'E02003648', 'E02003649', 'E02003651'), PFN := 'E23000026_007'] # Dunstable Town
pc[LSOA %in% c('E01017586', 'E01017587'), PFN := 'E23000026_007'] # Dunstable Rural
pc[LSOA %in% c('W01000614', 'W01000622'), PFN := 'W15000004_014']

# HEATHROW NON TERMINALS
pc[is.na(PFN) & LSOA %in% c('E01002443', 'E01002444'), PFN := 'E23000001_659']

message('Adding PFN to missing postcode using similar LSOA...')
y <- unique(pc[!is.na(PFN) & LSOA %in% unique(pc[CTRY != 'SCO' & is.na(PFN), LSOA]), .N, .(LSOA, PFN)])[order(LSOA, -N)]
yd <- y[LSOA %in% y[, .N, LSOA][N > 1, LSOA]]
y <- rbindlist(list( y[LSOA %in% y[, .N, LSOA][N == 1, LSOA], .(LSOA, PFN)] , yd[yd[, .I[which.max(N)], .(LSOA)]$V1, .(LSOA, PFN)] ))
pc <- dt_update(pc, y)

# message('Determine minimum centroids distance for missing mappings...')
# message(' - filtering out Scotland...')
# pcn <- pc[CTRY != 'SCO' & is.na(PFN), ]
# message(' - calculating centroids...')
# gc <- rgeos::gCentroid(nbnd, byid = TRUE)
# message(' - calculating distances...')
# dst = raster::pointDistance(pcn[, .(x_lon, y_lat)], gc, lonlat = TRUE)
# rownames(dst) <- pcn$PCU
# colnames(dst) <- nbnd$id
# message(' - querying minimum distance...')
# dst <- setDT(melt(dst, ))
# dst <- dst[dst[ , .I[which.min(value)], Var1]$V1][, value := NULL]
# setnames(dst, c('PCU', 'PFN'))
# message(' - updating postcodes...')
# pc[CTRY != 'SCO' & is.na(PFN), PFN := dst[.SD[['PCU']], .(PFN), on = 'PCU'] ]

message('Adding Scottish PFN/PFA as mapping from LADs/WARDs...')
y <- fread(file.path(data_path, 'geography', 'lookups', 'SCO_LAD_PFA.csv'))
pc <- dt_update(pc, y, TRUE)
y <- unique(pc[CTRY == 'SCO', .(WARD, PFA)])[order(PFA, WARD)]
y[, PFN := paste0(PFA, '_', stringr::str_pad(1:.N, 3, 'left', '0')), PFA][, PFA := NULL]
fwrite(y, file.path(data_path, 'geography', 'lookups', 'SCO_WARD_PFN.csv'))
pc <- dt_update(pc, y, TRUE)

# save postcodes dataset ------------------------
message('Saving postcodes with various indices...')
save_postcodes(pc, TRUE)

# clean and Exit --------------------------------
message('Clean and Exit...')
system(paste('rm -R', pfo_path))
rm(list = ls())
gc()
