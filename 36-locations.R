###############################################################
# UK GEOGRAPHY * 61 - LOCATIONS
###############################################################
# All files come from ONSPD/documents, and saved in <data_in>/locations (unless otherwise specified)

# load packages ---------------------------------------------------------------------------------------------------------------------------
pkg <- c('data.table', 'fst', 'rgdal', 'rgeos', 'RMySQL')
invisible(lapply(pkg, require, character.only = TRUE))

# set constants ---------------------------------------------------------------------------------------------------------------------------
data_in <- file.path(Sys.getenv('PUB_PATH'), 'ext_data', 'uk', 'geography')
data_out <- file.path(Sys.getenv('PUB_PATH'), 'datasets', 'uk', 'geography')
gb_grid  <- '+init=epsg:27700'
ni_grid  <- '+init=epsg:29902'
latlong <- '+init=epsg:4326'
cols <- c('location_id', 'name', 'type', 'x_lon', 'y_lat', 'wx_lon', 'wy_lat', 'perimeter', 'area')
locations <- data.table(
    'location_id' = character(0), 'name' = character(0), 'type' = character(0), 
    'x_lon' = numeric(0), 'y_lat' = numeric(0), 'wx_lon' = numeric(0), 'wy_lat' = numeric(0), 'perimeter' = numeric(0), 'area' = numeric(0)
)

# Define functions ------------------------------------------------------------------------------------------------------------------------
get_measures <- function(loca_id, 
                         has.ni = TRUE, 
                         bnd_path = file.path(Sys.getenv('PUB_PATH'), 'boundaries', 'uk', 'shp', 's00'),
                         data_path = file.path(Sys.getenv('PUB_PATH'), 'datasets', 'uk', 'geography')
                ){
    gb_grid  <- '+init=epsg:27700'
    ni_grid  <- '+init=epsg:29902'
    bnd <- readOGR(bnd_path, loca_id, stringsAsFactors = FALSE)
    # calculate centroids for all locations (doesn't need projection)
    xy <- cbind( loca_id = bnd@data, as.data.frame(gCentroid(bnd, byid = TRUE)) )
    # separate GB from NI (because of different projections)
    lkps <- read.fst(file.path(data_path, 'output_areas'), columns = c('CTRY', loca_id), as.data.table = TRUE)
    lkps <- unique(lkps)
    lkps <- as.character(lkps[CTRY == 'NIE', get(loca_id)])
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
get_add_locations <- function(tcode, 
                              col2select = 1:2, 
                              has.ni = TRUE,
                              data_path = file.path(Sys.getenv('PUB_PATH'), 'ext_data', 'uk', 'geography')
                    ){
    
    message('Processing ', tcode, 's...')
    
    # read code and names
    fname <- paste0(file.path(data_path, 'locations', tcode), '.csv')
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

    message('Done! Processed ', nrow(y), ' ', tcode, ' areas.')
    return(y)    
}

# "Census" hierarchy ----------------------------------------------------------------------------------------------------------------------

## > LSOA ---------------------------------------------------------------------------------------------------------------------------------
message('Process locations: LSOA...')

# read code and names
y <- fread( file.path(data_in, 'locations', 'LSOA.csv'), col.names = c('location_id', 'name'))

# calculate geometric centroids, perimeter, area
y <- y[get_measures('LSOA'), on = 'location_id']

### add weighted centroids

## England
pwc.ew <- readOGR(file.path(data_in, 'centroids'), 'EW_LSOA_pwc', stringsAsFactors = FALSE)
pwc.ew <- spTransform(pwc.ew, CRS(latlong))
pwc.ew <- data.table(pwc.ew@data[, c('lsoa11cd')], pwc.ew@coords)
setnames(pwc.ew, c('location_id', 'wx_lon', 'wy_lat'))

## Scotland
pwc.sc <- readOGR(file.path(data_in, 'centroids'), 'SC_LSOA_pwc', stringsAsFactors = FALSE)
pwc.sc <- spTransform(pwc.sc, CRS(latlong))
pwc.sc <- data.table(pwc.sc@data[, c('DataZone')], pwc.sc@coords)
setnames(pwc.sc, c('location_id', 'wx_lon', 'wy_lat'))

## N. Ireland (still not available)

## UK
pwc <- rbindlist(list( pwc.ew, pwc.sc))

# add to other measures
y <- pwc[y, on = 'location_id'][order(location_id)]
y[, type := 'LSOA']
setcolorder(y, cols)

# add to main container
locations[, location_id := as.character(location_id)]
locations <- rbindlist(list( locations, y) )

## > MSOA ---------------------------------------------------------------------------------------------------------------------------------
message('Process locations: MSOA...')
# read code and names
y <- fread( file.path(data_in, 'locations', 'MSOA.csv'), col.names = c('location_id', 'name'))
y <- y[!grep('99999999', location_id)]

# calculate centroids, perimeter, area
y <- y[get_measures('MSOA', has.ni = FALSE), on = 'location_id']

## add weighted centroids (from ONS)

# England
pwc.ew <- readOGR(file.path(data_in, 'centroids'), 'EW_MSOA_pwc', stringsAsFactors = FALSE)
pwc.ew <- spTransform(pwc.ew, CRS(latlong))
pwc.ew <- data.table(pwc.ew@data[, c('msoa11cd')], pwc.ew@coords)
setnames(pwc.ew, c('location_id', 'wx_lon', 'wy_lat'))

## Scotland
pwc.sc <- readOGR(file.path(data_in, 'centroids'), 'SC_MSOA_pwc', stringsAsFactors = FALSE)
pwc.sc <- spTransform(pwc.sc, CRS(latlong))
pwc.sc <- data.table(pwc.sc@data[, c('InterZone')], pwc.sc@coords)
setnames(pwc.sc, c('location_id', 'wx_lon', 'wy_lat'))

## N. Ireland:
# areas not existing

## UK
pwc <- rbindlist(list( pwc.ew, pwc.sc))

# add to other measures
y <- pwc[y, on = 'location_id'][order(location_id)]
y[, type := 'MSOA']
setcolorder(y, cols)

# add to main container
locations <- rbindlist(list( locations, y) )


## > Other Types --------------------------------------------------------------------------------------------------------------------------
message('Process locations: LAD...')
locations <- rbindlist(list( locations, get_add_locations('LAD') ))

message('Process locations: CTY...')
# look for updates: http://geoportal.statistics.gov.uk/datasets?q=LAD_CTY_LU
y1 <- fread(
        file.path(data_in, 'lookups', 'Local_Authority_District_to_County_April_2019_Lookup_in_England.csv'), 
        select = 3:4,
        col.names = c('CTY', 'name')
)
y2 <- fread(file.path(data_in, 'locations', 'LAD.csv'), select = 1:2, col.names = c('CTY', 'name'))
y3 <- data.table(
    'CTY' = paste0(c('NIE', 'SCO', 'WLS'), '_CTY'),
    'name' = c('Northern Ireland', 'Scotland', 'Wales')
)
y <- rbindlist(list( 
        unique(y1[, .(CTY, name)]), 
        y2[grepl('E060', CTY), .(CTY = gsub('E060', 'E069', CTY), name)], 
        y3 
))
fwrite(y[order(CTY)], file.path(data_in, 'locations', 'CTY.csv'))
locations <- rbindlist(list( locations, get_add_locations('CTY') ))

message('Process locations: RGN...')
# the file has been manually edited to include pseudo NSW
locations <- rbindlist(list( locations, get_add_locations('RGN') ))

message('Process locations: CTRY...')
# read code and names
y <- data.table('location_id' = c('ENG', 'NIE', 'SCO', 'WLS'), 'name' = c('England', 'N. Ireland', 'Scotland', 'Wales'))

# calculate geometric centroids, perimeter, area
y <- y[get_measures('CTRY'), on = 'location_id']
y <- y[order(location_id)]
y[, `:=`(type = 'CTRY', wx_lon = NA, wy_lat = NA)]
setcolorder(y, cols)

# add to main container
locations <- rbindlist(list( locations, y) )


# "Postcodes" hierarchy -------------------------------------------------------------------------------------------------------------------

message('Process locations: PCS...')
locations <- rbindlist(list( locations, get_add_locations('PCS', 1) ))

message('Process locations: PCD...')
locations <- rbindlist(list( locations, get_add_locations('PCD', 1) ))

message('Process locations: PCT...')
locations <- rbindlist(list( locations, get_add_locations('PCT') ))

message('Process locations: PCA...')
locations <- rbindlist(list( locations, get_add_locations('PCA') ))


# "Statistical" hierarchy -----------------------------------------------------------------------------------------------------------------

message('Process locations: MTC...')
y <- fread(
        file.path(data_in, 'lookups', 'Output_Area_2011_to_Major_Towns_and_Cities_December_2015_Lookup_in_England_and_Wales.csv'), 
        select = 2:3,
        col.names = c('MTC', 'name')
)
y <- unique(y[nchar(MTC) > 0, .(MTC, name)])
fwrite(y[order(MTC)], paste0(data_in, '/locations/MTC.csv'))
locations <- rbindlist(list( locations, get_add_locations('MTC', has.ni = FALSE) ))

message('Process locations: BUA...')
locations <- rbindlist(list( locations, get_add_locations('BUA', has.ni = FALSE) ))

message('Process locations: BUAS...')
locations <- rbindlist(list( locations, get_add_locations('BUAS', has.ni = FALSE) ))


# "Admin" hierarchy ----------------------------------------------------------------------------------------------------------------------

message('Process locations: TTWA...')
locations <- rbindlist(list( locations, get_add_locations('TTWA') ))

message('Process locations: WARD...')
locations <- rbindlist(list( locations, get_add_locations('WARD') ))

message('Process locations: PCON...')
locations <- rbindlist(list( locations, get_add_locations('PCON') ))

message('Process locations: CED...')
locations <- rbindlist(list( locations, get_add_locations('CED', has.ni = FALSE) ))

message('Process locations: PAR...')
locations <- rbindlist(list( locations, get_add_locations('PAR', has.ni = FALSE) ))

# "Services" hierarchy ----------------------------------------------------------------------------------------------------------------------

message('Process locations: PFA...')
locations <- rbindlist(list( locations, get_add_locations('PFA', has.ni = FALSE) ))

message('Process locations: STP...')
locations <- rbindlist(list( locations, get_add_locations('STP', has.ni = FALSE) ))

message('Process locations: CCG...')
locations <- rbindlist(list( locations, get_add_locations('CCG', col2select = c(1, 3)) ))

message('Process locations: NHSO...')
locations <- rbindlist(list( locations, get_add_locations('NHSO', col2select = c(1, 3)) ))

message('Process locations: NHSR...')
locations <- rbindlist(list( locations, get_add_locations('NHSR', col2select = c(1, 3)) ))


# Save to database ------------------------------------------------------------------------------------------------------------------------
message('Saving to database...')
dbc <- dbConnect(MySQL(), group = 'geouk')
dbSendQuery(dbc, 'TRUNCATE TABLE locations')
dbWriteTable(dbc, 'locations', locations, row.names = FALSE, append = TRUE)
dbDisconnect(dbc)

# Recode and save as fst with index by type and region --------------------------------------------------------------------------
message('Saving as fst...')
locations[, type := factor(type)]
locations <- locations[order(type, location_id)]
y <- locations[, .N, type]
y[, n2 := cumsum(N)][, n1 := shift(n2, 1L, type = 'lag') + 1][is.na(n1), n1 := 1]
setcolorder(y, c('type', 'N', 'n1', 'n2'))
write.fst(y, file.path(data_out, 'locations.idx'))
setcolorder(locations, 'type')
write.fst(locations, file.path(data_out, 'locations'))

# Clean & Exit -----------------------------------------------------------------------------------------------------------------
message('Finished!')
rm(list = ls())
gc()
