###############################################################
# 30- LOOKUPS
###############################################################

### 1- Load packages, Set variables ---------------------------------------------------------------------------------------------
pkg <- c('data.table', 'RMySQL')
pkg <- lapply(pkg, require, character.only = TRUE)
data.path <- 
    if(substr(Sys.info()['sysname'], 1, 1) == 'W'){
        'D:/cloud/OneDrive/data/UK/geography/postcodes/'
    } else {
        
    }

### 2- Load data ----------------------------------------------------------------------------------------------------------------
db_conn <- dbConnect(MySQL(), group = 'homeserver', dbname = 'geographyUK')



### - SAVE RESULTS -------------------------------------------------------------------------------------------------------------
dbSendQuery(db_conn, "TRUNCATE TABLE postcodes")
dbWriteTable(db_conn, 'postcodes', postcodes, row.names = FALSE, append = TRUE)


### - CLEAN & EXIT -------------------------------------------------------------------------------------------------------------
dbDisconnect(db_conn)
rm(list = ls())
gc()

