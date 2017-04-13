###############################################################
# 50- WORK WITH BOUNDARIES (POLYGONS)
###############################################################

# The following demonstrate the use of R with geographic boundaries through the following:
# - union of the four UK 
# - different bigger areas

### 1- Load packages, Set variables ---------------------------------------------------------------------------------------------
pkg <- c('data.table', 'rgdal', 'RMySQL')
pkg <- lapply(pkg, require, character.only = TRUE)
boundaries.path <- 
    if(substr(Sys.info()['sysname'], 1, 1) == 'W'){
        'D:/cloud/OneDrive/data/UK/geography/postcodes/'
    } else {
        
    }

### 2- Load shapefiles, normalize projection, merge in one unique file ----------------------------------------------------------






### - CLEAN & EXIT -------------------------------------------------------------------------------------------------------------
dbDisconnect(db_conn)
rm(list = ls())
gc()
