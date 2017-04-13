###############################################################
# 20- LOCATIONS
###############################################################

### 1- Load packages, Set variables ---------------------------------------------------------------------------------------------
pkg <- c('data.table', 'RMySQL')
pkg <- lapply(pkg, require, character.only = TRUE)

### 2- Load data ----------------------------------------------------------------------------------------------------------------
db_conn <- dbConnect(MySQL(), group = 'homeserver', dbname = 'geographyUK')
postcodes <- data.table(dbReadTable(db_conn, 'postcodes'))
dbDisconnect(db_conn)

dt <- postcodes[, -(1:5), with = FALSE]
unique(dt[, .(OA, CTRY)])[, .N, CTRY]
# there is a total of 265 OAs missing, 36 from ENG and 229 from SCO
write.csv(dt[, .N, OA][order(OA)], 'temp_OA.csv', row.names = FALSE)

unique(dt[, .(OA, LSOA)])[, .N, OA][N > 1]
unique(dt[, .(OA, MSOA)])[, .N, OA][N > 1]
unique(dt[, .(MSOA, LAD)])[, .N, MSOA][N > 1]
unique(dt[, .(LSOA, CTRY)])[, .N, CTRY]
unique(dt[, .(MSOA, CTRY)])[, .N, CTRY]
unique(dt[, .(LAD, CTRY)])[, .N, CTRY]
unique(dt[, .(CTY, CTRY)])[, .N, CTRY]
unique(dt[substr(CTY, 1, 2) != 'E9', .(CTY, CTRY)])[, .N, CTRY]
dt[CTY == 'E99999999', .(CTY, RGN, paste0('E9999991', substr(RGN, 9, 9) ) ) ][, .N, V3]
dt[CTY == 'E99999999', CTY := paste0('E9999991', substr(RGN, 9, 9) ) ]
write.csv(unique(dt[, .(LSOA, CTY)])[order(LSOA)], 'temp_OA.csv', row.names = FALSE)
# OA %in% c('E00005337', 'E00003159') have problems with LAD, RGN, WARD, PCON, ...
unique(dt[, .(RGN, CTRY)])[, .N, CTRY]



### - SAVE RESULTS -------------------------------------------------------------------------------------------------------------
dbSendQuery(db_conn, "TRUNCATE TABLE postcodes")
dbWriteTable(db_conn, 'postcodes', postcodes, row.names = FALSE, append = TRUE)


### - CLEAN & EXIT -------------------------------------------------------------------------------------------------------------
dbDisconnect(db_conn)
rm(list = ls())
gc()

