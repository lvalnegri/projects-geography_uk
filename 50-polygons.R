###############################################################
# 50- WORK WITH BOUNDARIES (POLYGONS)
###############################################################

### 1- Blend Output Areas from ENG, WLS, SCO, NIE into one unique file for the UK as a whole --------------------------------------
# Download the Output Areas (OA) boundaries for each country :
#   - England and Wales (EW): browse to [COA Boundaries](http://geoportal.statistics.gov.uk/datasets?q=COA%20Boundaries&sort_by=name) 
#     and download the *Generalised Clipped boundaries* full dataset shapefile (~50MB). The projection is [British National Grid, OSGB_1936](http://spatialreference.org/ref/epsg/osgb-1936-british-national-grid/)
#   - Scotland (SC): open [2011 Census Geography](http://www.nrscotland.gov.uk/statistics-and-data/geography/our-products/census-datasets/2011-census/2011-boundaries) and download the *2011 Output Area Boundaries, Extent of the Realm* zip file (~28MB). The projection is British National Grid, OSGB_1936
#   - Northern Ireland (NI): go to [NISRA Geography](https://www.nisra.gov.uk/publications/small-area-boundaries-gis-format)
#     and download the *ESRI Shapefile format* zip file (~25MB). The projection is [Irish Grid, GCS_TM65](http://spatialreference.org/ref/epsg/29902/)
# 
# Extract from each archives only the files with the extensions: **shp** (geometry), **shx** (index), **prj** (projection), and **dbf** (data). Rename the three blocks as: **EW.*** (England and Wales), **SC.*** (Scotland), **NI.*** (Northern Ireland).

# load the packages
library('rgdal')     # easily read/write the shapefiles, and automatically apply the projection contained in the prj file
library('maptools')  # merge multiple Spatial objects
# set the directory of the boundaries shapefiles
boundaries.path <- 
    if(substr(Sys.info()['sysname'], 1, 1) == 'W'){
        'D:/cloud/OneDrive/data/UK/geography/boundaries'
    } else {
        '/home/datamaps/data/UK/geography/boundaries'
    }
# set the projection string for WGS84
proj.wgs <- '+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0'

# English-Welsh
shp.ew <- readOGR(boundaries.path, layer = 'EW')
# check the projection, and read the field to keep as future id; in this case: "oa11cd"
summary(shp.ew)
# transform the shapefile projection to WGS84 
shp.ew <- spTransform(shp.ew, CRS(proj.wgs))
# keep in the data slot only the ONS Output Area id, renaming it as 'id'
shp.ew <- shp.ew[, 'oa11cd']
colnames(shp.ew@data) <- c('id')
# reassign the polygon IDs
shp.ew <- spChFIDs(shp.ew, as.character(shp.ew$id))

# SCotland
shp.sc <- readOGR(boundaries.path, layer = 'SC')
summary(shp.sc)
shp.sc <- spTransform(shp.sc, CRS(proj.wgs))
shp.sc <- shp.sc[, 'code']
colnames(shp.sc@data) <- c('id')
shp.sc <- spChFIDs(shp.sc, as.character(shp.sc$id))

# Northern Ireland
shp.ni <- readOGR(boundaries.path, layer = 'NI')
summary(shp.ni)
shp.ni <- spTransform(shp.ni, CRS(proj.wgs))
shp.ni <- shp.ni[, 'SA2011']
colnames(shp.ni@data) <- c('id')
shp.ni <- spChFIDs(shp.ni, as.character(shp.ni$id))

# Create the UK boundaries as a merge of all previous boundaries
shp.uk <- spRbind(spRbind(shp.ew, shp.sc), shp.ni)

# you could try to look at the result, but it takes a while...
plot(shp.uk)

# instead, count by country:
table(substr(shp.uk@data$id, 1, 1))
# and it should return the following result (for 2011 census):  E 171372, N 4537, S 46351, W 10036 


### 2- Merge polygons to create a boundary shapefile for a parent level ---------------------------------------------------------


# load packages
library(RMySQL)
library(rgdal)
library(rmapshaper)
library(maptools)

# set variables
boundaries.path <- # DO NOT include the last backslash
    if(substr(Sys.info()['sysname'], 1, 1) == 'W'){
        'D:/cloud/OneDrive/data/UK/geography/boundaries/london'
    } else {
        '/home/datamaps/data/UK/geography/boundaries'
    }
# define helper functions
merge.subpoly <- function(shp, subarea){
    # select all child polygons contained in specified parent polygon
    shp.tmp <- subset(shp, shp[['parent']] == subarea)
    # delete interiors
    shp.tmp <- ms_dissolve(shp.tmp)
    # define new polygon id
    shp.tmp$id <- subarea
    shp.tmp <- spChFIDs(shp.tmp, as.character(shp.tmp$id))
    return(shp.tmp)
}
build.parent.boundaries <- function(parent, child, simplify = FALSE, keep.pct = 0.2){
    # read base polygons from shapefile
    shp.base <- readOGR(boundaries.path, layer = child)
    # read lookups
    db_conn <- dbConnect(MySQL(), group = 'local', dbname = 'geographyUK')
    lkp <- dbGetQuery(db_conn, paste('SELECT DISTINCT', child, 'AS child,', parent, 'AS parent FROM lookups') )
    dbDisconnect(db_conn)
    # join shapefile data slot and lookup table on the child code 
    shp.base <- merge(shp.base, lkp, by.x = 'id', by.y = 'child')
    # Build the list of subareas 
    subareas <- sort(unique(shp.base[['parent']]))
    # Define first parent polygon
    print(paste('Processing', parent, 'subarea', subareas[1], '- number 1 out of', length(subareas)))
    shp.area <- merge.subpoly(shp.base, subareas[1])
    # proceed for all other parent polygons, attaching every results to previous object
    for(idx in 2:length(subareas)){
        print(paste('Processing', parent, 'subarea', subareas[idx], '- number', idx, 'out of', length(subareas)))
        shp.area <- spRbind(shp.area, merge.subpoly(shp.base, subareas[idx]))
    }
    # delete the rmapshaperid from Polygons
    shp.area <- shp.area[, 'id']
    # simplification should only happens when child is OA
    if(simplify){
        # save full result before simplifying (in case, remove old shapefiles)
        if(file.exists(paste0(boundaries.path, '/originals/', parent, '.shp') ) ) 
            file.remove(paste0(boundaries.path, '/originals/', parent, '.', c('shp', 'prj', 'dbf', 'shx')))
        writeOGR(shp.area, dsn = paste0(boundaries.path, '/originals'), layer = parent, driver = 'ESRI Shapefile')
        # reduce the details of the boundaries, the control is needed because the process of simplification could entirely dissove some polygons
        repeat{
            print(paste('Trying', keep.pct))
            shp.area.s <- ms_simplify(shp.area, keep = keep.pct, keep_shapes = TRUE)
            if(nrow(shp.area) == nrow(shp.area.s)) break
            keep.pct <- keep.pct + 0.02
        }
        print(paste('Simplified with a value of', keep.pct))
        # delete the rmapshaperid from Polygons
        shp.area <- shp.area.s[, 'id']
    }    
    # save Polygons as shapefile (in case, remove old shapefiles)
    if(file.exists(paste0(boundaries.path, '/', parent, '.shp') ) ) 
        file.remove(paste0(boundaries.path, '/', parent, '.', c('shp', 'prj', 'dbf', 'shx')))
    writeOGR(shp.area, dsn = boundaries.path, layer = parent, driver = 'ESRI Shapefile')
}


build.parent.boundaries('LSOA', 'OA', TRUE)
build.parent.boundaries('MSOA', 'LSOA')
build.parent.boundaries('LAD', 'MSOA')
build.parent.boundaries('CTY', 'LAD')
build.parent.boundaries('RGN', 'CTY')
build.parent.boundaries('CTRY', 'RGN')

build.parent.boundaries('PCS', 'OA', TRUE)
build.parent.boundaries('PCD', 'PCS')
build.parent.boundaries('PCA', 'PCD')


### 5- Query boundaries for a specified parent area

# load packages
library(RMySQL)
library(rgdal)
library(rmapshaper)

# define helper functions
query.boundaries <- function(area.type, parent.type, parent.ids, simplify = FALSE, save.shp = FALSE, return.shp = TRUE, add.to.path = NA){
    boundaries.path <-
        if(substr(Sys.info()['sysname'], 1, 1) == 'W'){
            'D:/cloud/OneDrive/data/UK/geography/boundaries'
        } else {
            '/home/datamaps/data/UK/geography/boundaries'
        }
    shp <- readOGR(boundaries.path, layer = area.type)
    db_conn <- dbConnect(MySQL(), group = 'local', dbname = 'geographyUK')
    lkp <- dbGetQuery(db_conn, paste0('SELECT DISTINCT ', area.type, ' FROM lookups WHERE ', parent.type, ' IN (', parent.ids, ')' ))
    dbDisconnect(db_conn)
    shp <- subset(shp, shp$id %in% unlist(lkp))
    if(simplify) shp <- ms_simplify(shp, keep = 0.20, keep_shapes = TRUE)
    if(save.shp){
        if(!is.na(add.to.path)) boundaries.path <- paste0(boundaries.path, '/', add.to.path)
        if(file.exists(paste0(boundaries.path, '/', area.type, '.shp') ) ) 
            file.remove(paste0(boundaries.path, '/', area.type, '.', c('shp', 'prj', 'dbf', 'shx')))
        writeOGR(shp, dsn = boundaries.path, layer = area.type, driver = 'ESRI Shapefile')
    }
    if(return.shp) return(shp)
}

query.boundaries('OA', 'RGN', "'E12000007'", save.shp = TRUE, add.to.path = 'london')



library(leaflet)
shp.t %>% leaflet() %>% addTiles() %>% addPolygons()


data <- c(code = 1010010, type = 'OA')



### 5- Create loolkups for between child and parent from postcode -------------------------------------------------------------


# LOOUKPS OA TO LAU2 FOR NIE
library(data.table)
# read postcodes data
postcodes <- fread('D:/cloud/OneDrive/data/UK/geography/postcodes/ONSPD.csv', select = c('nuts', 'osgrdind', 'ctry', 'oa11') )
# keep only irish postcodes with valid coordinates
postcodes <- postcodes[osgrdind < 9 & ctry == 'N92000002']
#delete grid and country columns
postcodes[, `:=`(osgrdind = NULL, ctry = NULL)]
# extract exact lookups
y <- unique(postcodes[, .(oa11, pfa)])[, .N, oa11][N == 1][, oa11]
nie1 <- unique(postcodes[oa11 %in% y, .(oa11, pfa)])
# extract overlapping and associate each OA with the sector having more postcodes
y <- unique(postcodes[, .(oa11, pfa)])[, .N, oa11][N > 1][, oa11]
nie2 <- postcodes[oa11 %in% y][, .N, .(oa11, pfa)][order(oa11, -N)][, .SD[1], oa11][, .(oa11, pfa)]
# if you want to check the proportion of covered area:
postcodes[oa11 %in% y][, .N, .(oa11, pfa)][order(oa11, -N)][, pct := round(100 * N / sum(N), 2), oa11][, .(mp = max(pct)), oa11][order(-mp)]

nie <- rbindlist(list(nie1, nie2))
setnames(nie, c('OA', 'LAU2'))
write.csv(nie, 'D:/cloud/OneDrive/data/UK/geography/lookups/OA_to_LAU.csv', row.names = FALSE)



# LOOUKPS OA TO PFA for England only
library(data.table)
postcodes <- fread('D:/cloud/OneDrive/data/UK/geography/postcodes/ONSPD.csv', select = c('pfa', 'osgrdind', 'ctry', 'oa11') )
postcodes <- postcodes[osgrdind < 9 & ctry == 'E92000001']
postcodes[, `:=`(osgrdind = NULL, ctry = NULL)]
y <- unique(postcodes[, .(oa11, pfa)])[, .N, oa11][N == 1][, oa11]
y1 <- unique(postcodes[oa11 %in% y, .(oa11, pfa)])
y <- unique(postcodes[, .(oa11, pfa)])[, .N, oa11][N > 1][, oa11]
y2 <- postcodes[oa11 %in% y][, .N, .(oa11, pfa)][order(oa11, -N)][, .SD[1], oa11][, .(oa11, pfa)]
# if you want to check the proportion of covered area:
postcodes[oa11 %in% y][, .N, .(oa11, pfa)][order(oa11, -N)][, pct := round(100 * N / sum(N), 2), oa11][, .(mp = max(pct)), oa11][order(-mp)]

y <- rbindlist(list(y1, y2))
setnames(y, c('OA', 'PFA'))
write.csv(nie, 'D:/cloud/OneDrive/data/UK/geography/lookups/OA_to_PFA.csv', row.names = FALSE)



# LOOUKPS OA TO PCON
library(data.table)
postcodes <- fread('D:/cloud/OneDrive/data/UK/geography/postcodes/ONSPD.csv', select = c('pcon', 'osgrdind', 'oa11') )
postcodes <- postcodes[osgrdind < 9]
postcodes[, osgrdind := NULL]
y <- unique(postcodes[, .(oa11, pcon)])[, .N, oa11][N == 1][, oa11]
y1 <- unique(postcodes[oa11 %in% y, .(oa11, pcon)])
y <- unique(postcodes[, .(oa11, pcon)])[, .N, oa11][N > 1][, oa11]
y2 <- postcodes[oa11 %in% y][, .N, .(oa11, pcon)][order(oa11, -N)][, .SD[1], oa11][, .(oa11, pcon)]
yp <- postcodes[oa11 %in% y][, .N, .(oa11, pcon)][order(oa11, -N)][, pct := round(100 * N / sum(N), 2), oa11][, .(mp = max(pct)), oa11][order(-mp)]
y <- rbindlist(list(y1, y2))
setnames(y, c('OA', 'PCON'))
write.csv(y[order(OA)], 'D:/cloud/OneDrive/data/UK/geography/lookups/OA_to_PCON.csv', row.names = FALSE)












### 4- Calculate Length (perimeter), Area and (geometric) Centroids -------------------------------------------------------------

get.poly.measures <- function(shp, proj, holes = TRUE, cond = NULL){
    if(!is.null(cond)) shp <- subset(shp, eval(parse(text = cond) ) )
    xy <- as.data.frame(gCentroid(shp, byid = TRUE))
    shp <- spTransform(shp, CRS(proj))
    area <- as.data.frame(
        if(holes){
            sapply(shp@polygons, function(x) x@Polygons[[1]]@area)
        } else {
            gArea(shp, byid = TRUE)
        }
    )
    cbind( shp@data, xy, as.data.frame(gLength(shp, byid = TRUE)), area )
}

calc.measures <- function(area){
    library(RMySQL)
    library(rgdal)
    library(rgeos)
    my.path <- 
        if(substr(Sys.info()['sysname'], 1, 1) == 'W'){
            'D:/cloud/OneDrive/data/UK/geography/'
        } else {
            '/home/datamaps/data/UK/geography/'
        }
    boundaries.path <- paste0(my.path, 'boundaries/originals')
    data.path <- paste0(my.path, 'measures/')
    print(paste0('Loading boundaries...'))
    shp <- readOGR(boundaries.path, area)
    print(paste0('Loading lookups...'))
    db_conn <- dbConnect(MySQL(), group = 'local', dbname = 'geographyUK')
    lkp <- dbGetQuery(db_conn, paste('SELECT DISTINCT CTRY,', area, 'FROM lookups') )
    dbDisconnect(db_conn)
    print(paste0('Merging boundaries and lookups...'))
    shp@data <- merge(shp@data, lkp, by.x = 'id', by.y = area)
    print(paste0('Calculating measures...'))
    y <- rbind(
            get.poly.measures(shp, proj = '+init=epsg:27700', cond = "CTRY != 'N92000002'" ),  # ENG-SCO-WLS using British Grid
            get.poly.measures(shp, proj = '+init=epsg:29902', cond = "CTRY == 'N92000002'" )   # NIE using Irish Grid
    )
    y$CTRY <- NULL
    colnames(y) <- c('id', 'X_lon', 'Y_lat', 'perimeter', 'area')
    fn <- paste0(area, '_measures.csv')
    print(paste('Saving file', fn, 'to', data.path))
    write.csv(y[order(y$id),], paste0(data.path, area, '_measures.csv'), row.names = FALSE)
    print('Done!')
}
calc.measures('OA')

# Some area like Postcodes Sectors have polygons overlapping countries, resulting in duplications and errors when applying previous filters
y <- rbind(
        get.poly.measures(shp, proj = '+init=epsg:27700', cond = "CTRY != 'N92000002'" ),
        get.poly.measures(shp, proj = '+init=epsg:29902', cond = "CTRY == 'N92000002'" )
)



### 5- Associating points with polygons (given a POI coordinates, find the corresponding output area) ---------------------------

# read output areas (OA) boundaries
bnd <- readOGR(boundaries.path, 'OAsmp')

# read postcodes centroid
db_conn <- dbConnect(MySQL(), group = 'local', dbname = 'geographyUK')
postcodes <- data.table(dbGetQuery(db_conn, 'SELECT postcode, X_lon, Y_lat, OA FROM postcodes'), key = 'postcode')
dbDisconnect(db_conn)
# convert the postcodes dataframe to a spatial object with convenient projection
coordinates(postcodes) <- ~ X_lon + Y_lat  
proj4string(postcodes) <- proj4string(bnd)



### 8- Create Voronoi diagram (for postcodes areas?) ----------------------------------------------------------------------------



### 9- Convert SpatialPolygon to dataframe (for use in ggplot)
# Print a processing message
print(paste('Saving', area, 'in dataframe format'))
# save lookup (rmapshaperid, id) adding the area type
lkp <- shp.area@data
lkp$type <- area
colnames(lkp) <- c('boundary_id', 'id', 'type')
# connect to database
db_conn <- dbConnect(MySQL(), user = 'root', password = 'root', dbname = 'geography')
# save lookup to database
dbSendQuery(db_conn, paste0("DELETE FROM boundaries_ids WHERE type = '", area, "'") )
dbWriteTable(db_conn, 'boundaries_ids', lkp, row.names = FALSE, append = TRUE)
# close db connection
dbDisconnect(db_conn)
# create dataframe suitable for ggplot
df.area <- tidy(shp.area)
# change names in dataframe to coordinates to avoid possible mismatching with programming languages keywords
setnames(df.area, c('long', 'lat'), c('X_lon', 'Y_lat'))
# add "type" column
df.area$type <- area
# connect to database
db_conn <- dbConnect(MySQL(), user = 'root', password = 'root', dbname = 'geography')
# save dataframe to database
dbSendQuery(db_conn, paste0("DELETE FROM boundaries WHERE type = '", area, "'") )
dbWriteTable(db_conn, 'boundaries', df.area, row.names = FALSE, append = TRUE)
# close db connection
dbDisconnect(db_conn)






