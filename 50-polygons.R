###############################################################
# 50- WORK WITH BOUNDARIES (POLYGONS)
###############################################################

#### 1- Merge shapefiles: Output Areas from ENG, WLS, SCO, NIE into one unique file for UK --------------------------------------
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
boundaries.path <- '/path/to/shapefiles' # DO NOT insert the final backslash!!!
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

# save merged polygons as a unique shapefile. Ensure there are no such files in the given path
writeOGR(shp.uk, dsn = boundaries.path, layer = 'UK', driver = 'ESRI Shapefile')

# you could try to look at the result, but it takes a while...
plot(shp.uk)


#### 2- Output Area to Postcode Sectors, Districts, Areas -----------------------------------------------------------------------

# load packages
library(data.table)
library(rgdal)
library(rmapshaper)
library(maptools)
# set variables
boundaries.path <- 'D:/cloud/OneDrive/data/UK/geography/boundaries'     # DO NOT include the last backslash
data.path <- 'D:/cloud/OneDrive/data/UK/geography/lookups/'

area <- 'PCS'
# read base polygons from shapefile
shp.base <- readOGR(boundaries.path, layer = 'OA')
#  read lookups
lookups <- fread(paste0(data.path, 'OA_to_PCS.csv'))
# join shapefile data slot and lookup table on the area code 
shp.base <- merge(shp.base, lookups[, .(OA, area = get(area))], by.x = 'id', by.y = 'OA')
# Build the list of subareas 
subareas <- sort(unique(shp.base[['area']]))
# Define first area
subarea <- subareas[1]
# Print a processing message
print(paste('Processing', area, 'subarea', subarea, '- number 1 out of', length(subareas)))
# select all OA contained in first subarea
shp.area <- subset(shp.base, shp.base[['area']] == subarea)
# dissolve submap
shp.area <- ms_dissolve(shp.area)
# define object id
shp.area$id <- subarea
shp.area <- spChFIDs(shp.area, as.character(shp.area$id))
# proceed in the same way for all other subareas, attaching every results to previous object
for(idx in 2:length(subareas)){
    subarea <- subareas[idx]
    print(paste('Processing', area, 'subarea', subarea, '- number', idx, 'out of', length(subareas)))
    shp.tmp <- subset(shp.base, shp.base[['area']] == subarea)
    shp.tmp <- ms_dissolve(shp.tmp)
    shp.tmp$id <- subarea
    shp.tmp <- spChFIDs(shp.tmp, as.character(shp.tmp$id))
    shp.area <- spRbind(shp.area, shp.tmp)
}
# reduce the details of the boundaries
shp.area <- ms_simplify(shp.area, keep = 0.05)
# delete the rmapshaperid from Polygons
shp.area <- shp.area[, 'id']
# save Polygons as shapefile
writeOGR(shp.area, dsn = boundaries.path, layer = area, driver = 'ESRI Shapefile')


get.bnd.subarea <- function(subarea) {
  # select all base areas contained in subarea
  shp.tmp <- subset(shp.base, shp.base[['area']] == subarea)
  # dissolve submap
  shp.tmp <- ms_dissolve(shp.tmp)
  # define object id
  shp.tmp$id <- subarea
  shp.tmp <- spChFIDs(shp.tmp, as.character(shp.tmp$id))
  return(shp.tmp)
}



### CONVERT SHAPEFILE TO DATAFRAME FORMAT (for use in ggplot)
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






### - Associating points with polygons. case Study: given the postcodes' centroids, find the corresponding output area

# read output areas (OA) boundaries
bnd <- readOGR(boundaries.path, 'OAsmp')

# read postcodes centroid
db_conn <- dbConnect(MySQL(), group = 'local', dbname = 'geographyUK')
postcodes <- data.table(dbGetQuery(db_conn, 'SELECT postcode, X_lon, Y_lat, OA FROM postcodes'), key = 'postcode')
dbDisconnect(db_conn)
# convert the postcodes dataframe to a spatial object with convenient projection
coordinates(postcodes) <- ~ X_lon + Y_lat  
proj4string(postcodes) <- proj4string(bnd)

### Create Voronoi boundaries for postcodes Case Study

