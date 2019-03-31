#######################################################################
# UK GEOGRAPHY * 52 - Prepare UK shapefile for WPZs (workplace zones) #
#######################################################################

# load packages
pkgs <- c('rgdal')
lapply(pkgs, require, char = TRUE)

# set constants
in_path <- file.path(Sys.getenv('PUB_PATH'), 'ext_data', 'geography', 'uk', 'boundaries')
out_path <- file.path(Sys.getenv('PUB_PATH'), 'boundaries', 'uk', 'shp', 's00')
crs.wgs <- '+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0'

# load ONS boundaries
bnd <- readOGR(in_path, 'WPZ')
# check the projection, and read the field to keep as future id; in this case: "WZ11CD"
summary(bnd)
# transform the shapefile projection to WGS84 
bnd <- spTransform(bnd, CRS(crs.wgs))
# keep in the data slot only the ONS Output Area id, renaming it as 'id'
bnd <- bnd[, 'WZ11CD']
colnames(bnd@data) <- c('id')
# reassign the polygon IDs
bnd <- spChFIDs(bnd, as.character(bnd$id))
# check the CRS has changed correctely, and the data slot has shrink to only the ID
summary(bnd)
# count polygons by country:
table(substr(bnd@data$id, 1, 1))
# and it should return the following result (for 2011 census):  
# E 50,868, W 1,756 (EW: 52,624), S 5,375 (GB: 57,999), N 2,710 (UK: 60,709) 

# save to 's00' (in case, remove old shapefiles)
if(file.exists(file.path(out_path, 'WPZ.shp')))
    file.remove(paste0(out_path, '/WPZ.', c('shp', 'prj', 'dbf', 'shx')))
writeOGR(bnd, dsn = out_path, layer = 'WPZ', driver = 'ESRI Shapefile')

# clean env
rm(list = ls())
gc()
