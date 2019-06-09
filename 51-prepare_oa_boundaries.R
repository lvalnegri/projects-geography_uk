##############################################################
# UK GEOGRAPHY * 51 - Prepare UK file for OAs (output areas) #
##############################################################

## PREPARATION: Download the Output Areas (OA) boundaries for each country  -----------------------------------------------------
#   - EW: browse to [COA Boundaries](http://geoportal.statistics.gov.uk/datasets?q=COA%20Boundaries&sort_by=name) 
#     and download the *Generalised Clipped boundaries* full dataset shapefile (~50MB). 
#     The projection is [British National Grid, OSGB_1936](http://spatialreference.org/ref/epsg/osgb-1936-british-national-grid/)
#   - SC: open [2011 Census Geography](http://www.nrscotland.gov.uk/statistics-and-data/geography/our-products/census-datasets/2011-census/2011-boundaries) 
#     and download the *2011 Output Area Boundaries, Extent of the Realm* zip file (~28MB). 
#     The projection is British National Grid, OSGB_1936
#   - NI: go to [NISRA Geography](https://www.nisra.gov.uk/publications/small-area-boundaries-gis-format)
#     and download the *ESRI Shapefile format* zip file (~25MB). 
#     The projection is [Irish Grid, GCS_TM65](http://spatialreference.org/ref/epsg/29902/)
## Extract from each of the above archives only the files with the following extensions: 
#   - shp (geometry)
#   - shx (index)
#   - prj (projection)
#   - dbf (data). 
## Rename the three blocks as: **EW.xxx** (England and Wales), **SC.xxx** (Scotland), **NI.xxx** (Northern Ireland)
## Save files in <in_path>

# load packages ----------------------------------------------------------------------------------------------------------------
pkg <- c('data.table', 'fst', 'maptools', 'rgdal', 'rmapshaper')
invisible(lapply(pkg, require, char = TRUE))

# set constants -----------------------------------------------------------------------------------------------------------------
pub_path <- Sys.getenv('PUB_PATH')
in_path <- file.path(pub_path, 'ext_data', 'uk', 'geography', 'boundaries', 'OA')
out_path <- file.path(pub_path, 'boundaries', 'uk', 'shp')
ew_grid <- '+init=epsg:27700' # [British National Grid, OSGB_1936] 
sc_grid = '+init=epsg:27700'  # [British National Grid, OSGB_1936]
ni_grid = '+init=epsg:29902'  # [Irish Grid, GCS_TM65]
crs.wgs <- '+init=epsg:4326'  # [WGS84] also: '+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0'

# create unique UK boundary spatial object --------------------------------------------------------------------------------------

## English-Welsh

# read the shapefile
shp.ew <- readOGR(in_path, layer = 'EW')

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

## SCotland (follows same steps as EW, see notes above)
shp.sc <- readOGR(in_path, layer = 'SC')
summary(shp.sc)
shp.sc <- spTransform(shp.sc, CRS(crs.wgs))
shp.sc <- shp.sc[, 'code']
colnames(shp.sc@data) <- c('id')
shp.sc <- spChFIDs(shp.sc, as.character(shp.sc$id))
summary(shp.sc)

## Northern Ireland (follows same steps as EW, see notes above) 
shp.ni <- readOGR(in_path, layer = 'NI')
summary(shp.ni)
shp.ni <- spTransform(shp.ni, CRS(crs.wgs))
shp.ni <- shp.ni[, 'SA2011']
colnames(shp.ni@data) <- c('id')
shp.ni <- spChFIDs(shp.ni, as.character(shp.ni$id))
summary(shp.ni)

# Create the UK boundaries as a merge of all previous boundaries
shp.uk <- spRbind(spRbind(shp.ew, shp.sc), shp.ni)
rm(shp.ew, shp.ni, shp.sc)
gc()

# count by country:
table(substr(shp.uk@data$id, 1, 1))
# and it should return the following result (for 2011 census):  
# E 171,372, W 10,036 (EW: 181,408), S 46,351 (GB: 227,759), N 4,537 (UK: 232,296) 

# save polygons as shapefiles ---------------------------------------------------------------------------------------------------

# in original directory
if(file.exists(file.path(in_path, 'UK.shp'))) 
    file.remove(paste0(file.path(in_path, 'UK.'), c('shp', 'prj', 'dbf', 'shx')))
writeOGR(shp.uk, dsn = in_path, layer = 'UK', driver = 'ESRI Shapefile')

# in the s00 directory for further processing
if(file.exists(file.path(out_path, 's00', 'OA.shp'))) 
  file.remove(paste0(file.path(out_path, 's00', 'OA.'), c('shp', 'prj', 'dbf', 'shx')))
writeOGR(shp.uk, dsn = file.path(out_path, 's00'), layer = 'OA', driver = 'ESRI Shapefile')

# clean
rm(list = ls())
gc()

# reduce the complexity of the boundaries ---------------------------------------------------------------------------------------

library(sf)
library(fst)
library(dplyr)    
library(rmapshaper)
pub_path <- Sys.getenv('PUB_PATH')
bnd_path <- file.path(pub_path, 'boundaries', 'uk', 'shp')

message('Reading initial OA shapefile...')
shp.uk <- read_sf(file.path(pub_path, 'boundaries', 'uk', 'shp', 's00'), layer = 'OA')
rgn <- read.fst(
        file.path(pub_path, 'datasets', 'uk', 'geography', 'output_areas'), 
        columns = c('OA', 'RGN'), 
        as.data.table = TRUE
)

for(p in c('05', seq(10, 50, 10))){
    message('=============================================')
    message('Simplifying ', as.numeric(p), '% by region...')
    shp_area <- list()
    for(r in 1:length(levels(rgn$RGN))){
        message(' + Simplifying region ', levels(rgn$RGN)[r], '...')
        y <- shp.uk %>% 
              filter(id %in% rgn[RGN == levels(rgn$RGN)[r], OA]) %>% 
              ms_simplify(keep = as.numeric(p)/100, keep_shapes = TRUE)
        shp_area[[r]] <- y
    }
    message('Binding regions together...')
    shp_area <- do.call('rbind', shp_area)
    message('Saving...')
    bnd_ppath <- paste0(bnd_path, '/s', p)
    st_write(shp_area, paste0(file.path(bnd_ppath, 'OA'), '.shp'), delete_layer = TRUE)
}
message('=============================================')

message('Cleaning...')
rm(list = ls())
gc()
