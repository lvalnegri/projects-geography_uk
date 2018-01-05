###############################################################
# 50- WORK WITH BOUNDARIES (POLYGONS)
###############################################################

### 1- Blend Output Areas from England and Wales (EW), Scotland (SC), Northern Ireland (NI) into one unique file for the UK as a whole --------------------------------------

## Download the Output Areas (OA) boundaries for each country :
#   - EW: browse to [COA Boundaries](http://geoportal.statistics.gov.uk/datasets?q=COA%20Boundaries&sort_by=name) 
#     and download the *Generalised Clipped boundaries* full dataset shapefile (~50MB). 
#     The projection is [British National Grid, OSGB_1936](http://spatialreference.org/ref/epsg/osgb-1936-british-national-grid/)
ew_grid <- '+init=epsg:27700'
#     The bounding box is [, , , ]. The centroid is [, ]
ew_bbox <- c(, , , )
ew_centroid <- c(x_lon = , y_lat = )
#   - SC: open [2011 Census Geography](http://www.nrscotland.gov.uk/statistics-and-data/geography/our-products/census-datasets/2011-census/2011-boundaries) 
#     and download the *2011 Output Area Boundaries, Extent of the Realm* zip file (~28MB). 
#     The projection is British National Grid, OSGB_1936
sc_grid = '+init=epsg:27700'
#     The bounding box is [, , , ]. The centroid is [, ]
sc_bbox <- c(, , , )
sc_centroid <- c(x_lon = , y_lat = )
#   - NI: go to [NISRA Geography](https://www.nisra.gov.uk/publications/small-area-boundaries-gis-format)
#     and download the *ESRI Shapefile format* zip file (~25MB). 
#     The projection is [Irish Grid, GCS_TM65](http://spatialreference.org/ref/epsg/29902/)
ni_grid = '+init=epsg:29902' 
#     The bounding box is [, , , ]. The centroid is [, ]
ni_bbox <- c(, , , )
ni_centroid <- c(x_lon = , y_lat = )

## Extract from each archives only the files with the following extensions: 
#   - **shp** (geometry)
#   - **shx** (index)
#   - **prj** (projection)
#   - **dbf** (data). 
# Rename the three blocks as: **EW.xxx** (England and Wales), **SC.xxx** (Scotland), **NI.xxx** (Northern Ireland).

# Load the packages. On Linux (Ubuntu) install the following librearies: libproj-dev, libgdal-dev, libv8-dev 
pkg <- c('maptools', 'rgdal', 'rmapshaper')
invisible(lapply(pkg, require, char = TRUE))

# set the directory of the boundaries shapefiles. Do NOT end the path with "/" or the boundaries will fail to load! 
boundaries.path <- 
    if(substr(Sys.info()['sysname'], 1, 1) == 'W'){
        'D:/cloud/OneDrive/data/UK/geography/boundaries'  # Windows
    } else {
        '/home/datamaps/data/UK/geography/boundaries'     # Linux
    }

# set the correct projection string for WGS84
proj.wgs <- '+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0'

## process English-Welsh
# read the shapefile
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

# process SCotland (follows same steps as EW, see notes above)
shp.sc <- readOGR(boundaries.path, layer = 'SC')
summary(shp.sc)
shp.sc <- spTransform(shp.sc, CRS(proj.wgs))
shp.sc <- shp.sc[, 'code']
colnames(shp.sc@data) <- c('id')
shp.sc <- spChFIDs(shp.sc, as.character(shp.sc$id))

# process Northern Ireland (follows same steps as EW, see notes above) 
shp.ni <- readOGR(boundaries.path, layer = 'NI')
summary(shp.ni)
shp.ni <- spTransform(shp.ni, CRS(proj.wgs))
shp.ni <- shp.ni[, 'SA2011']
colnames(shp.ni@data) <- c('id')
shp.ni <- spChFIDs(shp.ni, as.character(shp.ni$id))

# Create the UK boundaries as a merge of all previous boundaries
shp.uk <- spRbind(spRbind(shp.ew, shp.sc), shp.ni)
# reduce the complexity of the boundaries (it's a statistical map, not an OS Explorer Map!)
shp.uk <- ms_simplify(shp.uk, keep = 0.05)

# count by country:
table(substr(shp.uk@data$id, 1, 1))
# and it should return the following result (for 2011 census):  
# E 171,372, W 10,036 (EW: 181,408), S 46,351 (GB: 227,759), N 4,537 (UK: 232,296) 
uk_centroid <- c(x_lon = -2.421976, y_lat = 53.825564)
uk_bbox <- c(lng1 = 1.8, lat1 = 49.9, lng2 = -8.3, lat2 = 59.0 )

# save Polygons as unique shapefile (in case, remove old shapefiles)
if(file.exists(paste0(boundaries.path, '/OA.shp') ) ) 
    file.remove(paste0(boundaries.path, '/OA.', c('shp', 'prj', 'dbf', 'shx')))
writeOGR(shp.area, dsn = boundaries.path, layer = 'OA', driver = 'ESRI Shapefile')


### 2- Merge polygons from OA shapefile to create a boundary shapefile for a parent level ---------------------------------------------------------
# a functional "lookups" table is supposed to exists in the geography database

# load packages
pkg <- c('maptools', 'rgdal', 'rmapshaper', 'RMySQL')
invisible(lapply(pkg, require, char = TRUE))

# set the directory of the boundaries shapefiles. Do NOT end the path with "/" or the boundaries will fail to load! 
boundaries.path <- 
    if(substr(Sys.info()['sysname'], 1, 1) == 'W'){
        'D:/cloud/OneDrive/data/UK/geography/boundaries'  # Windows
    } else {
        '/home/datamaps/data/UK/geography/boundaries'     # Linux
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

# create boundaries for the "" hierarchy
build.parent.boundaries('LSOA', 'OA', TRUE)
build.parent.boundaries('MSOA', 'LSOA')
build.parent.boundaries('LAD', 'MSOA')
build.parent.boundaries('CTY', 'LAD')
build.parent.boundaries('RGN', 'CTY')
build.parent.boundaries('CTRY', 'RGN')

# create boundaries for the "" hierarchy

# create boundaries for the "" hierarchy

# create boundaries for the "postcodes" hierarchy
build.parent.boundaries('PCS', 'OA', TRUE)
build.parent.boundaries('PCD', 'PCS')
build.parent.boundaries('PCA', 'PCD')

# create boundaries for the "Health" hierarchy


### 4- Query boundaries for a specified parent area

# load packages
library(RMySQL)
library(rgdal)
library(rmapshaper)

# define helper functions
query.boundaries <- function(
                        area.type, parent.type, parent.ids, 
                        simplify = FALSE, save.shp = FALSE, return.shp = TRUE, 
                        add.to.path = NA
){
    boundaries.path <-
        if(substr(Sys.info()['sysname'], 1, 1) == 'W'){
            'D:/cloud/OneDrive/data/UK/geography/boundaries'
        } else {
            '/home/datamaps/data/UK/geography/boundaries'
        }
    # load boundaries shapefile
    shp <- readOGR(boundaries.path, layer = area.type)
    # load lookup for child codes included in chosen parent area
    db_conn <- dbConnect(MySQL(), group = 'local', dbname = 'geographyUK')
    lkp <- dbGetQuery(db_conn, paste0('SELECT DISTINCT ', area.type, ' FROM lookups WHERE ', parent.type, ' IN (', parent.ids, ')' ))
    dbDisconnect(db_conn)
    # filter children polygons included in parent
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



### 5- Associating points with polygons (given a POI coordinates, find the corresponding polygon (or OA id, you can get whatever else using lookups) ---------------------------

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
db_conn <- dbConnect(MySQL(), group = 'local', dbname = 'geography')
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
db_conn <- dbConnect(MySQL(), group = 'local', dbname = 'geography')
# save dataframe to database
dbSendQuery(db_conn, paste0("DELETE FROM boundaries WHERE type = '", area, "'") )
dbWriteTable(db_conn, 'boundaries', df.area, row.names = FALSE, append = TRUE)
# close db connection
dbDisconnect(db_conn)






