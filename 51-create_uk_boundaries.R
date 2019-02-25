#############################################################################
# UK GEOGRAPHY * 51 - BOUNDARIES: create unique UK file for output areas
#############################################################################

## Download the Output Areas (OA) boundaries for each country :
#   - EW: browse to [COA Boundaries](http://geoportal.statistics.gov.uk/datasets?q=COA%20Boundaries&sort_by=name) 
#     and download the *Generalised Clipped boundaries* full dataset shapefile (~50MB). 
#     The projection is [British National Grid, OSGB_1936](http://spatialreference.org/ref/epsg/osgb-1936-british-national-grid/)
ew_grid <- '+init=epsg:27700'
#   - SC: open [2011 Census Geography](http://www.nrscotland.gov.uk/statistics-and-data/geography/our-products/census-datasets/2011-census/2011-boundaries) 
#     and download the *2011 Output Area Boundaries, Extent of the Realm* zip file (~28MB). 
#     The projection is British National Grid, OSGB_1936
sc_grid = '+init=epsg:27700'
#   - NI: go to [NISRA Geography](https://www.nisra.gov.uk/publications/small-area-boundaries-gis-format)
#     and download the *ESRI Shapefile format* zip file (~25MB). 
#     The projection is [Irish Grid, GCS_TM65](http://spatialreference.org/ref/epsg/29902/)
ni_grid = '+init=epsg:29902' 
# set the coord ref system string for WGS84
crs.wgs <- '+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0'

## Extract from each archives only the files with the following extensions: 
#   - **shp** (geometry)
#   - **shx** (index)
#   - **prj** (projection)
#   - **dbf** (data). 
# Rename the three blocks as: **EW.xxx** (England and Wales), **SC.xxx** (Scotland), **NI.xxx** (Northern Ireland).

# Load the packages. On Linux (Ubuntu) install the following librearies: libproj-dev, libgdal-dev, libv8-dev 
pkg <- c('data.table', 'maptools', 'rgdal', 'rmapshaper', 'RMySQL')
invisible(lapply(pkg, require, char = TRUE))

# set the directory of the boundaries shapefiles. Do NOT end the path with "/" or the boundaries will fail to load! 
bnd_path <- file.path(Sys.getenv('PUB_PATH'), 'ext-data/geography_uk/boundaries')

## process English-Welsh
# read the shapefile
shp.ew <- readOGR(bnd_path, layer = 'EW')
# check the projection, and read the field to keep as future id; in this case: "oa11cd"
summary(shp.ew)
# transform the shapefile projection to WGS84 
shp.ew <- spTransform(shp.ew, CRS(crs.wgs))
# keep in the data slot only the ONS Output Area id, renaming it as 'id'
shp.ew <- shp.ew[, 'oa11cd']
colnames(shp.ew@data) <- c('id')
# reassign the polygon IDs
shp.ew <- spChFIDs(shp.ew, as.character(shp.ew$id))
# check the CRS has changed correctely, and the data slot has shrink to only the ID
summary(shp.ew)

# process SCotland (follows same steps as EW, see notes above)
shp.sc <- readOGR(bnd_path, layer = 'SC')
summary(shp.sc)
shp.sc <- spTransform(shp.sc, CRS(crs.wgs))
shp.sc <- shp.sc[, 'code']
colnames(shp.sc@data) <- c('id')
shp.sc <- spChFIDs(shp.sc, as.character(shp.sc$id))
summary(shp.sc)

# process Northern Ireland (follows same steps as EW, see notes above) 
shp.ni <- readOGR(bnd_path, layer = 'NI')
summary(shp.ni)
shp.ni <- spTransform(shp.ni, CRS(crs.wgs))
shp.ni <- shp.ni[, 'SA2011']
colnames(shp.ni@data) <- c('id')
shp.ni <- spChFIDs(shp.ni, as.character(shp.ni$id))
summary(shp.ni)

# Create the UK boundaries as a merge of all previous boundaries
shp.uk <- spRbind(spRbind(shp.ew, shp.sc), shp.ni)

# count by country:
table(substr(shp.uk@data$id, 1, 1))
# and it should return the following result (for 2011 census):  
# E 171,372, W 10,036 (EW: 181,408), S 46,351 (GB: 227,759), N 4,537 (UK: 232,296) 

# save Polygons as unique shapefile (in case, remove old shapefiles)
if(file.exists(file.path(bnd_path, 'UK.shp') ) ) 
    file.remove(paste0(bnd_path, '/UK.', c('shp', 'prj', 'dbf', 'shx')))
writeOGR(shp.uk, dsn = bnd_path, layer = 'UK', driver = 'ESRI Shapefile')

# reduce the complexity of the boundaries (it's a statistical map, not an OS Explorer Map!)
# unfortunately needs A LOT of memory (>32GB), and often has problems on Linux...
# shp.uk <- readOGR(bnd_path, layer = 'UK')
smp.uk <- ms_simplify(shp.uk, keep = 0.25)

# save new smaller polygons as OA for further aggregations and mapping
if(file.exists(file.path(bnd_path, 'OA.shp') ) ) 
    file.remove(paste0(bnd_path, '/OA.', c('shp', 'prj', 'dbf', 'shx')))
writeOGR(shp.uk, dsn = bnd_path, layer = 'OA', driver = 'ESRI Shapefile')

