#####################################################
# UK GEOGRAPHY * 81 - Calculate Distances Postcodes #
#####################################################

message('Loading libraries...')
pkg <- c('popiFun', 'data.table', 'fst', 'geosphere', 'rgeos')
invisible(lapply(pkg, require, char = TRUE))
out_path <- file.path(geouk_path, 'distances', 'postcodes')

message('\n Loading data...')
pc <- read_fst(file.path(geouk_path, 'postcodes'), columns = c('postcode', 'PCA', 'x_lon', 'y_lat'), as.data.table = TRUE)
ngh <- read_fst(file.path(geouk_path, 'neighbours', 'PCA'), as.data.table = TRUE)

dt.haversine <- function(lat_from, lon_from, lat_to, lon_to, r = 6378137){
    radians <- pi/180
    lat_to <- lat_to * radians
    lat_from <- lat_from * radians
    lon_to <- lon_to * radians
    lon_from <- lon_from * radians
    dLat <- (lat_to - lat_from)
    dLon <- (lon_to - lon_from)
    a <- (sin(dLat/2)^2) + (cos(lat_from) * cos(lat_to)) * (sin(dLon/2)^2)
    return(2 * atan2(sqrt(a), sqrt(1 - a)) * r)
}
for(pca in levels(pc$PCA)){
    dist <- data.table(pcA = character(), pcB = character(), distance = numeric(), knn = integer())
    message('Processing Postcode Area ', pca)
    y0 <- pc[PCA == pca]
    ya <- pc[PCA %in% c(pca, ngh[location_id == pca, neighbour_id]), -c('PCA')][order(postcode)]
    for(idx in 1:nrow(y0)){
        message(' * Processing postcode ', idx, ' (', round(100 * idx / nrow(y0), 2), '%)')
        y <- data.table( 
                pcA = y0[idx, postcode],
                pcB = ya[, postcode], 
                distance = distVincentyEllipsoid(y0[idx, .(x_lon, y_lat)], ya[, .(x_lon, y_lat)]) 
        )
        y <- y[order(distance)][, knn := 1:.N]
        message('   Adding to main dataset...')
        dist <- rbindlist(list( dist, y ), use.names = TRUE)
    }
    dist <- dist[pcA != pcB][, knn := knn - 1]
    message('\n Saving file with index...')
    setorderv(dist, c('pcA', 'distance'))
    write_fst_idx('pca', c('pcA'), dist, out_path, 'pca')
    # setorderv(dist, c('pcA', 'distance'))
    # y <- dist[, .N, pcA]
    # y[, n2 := cumsum(N)][, n1 := shift(n2, 1L, type = 'lag') + 1][is.na(n1), n1 := 1]
    # setcolorder(y, c('pcA', 'N', 'n1', 'n2'))
    # write_fst(y, file.path(out_path, paste0(pca, '.idx')))
    # write_fst(dist, file.path(out_path, pca))
    message('\n================================\n')
}

message('Creating unique file for distances below 10 km...')
dist <- NULL
for(pca in levels(pc$PCA)){
    message('Processing Postcode Area ', pca)
    y <- read_fst(file.path(out_path, pca), as.data.table = TRUE)
    message('Subsetting to 10 km then adding to main dataset...')
    y <- y[distance < 10000]
    dist <- rbindlist(list( dist, y ), use.names = TRUE)
}
message('\n Saving file...')
write_fst(dist, file.path(out_path, 'dp10km'))

message('\n Done! Clearing Environment...')
rm(list = ls())
gc()
