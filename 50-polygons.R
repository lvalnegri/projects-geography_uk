###############################################################
# 50- WORK WITH BOUNDARIES (POLYGONS)
###############################################################

### 1- Load packages, Set variables ---------------------------------------------------------------------------------------------
pkg <- c('data.table', 'rgdal', 'RMySQL')
pkg <- lapply(pkg, require, character.only = TRUE)
data.path <- 
    if(substr(Sys.info()['sysname'], 1, 1) == 'W'){
        'D:/cloud/OneDrive/data/UK/geography/postcodes/'
    } else {
        
    }

### 2- Load data ----------------------------------------------------------------------------------------------------------------
db_conn <- dbConnect(MySQL(), group = 'homeserver', dbname = 'geographyUK')
strSQL = "
"
dataset <- data.table(dbGetQuery(db_conn, strSQL), key = '')
dataset <- data.table(dbReadTable(db_conn, 'postcodes'), key = '')


### - CLEAN & EXIT -------------------------------------------------------------------------------------------------------------
dbDisconnect(db_conn)
rm(list = ls())
gc()

