#######################################################################
# UK GEOGRAPHY * 53 - Prepare UK shapefile for WPZs (workplace zones) #
#######################################################################

# load packages ----------------------------------------------------------------------------------------------------------------
pkg <- c('data.table', 'fst', 'maptools', 'rgdal', 'rmapshaper')
invisible(lapply(pkg, require, char = TRUE))

# set constants -----------------------------------------------------------------------------------------------------------------
pub_path <- Sys.getenv('PUB_PATH')
in_path <- file.path(pub_path, 'ext_data', 'uk', 'geography', 'boundaries', 'WPZ')
out_path <- file.path(pub_path, 'boundaries', 'uk', 'shp')
ew_grid <- '+init=epsg:27700' # [British National Grid, OSGB_1936] 
sc_grid = '+init=epsg:27700'  # [British National Grid, OSGB_1936]
ni_grid = '+init=epsg:29902'  # [Irish Grid, GCS_TM65]
crs.wgs <- '+init=epsg:4326'  # [WGS84] also: '+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0'

# create unique UK boundary spatial object --------------------------------------------------------------------------------------

## English-Welsh

# read the shapefile
shp.ew <- readOGR(in_path, layer = 'EW')

# check the projection, and read the field to keep as future id
summary(shp.ew)

# transform the shapefile projection to WGS84 
shp.ew <- spTransform(shp.ew, CRS(crs.wgs))

# keep in the data slot only the ONS WorkPlace Zone id, renaming it as 'id'
shp.ew <- shp.ew[, 'wz11cd']
colnames(shp.ew@data) <- c('id')

# reassign the polygon IDs
shp.ew <- spChFIDs(shp.ew, as.character(shp.ew$id))

# check the CRS has changed correctely, and the data slot has shrink to only the ID
summary(shp.ew)

## SCotland (follows same steps as EW, see notes above)
shp.sc <- readOGR(in_path, layer = 'SC')
summary(shp.sc)
shp.sc <- spTransform(shp.sc, CRS(crs.wgs))
shp.sc <- shp.sc[, 'WZCD']
colnames(shp.sc@data) <- c('id')
shp.sc <- spChFIDs(shp.sc, as.character(shp.sc$id))
summary(shp.sc)

## Northern Ireland (follows same steps as EW, see notes above) 
shp.ni <- readOGR(in_path, layer = 'NI')
summary(shp.ni)
shp.ni <- spTransform(shp.ni, CRS(crs.wgs))
shp.ni <- shp.ni[, 'CD']
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
# E 50,868, W 2,710 (EW: 53,578), S 5,375 (GB: 58,953), N 1,756 (UK: 60,709) 

# save polygons as shapefiles ---------------------------------------------------------------------------------------------------

# in original directory
if(file.exists(file.path(in_path, 'UK.shp') ) ) 
    file.remove(paste0(in_path, '/UK.', c('shp', 'prj', 'dbf', 'shx')))
writeOGR(shp.uk, dsn = in_path, layer = 'UK', driver = 'ESRI Shapefile')

# in the s00 directory for further processing
if(file.exists(file.path(out_path, 's00', 'WPZ.shp') ) ) 
  file.remove(paste0(file.path(out_path, 's00', 'WPZ'), '.', c('shp', 'prj', 'dbf', 'shx')))
writeOGR(shp.uk, dsn = file.path(out_path, 's00'), layer = 'WPZ', driver = 'ESRI Shapefile')

# clean
rm(list = ls())
gc()



# reduce the complexity of the boundaries ---------------------------------------------------------------------------------------

library(sf)
library(fst)
library(dplyr)    
library(rmapshaper)
library(parallel)
pub_path <- Sys.getenv('PUB_PATH')
bnd_path <- file.path(pub_path, 'boundaries', 'uk', 'shp')

message('Reading initial WPZ shapefile...')
shp.uk <- read_sf(file.path(pub_path, 'boundaries', 'uk', 'shp', 's00'), layer = 'WPZ')

rgn <- read.fst(
        file.path(pub_path, 'datasets', 'uk', 'geography', 'workplace_zones'), 
        columns = c('WPZ', 'RGN'), 
        as.data.table = TRUE
)

for(p in c('05', seq(10, 50, 10))){
    message('=============================================')
    message('Simplifying ', as.numeric(p), '% by region...')
    y <- mclapply(
                levels(rgn$RGN), 
                function(x)
                    shp.uk %>% 
                      filter(id %in% rgn[RGN == x, WPZ]) %>% 
                      ms_simplify(keep = as.numeric(p)/100, keep_shapes = TRUE),
                mc.cores = detectCores(logical = FALSE)
    )
    message('Binding regions together...')
    y <- do.call('rbind', y)
    message('Saving...')
    bnd_ppath <- paste0(bnd_path, '/s', p)
    st_write(y, paste0(file.path(bnd_ppath, 'WPZ'), '.shp'), delete_layer = TRUE)
}
message('=============================================')

message('Cleaning...')
rm(list = ls())
gc()
