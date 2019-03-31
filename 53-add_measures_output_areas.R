################################################################################
# UK GEOGRAPHY * 52 - BOUNDARIES: add centroids and measures to output_areas
################################################################################

# load packages -----------------------------------------------------------------------------------------------------------------
pkg <- c('data.table', 'fst', 'maptools', 'rgdal', 'rgeos', 'RMySQL', 'sp')
invisible(lapply(pkg, require, character.only = TRUE))

# set constants ------------------------------------------------------------------------------------------------
bnd_path <- file.path(Sys.getenv('PUB_PATH'), 'ext-data/geography_uk/boundaries')
data_out <- file.path(Sys.getenv('PUB_PATH'), '/usr/local/share/data/dataframes/geography_uk')
gb_grid  <- '+init=epsg:27700'
ni_grid  <- '+init=epsg:29902'
latlong <- '+init=epsg:4326'

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
    t <- cbind( OA = shp@data[loca_id], xy, gLength(shp, byid = TRUE), sapply(shp@polygons, function(x) x@Polygons[[1]]@area) )
    names(t) <- c('OA', 'x_lon', 'y_lat', 'perimeter', 'area')
    t$OA <- as.character(t$OA)
    data.table(t)
}

### A) Population Weighted Centroids (from ONS) ---------------------------------------------------------------------------------

## England and Wales 
# download csv files
eng <- fread('https://opendata.arcgis.com/datasets/ba64f679c85f4563bfff7fad79ae57b1_0.csv', 
             select = c(1, 2, 4),
             col.names = c('wx_lon', 'wy_lat', 'OA')
)
# change order of columns
setcolorder(eng, c('OA', 'wx_lon', 'wy_lat'))

## Scotland
# download and unzip boundaries
download.file('https://www.nrscotland.gov.uk/files/geography/output-area-2011-pwc.zip', 'boundaries.zip')
unzip('boundaries.zip')
# read boundaries
sco <- readOGR('.', 'OutputArea2011_PWC', stringsAsFactors = FALSE)
# extract only id and coordinates
sco <- sco@data[, c(2, 4, 5)]
# rename  columns
names(sco) <- c('OA', 'wx_lon', 'wy_lat')
sco$wx_lon <- as.integer(sco$wx_lon)
sco$wy_lat <- as.integer(sco$wy_lat)
# convert to spatial
coordinates(sco) <- ~wx_lon+wy_lat
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
names(nie) <- c('OA', 'wx_lon', 'wy_lat')
# reconvert to spatial
coordinates(nie) <- ~wx_lon+wy_lat
# apply correct projection
proj4string(nie) <- CRS(ni_grid)
# change projection to wgs84
nie <- spTransform(nie, CRS(latlong))
# extract only ids and coordinates
nie <- data.table(OA = nie@data$OA, nie@coords)

## UK: bind all above
uk1 <- rbind(eng, sco, nie)[order(OA)]


### Save to database ------------------------------------------------------------------------------------------------------------

# open db connection
dbc <- dbConnect(MySQL(), group = 'dataOps', dbname = 'geography_uk')
# create temporary table including datatypes and index
dbSendQuery(dbc, 'DROP TABLE IF EXISTS temp')
dbWriteTable(dbc, 'temp', uk1, row.names = FALSE, append = TRUE)
dbSendQuery(dbc, "
    ALTER TABLE `temp`
        CHANGE COLUMN `OA` `OA` CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci' FIRST,
        CHANGE COLUMN `wx_lon` `wx_lon` DECIMAL(10,8) NOT NULL AFTER `OA`,
        CHANGE COLUMN `wy_lat` `wy_lat` DECIMAL(10,8) UNSIGNED NOT NULL AFTER `wx_lon`,
        ADD PRIMARY KEY (`OA`);
")
# update output_areas table
dbSendQuery(dbc, "
    UPDATE output_areas lk 
        JOIN temp t ON lk.OA = t.OA 
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
eng <- get_measures(eng, 'oa11cd')

## Scotland
# load original boundaries
sco <- readOGR(bnd_path, 'SC', stringsAsFactors = FALSE)
# calculate measures
sco <- get_measures(sco, 'code')

## N.Ireland
# load original boundaries
nie <- readOGR(bnd_path, 'NI', stringsAsFactors = FALSE)
# calculate measures
nie <- get_measures(nie, 'SA2011', is.ni = TRUE)

# UK: bind all above
uk2 <- rbind(eng, sco, nie)[order(OA)]


## Save to database -------------------------------------------------------------------------------------------------------------

# open db connection
dbc <- dbConnect(MySQL(), group = 'dataOps', dbname = 'geography_uk')
# create temporary table including datatypes and index
dbSendQuery(dbc, 'DROP TABLE IF EXISTS temp')
dbWriteTable(dbc, 'temp', uk2, row.names = FALSE, append = TRUE)
dbSendQuery(dbc, "
    ALTER TABLE `temp`
    	CHANGE COLUMN `OA` `OA` CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci' FIRST,
    	CHANGE COLUMN `x_lon` `x_lon` DECIMAL(10,8) NOT NULL AFTER `OA`,
    	CHANGE COLUMN `y_lat` `y_lat` DECIMAL(10,8) NOT NULL AFTER `x_lon`,
    	CHANGE COLUMN `perimeter` `perimeter` DECIMAL(9,3) UNSIGNED NOT NULL AFTER `y_lat`,
    	CHANGE COLUMN `area` `area` DECIMAL(15,6) UNSIGNED NOT NULL AFTER `perimeter`,
    	ADD PRIMARY KEY (`OA`);
")
# update output_areas table
dbSendQuery(dbc, "
    UPDATE output_areas lk 
        JOIN temp t ON lk.OA = t.OA 
    SET lk.x_lon = t.x_lon, lk.y_lat = t.y_lat, lk.perimeter = t.perimeter, lk.area = t.area
")
# clean table 
dbSendQuery(dbc, 'DROP TABLE temp')
# close connection
dbDisconnect(dbc)

## Save to fst ------------------------------------------------------------------------------------------------------------------

# read fst 
y <- read.fst(file.path(data_out, 'output_areas'), as.data.table = TRUE)

# delete columns
y[, c('wx_lon', 'wy_lat', 'x_lon', 'y_lat', 'perimeter', 'area') := NULL]

# join output_areas with uk1 and uk2 above
y <- y[ uk1[uk2, on = 'OA'], on = 'OA']

# save as fst 
write.fst(y, file.path(data_out, 'output_areas'))

## Clean & Exit -----------------------------------------------------------------------------------------------------------------
file.remove('boundaries.zip')
rm(list = ls())
gc()

