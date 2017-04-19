###############################################################
# 40- WORK WITH LOCATIONS (POINTS)
###############################################################

# load packages
library(rgdal)
library(rgeos)

# set variables
boundaries.path <- 
    if(substr(Sys.info()['sysname'], 1, 1) == 'W'){
        'D:/cloud/OneDrive/data/UK/geography/boundaries'
    } else {
        '/home/datamaps/data/UK/geography/boundaries'
    }

# read base polygons from shapefile
shp.base <- readOGR(boundaries.path, layer = 'OA')
proj.wgs <- '+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0'



# Points in Polygons

