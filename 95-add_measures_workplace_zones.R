#################################################################################
# UK GEOGRAPHY * 54 - BOUNDARIES: add centroids and measures to workplace zones #
#################################################################################

# load packages -----------------------------------------------------------------------------------------------------------------
pkg <- c('data.table', 'fst', 'maptools', 'rgdal', 'rgeos', 'RMySQL', 'sp')
invisible(lapply(pkg, require, character.only = TRUE))

# set constants ------------------------------------------------------------------------------------------------
cnt_path <- file.path(Sys.getenv('PUB_PATH'), 'ext_data', 'uk', 'geography', 'centroids')
bnd_path <- file.path(Sys.getenv('PUB_PATH'), 'ext_data', 'uk', 'geography', 'boundaries', 'WPZ')
data_out <- file.path(Sys.getenv('PUB_PATH'), 'datasets', 'uk', 'geography')
gb_grid  <- '+init=epsg:27700' # OSGB 1936 / British National Grid (projected)
ni_grid  <- '+init=epsg:29902' # TM65 / Irish Grid -- Ireland (projected)
latlong <- '+init=epsg:4326'   # WGS84 - World Geodetic System 1984 (unprojected)

# define functions ----------------------------------------------------------------------------------------------------------
get_measures <- function(shp, loca_id, is.ni = FALSE){
    gb_grid  <- '+init=epsg:27700'
    ni_grid  <- '+init=epsg:29902'
    latlong <- '+init=epsg:4326'
    shp <- spTransform(shp, CRS(latlong))
    xy <- as.data.frame(gCentroid(shp, byid = TRUE))
    prj <- gb_grid
    if(is.ni) prj <- ni_grid
    shp <- spTransform(shp, CRS(prj))
    t <- cbind( WPZ = shp@data[loca_id], xy, gLength(shp, byid = TRUE), sapply(shp@polygons, function(x) x@Polygons[[1]]@area) )
    names(t) <- c('WPZ', 'x_lon', 'y_lat', 'perimeter', 'area')
    t$WPZ <- as.character(t$WPZ)
    data.table(t)
}

### A) Population Weighted Centroids (from ONS) ---------------------------------------------------------------------------------

## England and Wales 
eng <- readOGR(cnt_path, 'EW_WPZ_pwc')
eng <- spTransform(eng, CRS(latlong))
eng <- data.table(eng@data$wz11cd, eng@coords)
setnames(eng, c('WPZ', 'wx_lon', 'wy_lat'))

## Scotland
sco <- readOGR(cnt_path, 'SC_WPZ_pwc')
sco <- spTransform(sco, CRS(latlong))
sco <- data.table(sco@data$WPZ, sco@coords)

## N.Ireland ==> STILL NOT PUBLISHED

## UK: bind all above
uk1 <- rbindlist(list(eng, sco), use.names = FALSE)[order(WPZ)]


### Save to database ------------------------------------------------------------------------------------------------------------

# open db connection
dbc <- dbConnect(MySQL(), group = 'dataOps', dbname = 'geography_uk')
# create temporary table including datatypes and index
dbSendQuery(dbc, 'DROP TABLE IF EXISTS temp')
dbWriteTable(dbc, 'temp', uk1, row.names = FALSE, append = TRUE)
dbSendQuery(dbc, "
    ALTER TABLE `temp`
        CHANGE COLUMN `WPZ` `WPZ` CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci' FIRST,
        CHANGE COLUMN `wx_lon` `wx_lon` DECIMAL(10,8) NOT NULL AFTER `WPZ`,
        CHANGE COLUMN `wy_lat` `wy_lat` DECIMAL(10,8) UNSIGNED NOT NULL AFTER `wx_lon`,
        ADD PRIMARY KEY (`WPZ`);
")
# update workplace_zones table
dbSendQuery(dbc, "
    UPDATE workplace_zones lk 
        JOIN temp t ON lk.WPZ = t.WPZ
    SET lk.wx_lon = t.wx_lon, lk.wy_lat = t.wy_lat
")
# clean temporary table 
dbSendQuery(dbc, 'DROP TABLE temp')
# close connection
dbDisconnect(dbc)


### B) Geometric Centroid, Perimeter, Area: calculated directly from boundaries -------------------------------------------------

## England and Wales 
# load original boundaries
eng <- readOGR(bnd_path, 'EW', stringsAsFactors = FALSE)
# calculate measures
eng <- get_measures(eng, 'wz11cd')

## Scotland
# load original boundaries
sco <- readOGR(bnd_path, 'SC', stringsAsFactors = FALSE)
# calculate measures
sco <- get_measures(sco, 'WZCD')

## N.Ireland
# load original boundaries
nie <- readOGR(bnd_path, 'NI', stringsAsFactors = FALSE)
# calculate measures
nie <- get_measures(nie, 'CD', is.ni = TRUE)

# UK: bind all above
uk2 <- rbindlist(list(eng, sco, nie))[order(WPZ)]

## Save to database -------------------------------------------------------------------------------------------------------------

# open db connection
dbc <- dbConnect(MySQL(), group = 'dataOps', dbname = 'geography_uk')
# create temporary table including datatypes and index
dbSendQuery(dbc, 'DROP TABLE IF EXISTS temp')
dbWriteTable(dbc, 'temp', uk2, row.names = FALSE, append = TRUE)
dbSendQuery(dbc, "
    ALTER TABLE `temp`
    	CHANGE COLUMN `WPZ` `WPZ` CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci' FIRST,
    	CHANGE COLUMN `x_lon` `x_lon` DECIMAL(10,8) NOT NULL AFTER `WPZ`,
    	CHANGE COLUMN `y_lat` `y_lat` DECIMAL(10,8) NOT NULL AFTER `x_lon`,
    	CHANGE COLUMN `perimeter` `perimeter` DECIMAL(9,3) UNSIGNED NOT NULL AFTER `y_lat`,
    	CHANGE COLUMN `area` `area` DECIMAL(15,6) UNSIGNED NOT NULL AFTER `perimeter`,
    	ADD PRIMARY KEY (`WPZ`);
")
# update workplace_zones table
dbSendQuery(dbc, "
    UPDATE workplace_zones lk 
        JOIN temp t ON lk.WPZ = t.WPZ 
    SET lk.x_lon = t.x_lon, lk.y_lat = t.y_lat, lk.perimeter = t.perimeter, lk.area = t.area
")
# clean table 
dbSendQuery(dbc, 'DROP TABLE temp')
# close connection
dbDisconnect(dbc)

## Save to fst ------------------------------------------------------------------------------------------------------------------

# read fst 
y <- read.fst(file.path(data_out, 'workplace_zones'), as.data.table = TRUE)

# delete columns
y[, c('wx_lon', 'wy_lat', 'x_lon', 'y_lat', 'perimeter', 'area') := NULL]

# join workplace_zones with uk1 and uk2 above
y <- y[ uk1[uk2, on = 'WPZ'], on = 'WPZ']

# save as fst 
write.fst(y, file.path(data_out, 'workplace_zones'))

## Clean & Exit -----------------------------------------------------------------------------------------------------------------
rm(list = ls())
gc()

