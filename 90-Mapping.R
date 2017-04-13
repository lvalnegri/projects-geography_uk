###############################################################
# 90- MAPPING: COMBINE SPATIAL OBJECTS AND DATA
###############################################################

### 1- Load packages, Set variables ---------------------------------------------------------------------------------------------
pkg <- c('data.table', 'ggplot', 'ggmap', 'ggspatial',  'leaflet', 'rgdal', 'RMySQL', 'sf', 'tmap')
pkg <- lapply(pkg, require, character.only = TRUE)
shp.path <- 
    if(substr(Sys.info()['sysname'], 1, 1) == 'W'){
        'D:/cloud/OneDrive/data/UK/geography/boundaries/ONS'
    } else {
        
    }

### 2- Load data ----------------------------------------------------------------------------------------------------------------
shp.bnd <- readOGR(shp.path, 'MTC')
shp.bnd <- spTransform(shp.bnd, CRS("+proj=longlat +datum=WGS84"))
plot(shp.bnd)
leaflet(shp.bnd) %>% addTiles() %>% addPolygons(fillColor = 'grey', weight = 2, opacity = 1, color = "white", dashArray = "3", fillOpacity = 0.7)

### - CLEAN & EXIT -------------------------------------------------------------------------------------------------------------
dbDisconnect(db_conn)
rm(list = ls())
gc()

