#################################################
# UK GEOGRAPHY * 16- BUILD POLICE NEIGHBOURHOOD #
#################################################

messages('Loading packages...')
pkg <- c('popiFun', 'data.table', 'fst', 'jsonlite', 'maptools', 'rgdal')
invisible(lapply(pkg, require,  char = TRUE))

data_path <- file.path(ext_path, 'uk')
pfo_path <- file.path(data_path, 'police_neighbourhood')
zfile <- file.path(pfo_path, 'KML.zip')

convert_KML <- function(fn){
    y <- readOGR(fn$fname) 
    y <- y[, 1]
    colnames(y@data) <- c('id')
    y$id <- neighs[PFA == fn$PFA & id == fn$id, PFN]
    y <- spChFIDs(y, as.character(y$id))
    y
}

messages('Loading data...')
forces <- fread(file.path(data_path, 'geography', 'locations', 'PFA.csv'))
forces <- forces[substr(PFA, 1, 1) != 'S']
neighs <- data.table()
for(idx in 1:nrow(forces)){
    message('Adding neighs from: ', forces[idx, name] )
    y <- fromJSON(paste0('https://data.police.uk/api/', forces[idx, id], '/neighbourhoods'))
    neighs <- rbindlist(list( neighs, data.table(forces[idx, PFA], y) ))
}
setnames(neighs, c('PFA', 'id', 'PFNn'))
setorderv(neighs, c('PFA', 'id'))
neighs[, PFN := paste0(PFA, '_', stringr::str_pad(1:.N, 3, 'left', '0')), PFA]
fwrite(neighs, file.path(data_path, 'geography', 'locations', 'PFN.csv'))

messages('Loading last neighbourhoods boundaries zip file...')
download.file('https://data.police.uk/data/boundaries/2020-07.zip', zfile)

messages('Extracting KML files...')
unzip(zfile, exdir = pfo_path)

messages('Fixing file names and location codes...')
# retrieve filenames of all unzipped files, and extract force and neigh
fnames <- data.table(fname = dir(pfo_path, full.names = TRUE, recursive = TRUE))
fnames[, `:=`( force = sub(".*/(.*)/.*", "\\1", fname), id = sub(".*/(.*)\\.kml", "\\1", fname) )]
fnames <- forces[, .(PFA, PFAid = id)][fnames, on = c(PFAid = 'force')]

messages('Converting KML files into one single sp Polygon ...')
neigh <- convert_KML(fnames[1])
for(idx in 2:nrow(fnames)){
    message('Adding polygon ', idx, ' out of ', nrow(fnames))
    y <- convert_KML(fnames[idx])
    neigh <- spRbind(neigh, y)
}
neigh <- spTransform(neigh, crs.wgs)

messages('Saving boundaries as shapefile...')
bnd_path <- file.path(bnduk_path)
if(file.exists(file.path(bnd_path, 'shp', 's00', 'PFN.shp'))) 
    file.remove(paste0(file.path(bnd_path, 'shp', 's00', 'PFN.'), c('shp', 'prj', 'dbf', 'shx')))
writeOGR(neigh, file.path(bnd_path, 'shp', 's00'), layer = 'PFN', driver = 'ESRI Shapefile') 

messages('Saving boundaries as RDS...')
saveRDS(neigh, file.path(bnd_path, 'rds', 's00', 'PFN'))

message('Mapping postcodes and neighbourhoods...')
message(' - loading postcodes...')
pc <- read_fst(file.path(geouk_path, 'postcodes'), as.data.table = TRUE)
yn <- names(pc)
message(' - filtering out Scotland...')
pcn <- pc[CTRY != 'SCO', .(postcode, x_lon, y_lat)]
message(' - converting into spatial points...')
coordinates(pcn) <- ~x_lon+y_lat
proj4string(pcn) <- crs.wgs
message(' - performing Points in Polygon...')
y <- over(pcn, neigh)
message(' - merging into postcodes...')
pc <- setDT(cbind(pcn@data, y))[pc, on = 'postcode']
setnames(pc, 'id', 'PFN')
setcolorder(pc, c(yn[1:(which(yn == 'PFA') - 1)], 'PFN', yn[which(yn == 'PFA'):length(cols)]))

message('Determine minimum centroids distance for missing mappings...')
message(' - filtering out Scotland...')
pcn <- pc[CTRY != 'SCO' & is.na(PFN), ]
message(' - calculating centroids...')
gc <- rgeos::gCentroid(neigh, byid = TRUE)
message(' - calculating distances...')
dst = raster::pointDistance(pcn[, .(x_lon, y_lat)], gc, lonlat = TRUE)
rownames(dst) <- pcn$postcode
colnames(dst) <- neigh$id
message(' - querying minimum distance...')
dst <- setDT(melt(dst, ))
dst <- dst[dst[ , .I[which.min(value)], Var1]$V1][, value := NULL]
setnames(dst, c('postcode', 'PFN'))
message(' - updating postcodes...')
pc[CTRY != 'SCO' & is.na(PFN), PFN := dst[.SD[['postcode']], .(PFN), on = 'postcode'] ]

message('Adding Scottish PFN as mapping from WARDs...')
y <- fread(file.path(data_path, 'geography', 'lookups', 'SCO_LAD_PFA.csv'))
pc[, `:=`( LAD = as.character(LAD), PFN = as.character(PFN), PFA = as.character(PFA) )]
pc[CTRY == 'SCO' , PFA := y[.SD[['LAD']], .(PFA), on = 'LAD'] ]
y <- fread(file.path(data_path, 'geography', 'lookups', 'SCO_PFN_LAD.csv'))
pc[CTRY == 'SCO' , PFN := y[.SD[['LAD']], .(PFN), on = 'PFN'] ]
pc[, `:=`( LAD = factor(LAD), PFN = factor(PFN), PFA = factor(PFA) )]

message('Saving postcodes with various indices...')
fnames <- list(
    'postcodes' = c('is_active', 'LSOA'),
    'postcodes_msls' = c('MSOA', 'LSOA'),
    'postcodes_pcoa' = c('PCON', 'OA'),    # CHECK!!!
    'postcodes_ldwd' = c('LAD', 'WARD'),
    'postcodes_ldpr' = c('LAD', 'PAR'),
    'postcodes_pfan' = c('PFA', 'PFN'),    # CHECK!!!
    'postcodes_pcds' = c('PCD', 'PCS'),
    'postcodes_pcat' = c('PCA', 'PCT')
)
for(idx in 1:length(fnames)){
    message(' - saving with index over <', fnames[[idx]][1], '> and <', fnames[[idx]][2], '>...')
    write_fst_idx(names(fnames[idx]), fnames[[idx]], pc, geouk_path)
}

message('Cleaning and Exit...')
system(paste0('rm -R ', pfo_path))
rm(list = ls())
gc()

# library(leaflet)
# leaflet() %>% addTiles() %>% addPolygons(data = neigh, color = 'blue', fillColor = 'orange', weight = 3, label = ~id)