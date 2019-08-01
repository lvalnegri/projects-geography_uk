##########################################################
# UK GEOGRAPHY * 71 - Calculate Neighbours for Postcodes #
##########################################################

# load packages
pkg <- c('data.table', 'fst', 'RMySQL', 'spdep')
invisible(lapply(pkg, require, character.only = TRUE))

# set constants
pub_path <- Sys.getenv('PUB_PATH')
data_path <- file.path(pub_path, 'datasets', 'uk')
neigh_path <- file.path(data_path, 'geography', 'neighbours')

message('Loading data...')
pc <- read.fst(
        file.path(data_path, 'geography', 'postcodes'), 
        columns = c('postcode', 'x_lon', 'y_lat', 'is_active'), 
        as.data.table = TRUE
)
pc <- pc[is_active == 1][, is_active := NULL]
pcd <- pc[duplicated(pc[, .(x_lon, y_lat)])]
pc <- pc[!postcode %in% pcd$postcode]
pcd <- pc[pcd, on = c('x_lon', 'y_lat')][, `:=`(x_lon = NULL, y_lat = NULL)]
setnames(pcd, 'i.postcode', 'pcd')

message('Calculating neighbors...')
neighs <- tri2nb(as.matrix(pc[, .(x_lon, y_lat)]), row.names = pc$postcode)

message('Extracting the list')
rgn.lst <- as.character(attr(neighs, 'region.id'))
y <- rbindlist(lapply(
    1:length(neighs),
    function(x)
        if(length(rgn.lst[neighs[[x]]]) > 0)
            data.table( rgn.lst[x], rgn.lst[neighs[[x]]] )
))
setnames(y, c('location_id', 'neighbour_id'))

message('Adding deleted duplications...')
pcd <- pc[pcd, on = c('x_lon', 'y_lat')]

y[, location_type := 'PC']

message('Ordering the dataset by postcode...')
setorderv(y, c('location_id', 'neighbour_id'))

message('Saving into database...')
dbc <- dbConnect(MySQL(), group = 'geouk')
dbSendQuery(dbc, paste0("DELETE FROM neighbours WHERE location_type = 'PC'"))
dbWriteTable(dbc, 'neighbours', y, row.names = FALSE, append = TRUE)
dbDisconnect(dbc)

message('Saving as fst with index...')
y[, location_type := NULL]
yx <- y[, .N, location_id]
yx[, n2 := cumsum(N)][, n1 := shift(n2, 1L, type = 'lag') + 1][is.na(n1), n1 := 1]
setcolorder(yx, c('location_id', 'N', 'n1', 'n2'))
write.fst(yx, file.path(neigh_path, 'PC.idx'))
write_fst(y, file.path(neigh_path, 'PC'))

message('Finished! Cleaning and Exit')
rm(list = ls())
gc()
