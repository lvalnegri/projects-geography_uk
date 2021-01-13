##############################################
# UK GEOGRAPHY * 50 - Maps for UK, CTRY, RGN #
##############################################

library(dmpkg.funs)

# start with Countries
ctry <- dunzip('https://opendata.arcgis.com/datasets/92ebeaf3caa8458ea467ec164baeefa4_0.zip', 'CTRY', file.path(geouk_path, 'shp', 's00'), shp = TRUE, bndid = 'ctry19cd')
ctry <- saveRDS(ctry, file.path(bnduk_path, 'rds', 's00', 'CTRY'))
saveRDS(ctry, file.path(bnduk_path, 'rds', 's00', 'CTRY'))

# dissolve countries to get UK
uk <- rmapshaper::ms_dissolve(ctry)
colnames(uk@data) <- c('id')
saveRDS(uk, file.path(bnduk_path, 'rds', 's00', 'UK'))

# load RGN boundaries, then add to uk without ENG
rgne <- dunzip('https://opendata.arcgis.com/datasets/15f49f9c99ae4a16a6a5134258749b8a_0.zip', shp = TRUE, bndid = 'rgn19cd')
saveRDS(rgne, file.path(bnduk_path, 'rds', 's00', 'RGNE'))
rgn <- subset(ctry, id != 'E92000001')
rgn <- raster::bind(rgne, rgn)
saveRDS(rgn, file.path(bnduk_path, 'rds', 's00', 'RGN'))

# crop Scotland northern islands from the above
coords <- data.frame(
    x_lon = c(-8.20,  -8.20,  1.77, 1.77, -8.20),
    y_lat = c(49.95, 58.70, 58.70, 49.95, 49.95)
)
ni <- SpatialPolygons(list( Polygons(list( Polygon(coords) ), 1) ))
proj4string(ni) = crs.wgs
uk <- raster::crop(uk, ni)
saveRDS(uk, file.path(bnduk_path, 'rds', 's00', 'UKni'))
ctry <- raster::crop(ctry, ni)
saveRDS(ctry, file.path(bnduk_path, 'rds', 's00', 'CTRYni'))
rgn <- raster::crop(rgn, ni)
saveRDS(rgn, file.path(bnduk_path, 'rds', 's00', 'RGNni'))

# simplify and save
