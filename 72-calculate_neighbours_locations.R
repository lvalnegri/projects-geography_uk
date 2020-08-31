##################################################################################
# UK GEOGRAPHY * 72 - Calculate Neighbours for Locations (not for OA, LSOA, WPZ) #
##################################################################################

# load packages
pkg <- c('popiFun', 'data.table', 'fst', 'maptools', 'RMySQL', 'spdep')
invisible(lapply(pkg, require, character.only = TRUE))

# set constants
pub_path <- Sys.getenv('PUB_PATH')
data_path <- file.path(pub_path, 'datasets', 'uk')
neigh_path <- file.path(data_path, 'geography', 'neighbours')
bnd_path <- file.path(pub_path, 'boundaries', 'uk', 'rds', 's10')

# load data
dbc <- dbConnect(MySQL(), group = 'geouk')
types <- dbGetQuery(dbc, "SELECT type, name FROM location_types")
dbDisconnect(dbc)

# # FOQ: FIRST ORDER CONTIGUITY (QUEEN MOVE) 
# # at least one point on the boundary of one polygon is shared with at least one point of its neighbor (you need just a corner)
# nb.FOQ = poly2nb(bnd, queen = TRUE, row.names = bnd$id)
# 
# # FOR: FIRST ORDER CONTIGUITY (ROOK MOVE) 
# # comprises only polygons sharing more than one boundary point ==> does not include corners;
# nb.FOR = poly2nb(bnd, queen = FALSE, row.names = bnd$id, snap = TRUE)

for(geo in types$type){
    message('=============================================================')
    message('Processing ', types[which(types == geo), 'name'], 's')
    message(' + Reading boundaries...')
    bnd <- readRDS(file.path(bnd_path, geo))
    message(' + Calculating neighbors...')
    neighs = poly2nb(bnd, queen = TRUE, row.names = bnd$id)
    message(' + Extracting the list')
    rgn.lst <- as.character(attr(neighs, 'region.id'))
    y <- rbindlist(lapply(
        1:length(neighs),
        function(x)
            if(length(rgn.lst[neighs[[x]]]) > 0)
                data.table( geo, rgn.lst[x], rgn.lst[neighs[[x]]] )
    ))
    setnames(y, c('location_type', 'location_id', 'neighbour_id'))
    message('Ordering the dataset by location id...')
    setorderv(y, c('location_type', 'location_id', 'neighbour_id'))
    message(' + Saving into database...')
    dbc <- dbConnect(MySQL(), group = 'geouk')
    dbSendQuery(dbc, paste0("DELETE FROM neighbours WHERE location_type = '", geo, "'"))
    dbWriteTable(dbc, 'neighbours', y, row.names = FALSE, append = TRUE)
    dbDisconnect(dbc)
    message(' + Saving as fst with index...')
    y[, location_type := NULL]
    yx <- y[, .N, location_id]
    yx[, n2 := cumsum(N)][, n1 := shift(n2, 1L, type = 'lag') + 1][is.na(n1), n1 := 1]
    setcolorder(yx, c('location_id', 'N', 'n1', 'n2'))
    write.fst(yx, file.path(neigh_path, paste0(geo, '.idx')))
    write_fst(y, file.path(neigh_path, geo))
    message(' + DONE!')
    message('=============================================================')
}

# clean and exit 
message('Finished!')
rm(list = ls())
gc()
