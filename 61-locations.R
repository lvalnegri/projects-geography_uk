###############################################################
# UK GEOGRAPHY * 61 - LOCATIONS
###############################################################
# All files comes from ONSPD, unless otherwise specified.

# load packages ---------------------------------------------------------------------------------------------------------------------------
pkg <- c('data.table', 'fst', 'rgdal', 'rgeos', 'RMySQL')
invisible(lapply(pkg, require, character.only = TRUE))

# set constants ---------------------------------------------------------------------------------------------------------------------------
data_path <- file.path(Sys.getenv('PUB_PATH'), 'ext-data/geography_uk')
data_out  <- file.path(Sys.getenv('PUB_PATH'), 'dataframes/geography_uk')
gb_grid  <- '+init=epsg:27700'
ni_grid  <- '+init=epsg:29902'
latlong <- '+init=epsg:4326'
cols <- c('location_id', 'name', 'type', 'x_lon', 'y_lat', 'wx_lon', 'wy_lat', 'perimeter', 'area')
locations <- data.table(
    'location_id' = character(0), 'name' = character(0), 'type' = character(0), 
    'x_lon' = numeric(0), 'y_lat' = numeric(0), 'wx_lon' = numeric(0), 'wy_lat' = numeric(0), 'perimeter' = numeric(0), 'area' = numeric(0)
)

# Define functions ------------------------------------------------------------------------------------------------------------------------
get_measures <- function(loca_id, has.ni = TRUE, bnd_path = '/usr/local/share/data/boundaries/shp/UK'){
    gb_grid  <- '+init=epsg:27700'
    ni_grid  <- '+init=epsg:29902'
    bnd <- readOGR(bnd_path, loca_id)
    # calculate centroids for all locations (doesn't need projection)
    xy <- cbind( loca_id = bnd@data, as.data.frame(gCentroid(bnd, byid = TRUE)) )
    # separate GB from NI (because of different projections)
    lkps <- read.fst(file.path(data_out, 'output_areas'), columns = c('CTRY', loca_id), as.data.table = TRUE)
    lkps <- unique(lkps)
    lkps <- as.character(lkps[CTRY == 'N', get(loca_id)])
    if(has.ni){
        bnd.ni <- subset(bnd, bnd$id %in% lkps)
        bnd.ni <- spTransform(bnd.ni, CRS(ni_grid))
        ap.ni <- cbind( loca_id = bnd.ni@data, 'perimeter' = gLength(bnd.ni, byid = TRUE), 'area' = gArea(bnd.ni, byid = TRUE) )
    }
    bnd <- subset(bnd, !bnd$id %in% lkps)
    bnd <- spTransform(bnd, CRS(gb_grid))
    ap <- cbind( loca_id = bnd@data, 'perimeter' = gLength(bnd, byid = TRUE), 'area' = gArea(bnd, byid = TRUE) )
    if(has.ni) ap <- rbind(ap.ni, ap)
    xy <- setDT(merge(xy, ap))
    setnames(xy, c('location_id', 'x_lon', 'y_lat', 'perimeter', 'area') )
    xy[!is.na(location_id)]
}
get_add_locations <- function(tcode, col2select = 1:2, has.ni = TRUE){
    
    message('Processing ', tcode, 's...')
    
    # read code and names
    fname <- paste0(data_path, '/locations/', tcode, '.csv')
    if(length(col2select) == 1){
        y <- fread( fname, select = col2select, col.names = c('location_id'), na.strings = '')
        y[, name := location_id]
    } else {
        y <- fread( fname, select = col2select, col.names = c('location_id', 'name'), na.strings = '')
    }
    
    # just to avoid weird surprises in case the supposed "locations" table is actually a "lookups" table
    y <- unique(y[!is.na(location_id)])
    
    # calculate centroids, perimeter, area
    y <- y[get_measures(tcode, has.ni = has.ni), on = 'location_id']
    y <- y[order(location_id)]
    y[, `:=`(location_id = as.character(location_id), type = tcode, wx_lon = NA, wy_lat = NA)]
    setcolorder(y, cols)

    message('Done! Processed ', nrow(y), ' ', tcode, ' polygons.')
    return(y)    
}

## Process locations: LSOA ----------------------------------------------------------------------------------------------------------------

message('Processing LSOAs...')
# read code and names
y <- fread( file.path(data_path, 'locations', 'LSOA.csv'), col.names = c('location_id', 'name'))

# calculate centroids, perimeter, area
y <- y[get_measures('LSOA'), on = 'location_id']

### add weighted centroids

## England
pwc.ew <- fread( 
        file.path(data_path, 'centroids', 'EW_LSOA.csv'), 
        select = c('lsoa11cd', 'X', 'Y'), 
        col.names = c('location_id', 'wx_lon', 'wy_lat')
)

## Scotland
# read LSOA boundaries, then extract ids and centroids
pwc.sc <- readOGR(file.path(data_path, 'centroids'), 'SC_LSOA')
pwc.sc <- pwc.sc@data[, c('DataZone', 'Easting', 'Northing')]
names(pwc.sc) <- c('location_id', 'wx_lon', 'wy_lat')
pwc.sc$wx_lon <- as.integer(as.character(pwc.sc$wx_lon))
pwc.sc$wy_lat <- as.integer(as.character(pwc.sc$wy_lat))
# convert to spatial
coordinates(pwc.sc) <- ~wx_lon+wy_lat
# apply EN projection
proj4string(pwc.sc) <- CRS(gb_grid)
# change EN projection to wgs84
pwc.sc <- spTransform(pwc.sc, CRS(latlong))
pwc.sc <- as.data.frame(pwc.sc)

## N. Ireland
# still not available

## UK
pwc <- rbindlist(list( pwc.ew, pwc.sc))

y <- pwc[y, on = 'location_id'][order(location_id)]
y[, type := 'LSOA']
setcolorder(y, cols)
# add to main container
locations[, location_id := as.character(location_id)]
locations <- rbindlist( list(locations, y) )


## Process locations: MSOA ----------------------------------------------------------------------------------------------------------------

message('Processing MSOAs...')
# read code and names
y <- fread( file.path(data_path, 'locations', 'MSOA.csv'), col.names = c('location_id', 'name'))
y[!grep('99999999', location_id)]

# calculate centroids, perimeter, area
y <- y[get_measures('MSOA', has.ni = FALSE), on = 'location_id']

## add weighted centroids (from ONS)

# England
pwc.ew <- fread(
        file.path(data_path, 'centroids', 'EW_MSOA.csv'), 
        select = c('msoa11cd', 'X', 'Y'), 
        col.names = c('location_id', 'wx_lon', 'wy_lat')
)

## Scotland
# read MSOA boundaries, then extract ids and centroids
pwc.sc <- readOGR(file.path(data_path, 'centroids'), 'SC_MSOA')
pwc.sc <- pwc.sc@data[, c('InterZone', 'Easting', 'Northing')]
names(pwc.sc) <- c('location_id', 'wx_lon', 'wy_lat')
pwc.sc$wx_lon <- as.integer(as.character(pwc.sc$wx_lon))
pwc.sc$wy_lat <- as.integer(as.character(pwc.sc$wy_lat))
# convert to spatial
coordinates(pwc.sc) <- ~wx_lon+wy_lat
# apply EN projection
proj4string(pwc.sc) <- CRS(gb_grid)
# change EN projection to wgs84
pwc.sc <- spTransform(pwc.sc, CRS(latlong))
pwc.sc <- as.data.frame(pwc.sc)

## UK
pwc <- rbindlist(list( pwc.ew, pwc.sc))

y <- pwc[y, on = 'location_id'][order(location_id)]
y[, type := 'MSOA']
setcolorder(y, cols)
# add to main container
locations[, location_id := as.character(location_id)]
locations <- rbindlist( list(locations, y) )


## Process locations: LAD -----------------------------------------------------------------------------------------------------------------
locations <- rbindlist( list(locations, get_add_locations('LAD') ))

## Process locations: CTY --------------------------------------------------------------------------------------------------------
# NOTE that the file is not the one in ONSPD but ==> 'https://opendata.arcgis.com/datasets/180a69233de94a8da3fb6a8a4959fcc7_0.csv'
locations <- rbindlist( list(locations, get_add_locations('CTY', 3:4, FALSE) ))

## Process locations: RGN --------------------------------------------------------------------------------------------------------
locations <- rbindlist( list(locations, get_add_locations('RGN', c(1, 3), FALSE) ))

## Process locations: CTRY -------------------------------------------------------------------------------------------------------
message('Processing CTRYs...')
# read code and names
y <- data.table('location_id' = c('E', 'N', 'S', 'W'), 'name' = c('England', 'N. Ireland', 'Scotland', 'Wales'))

# calculate centroids, perimeter, area
y <- y[get_measures('CTRY'), on = 'location_id']
y <- y[order(location_id)]
y[, `:=`(type = 'CTRY', wx_lon = NA, wy_lat = NA)]
setcolorder(y, cols)

# add to main container
locations[, location_id := as.character(location_id)]
locations <- rbindlist( list(locations, y) )


## Process locations: PCS --------------------------------------------------------------------------------------------------------
locations <- rbindlist( list(locations, get_add_locations('PCS', 1) ))

## Process locations: PCD --------------------------------------------------------------------------------------------------------
locations <- rbindlist( list(locations, get_add_locations('PCD', 1) ))

## Process locations: PCT -------------------------------------------------------------------------------------------------------
locations <- rbindlist( list(locations, get_add_locations('PCT') ))

## Process locations: PCA --------------------------------------------------------------------------------------------------------
locations <- rbindlist( list(locations, get_add_locations('PCA') ))

## Process locations: TTWA -------------------------------------------------------------------------------------------------------
locations <- rbindlist( list(locations, get_add_locations('TTWA') ))

## Process locations: WARD -------------------------------------------------------------------------------------------------------
locations <- rbindlist( list(locations, get_add_locations('WARD') ))

## Process locations: PCON -------------------------------------------------------------------------------------------------------
locations <- rbindlist( list(locations, get_add_locations('PCON') ))

## Process locations: CED --------------------------------------------------------------------------------------------------------
locations <- rbindlist( list(locations, get_add_locations('CED', has.ni = FALSE) ))

## Process locations: PAR --------------------------------------------------------------------------------------------------------
locations <- rbindlist( list(locations, get_add_locations('PAR', has.ni = FALSE) ))

## Process locations: MTC --------------------------------------------------------------------------------------------------------
# NOTE that the file is not the one in ONSPD but ==> 'https://opendata.arcgis.com/datasets/78ff27e752e44c3194617017f3f15929_0.csv'
locations <- rbindlist( list(locations, get_add_locations('MTC', 2:3, FALSE) ))

## Process locations: BUA --------------------------------------------------------------------------------------------------------
locations <- rbindlist( list(locations, get_add_locations('BUA', has.ni = FALSE) ))

## Process locations: BUAS -------------------------------------------------------------------------------------------------------
locations <- rbindlist( list(locations, get_add_locations('BUAS', has.ni = FALSE) ))

# Save to database --------------------------------------------------------------------------------------------------------------
message('Saving to database...')
dbc <- dbConnect(MySQL(), group = 'dataOps', dbname = 'geography_uk')
dbSendQuery(dbc, 'TRUNCATE TABLE locations')
dbWriteTable(dbc, 'locations', locations, row.names = FALSE, append = TRUE)
dbDisconnect(dbc)

# Recode and save as fst --------------------------------------------------------------------------------------------------------
message('Saving as fst...')
locations[, type := factor(type)]
write.fst(locations, file.path(data_out, 'locations'))

# Clean & Exit -----------------------------------------------------------------------------------------------------------------
message('FINISHED!')
rm(list = ls())
gc()
