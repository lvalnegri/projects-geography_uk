###############################################################
# 52a- CALCULATE OA MEASURES
###############################################################

## load packages ------------------------------------------------------------------------------------------------------------
pkg <- c('data.table', 'maptools', 'rgdal', 'rgeos', 'RMySQL')
invisible(lapply(pkg, require,  char = TRUE))

## Define variables ---------------------------------------------------------------------------------------------------------
boundaries_path <- 
    if(substr(Sys.info()['sysname'], 1, 1) == 'W'){
        'D:/cloud/OneDrive/data/UK/geography/boundaries/originals'
    } else {
        '/home/datamaps/data/UK/geography/boundaries/originals'
    }
gb_grid  <- '+init=epsg:27700'
ni_grid  <- '+init=epsg:29902'
latlong <- '+init=epsg:4326'
 
## Define functions ----------------------------------------------------------------------------------------------------------
get_measures <- function(shp, loca_id, is.ni = FALSE){
    gb_grid  <- '+init=epsg:27700'
    ni_grid  <- '+init=epsg:29902'
    latlong <- '+init=epsg:4326'
    shp <- spTransform(shp, CRS(latlong))
    xy <- as.data.frame(gCentroid(shp, byid = TRUE))
    prj <- gb_grid
    if(is.ni) prj <- ni_grid
    shp <- spTransform(shp, CRS(prj))
    t <- cbind( OA = shp@data[loca_id], xy, gLength(shp, byid = TRUE), sapply(shp@polygons, function(x) x@Polygons[[1]]@area) )
    names(t) <- c('OA', 'x_lon', 'y_lat', 'perimeter', 'area')
    t$OA <- as.character(t$OA)
    data.table(t)
}

### A) Population Weighted Centroids (needs rely on ONS) -----------------------------------------------------------------------

## England and Wales
# download csv files
eng <- fread('https://opendata.arcgis.com/datasets/ba64f679c85f4563bfff7fad79ae57b1_0.csv', 
             select = c(1, 2, 4),
             col.names = c('x_lon', 'y_lat', 'OA')
)
# change order of columns
setcolorder(eng, c('OA', 'x_lon', 'y_lat'))

## Scotland
# download and unzip boundaries
download.file('https://www.nrscotland.gov.uk/files/geography/output-area-2011-pwc.zip', 'boundaries.zip')
unzip('boundaries.zip')
# read boundaries
sco <- readOGR('.', 'OutputArea2011_PWC', stringsAsFactors = FALSE)
# extract only id and coordinates
sco <- sco@data[, c(2, 4, 5)]
# rename  columns
names(sco) <- c('OA', 'x_lon', 'y_lat')
sco$x_lon <- as.numeric(sco$x_lon)
sco$y_lat <- as.numeric(sco$y_lat)
# convert to spatial
coordinates(sco) <- ~x_lon+y_lat
# apply correct projection
proj4string(sco) <- CRS(gb_grid)
# change projection to wgs84
sco <- spTransform(sco, CRS(latlong))
# extract only ids and coordinates
sco <- data.table(OA = sco@data$OA, sco@coords)

## N.Ireland
# download and unzip boundaries
download.file('https://www.nisra.gov.uk/sites/nisra.gov.uk/files/publications/SA2011_Esri_Shapefile_0.zip', 'boundaries.zip')
unzip('boundaries.zip')
# read boundaries
nie <- readOGR('.', 'SA2011', stringsAsFactors = FALSE)
# extract only id and coordinates
nie <- nie@data[, c(1, 3, 4)]
# rename  columns
names(nie) <- c('OA', 'x_lon', 'y_lat')
# reconvert to spatial
coordinates(nie) <- ~x_lon+y_lat
# apply correct projection
proj4string(nie) <- CRS(ni_grid)
# change projection to wgs84
nie <- spTransform(nie, CRS(latlong))
# extract only ids and coordinates
nie <- data.table(OA = nie@data$OA, nie@coords)

## UK
# bind all above
uk <- rbind(eng, sco, nie)[order(OA)]
# open db connection
dbc <- dbConnect(MySQL(), group = 'dataOps', dbname = 'geography_uk')
# create temporary table including datatypes and index
dbSendQuery(dbc, 'DROP TABLE IF EXISTS tmp')
dbWriteTable(dbc, 'tmp', uk, row.names = FALSE, append = TRUE)
dbSendQuery(dbc, "
    ALTER TABLE `tmp`
    	CHANGE COLUMN `OA` `OA` CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci' FIRST,
    	CHANGE COLUMN `x_lon` `x_lon` DECIMAL(10,8) NOT NULL AFTER `OA`,
    	CHANGE COLUMN `y_lat` `y_lat` DECIMAL(10,8) UNSIGNED NOT NULL AFTER `x_lon`,
    	ADD PRIMARY KEY (`OA`);
")
# update lookups table
dbSendQuery(dbc, "UPDATE lookups lk JOIN tmp t ON lk.OA = t.OA SET lk.wx_lon = t.x_lon, lk.wy_lat = t.y_lat")
# clean table 
dbSendQuery(dbc, 'DROP TABLE tmp')
# close connection
dbDisconnect(dbc)


### B) Centroid, Perimeter, Area: calculated directly from boundaries ----------------------------------------------------------

## England and Wales
# download and unzip boundaries
download.file('https://opendata.arcgis.com/datasets/09b8a48426e3482ebbc0b0c49985c0fb_2.zip', 'boundaries.zip')
unzip('boundaries.zip')
# read general name
n_shp <- unzip('boundaries.zip', list = TRUE)[1, 1]
n_shp <- substr(n_shp, 1, regexpr('\\.', n_shp)[1] - 1)
# read boundaries
eng <- readOGR('.', n_shp, stringsAsFactors = FALSE)
# calculate measures
eng <- get_measures(eng, 'oa11cd')
# delete boundaries files
file.remove(unzip('boundaries.zip', list = TRUE)[, 1])

## Scotland
# download and unzip boundaries
download.file('https://www.nrscotland.gov.uk/files/geography/output-area-2011-eor.zip', 'boundaries.zip')
unzip('boundaries.zip')
# read general name
n_shp <- unzip('boundaries.zip', list = TRUE)[1, 1]
n_shp <- substr(n_shp, 1, regexpr('\\.', n_shp)[1] - 1)
# read boundaries
sco <- readOGR('.', n_shp, stringsAsFactors = FALSE)
# calculate measures
sco <- get_measures(sco, 'code')
# delete boundaries files
file.remove(unzip('boundaries.zip', list = TRUE)[, 1])

## N.Ireland
# download and unzip boundaries
download.file('https://www.nisra.gov.uk/sites/nisra.gov.uk/files/publications/SA2011_Esri_Shapefile_0.zip', 'boundaries.zip')
unzip('boundaries.zip')
# read general name
n_shp <- unzip('boundaries.zip', list = TRUE)[1, 1]
n_shp <- substr(n_shp, 1, regexpr('\\.', n_shp)[1] - 1)
# read boundaries
nie <- readOGR('.', n_shp, stringsAsFactors = FALSE)
# calculate measures
nie <- get_measures(nie, 'SA2011')
# delete boundaries files
file.remove(unzip('boundaries.zip', list = TRUE)[, 1])

## UK
# bind all above
uk <- rbind(eng, sco, nie)[order(OA)]
# open db connection
dbc <- dbConnect(MySQL(), group = 'dataOps', dbname = 'geography_uk')
# create temporary table including datatypes and index
dbSendQuery(dbc, 'DROP TABLE IF EXISTS tmp')
dbWriteTable(dbc, 'tmp', uk, row.names = FALSE, append = TRUE)
dbSendQuery(dbc, "
    ALTER TABLE `tmp`
    	CHANGE COLUMN `OA` `OA` CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci' FIRST,
    	CHANGE COLUMN `x_lon` `x_lon` DECIMAL(10,8) NOT NULL AFTER `OA`,
    	CHANGE COLUMN `y_lat` `y_lat` DECIMAL(10,8) NOT NULL AFTER `x_lon`,
    	CHANGE COLUMN `perimeter` `perimeter` DECIMAL(9,3) UNSIGNED NOT NULL AFTER `y_lat`,
    	CHANGE COLUMN `area` `area` DECIMAL(15,6) UNSIGNED NOT NULL AFTER `perimeter`,
    	ADD PRIMARY KEY (`OA`);
")
# update lookups table
dbSendQuery(dbc, "UPDATE lookups lk JOIN tmp t ON lk.OA = t.OA SET lk.x_lon = t.x_lon, lk.y_lat = t.y_lat, lk.perimeter = t.perimeter, lk.area = t.area")
# clean table 
dbSendQuery(dbc, 'DROP TABLE tmp')
# close connection
dbDisconnect(dbc)


## Clean & Exit ---------------------------------------------------------------------------------------------------------------
file.remove( c('boundaries.zip', 'OA_TO_HIGHER_AREAS.csv') )
rm(list = ls())
gc()
