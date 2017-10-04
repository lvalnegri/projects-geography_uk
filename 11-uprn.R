###############################################################
# 11- UPRN
###############################################################

### Load packages ---------------------------------------------------------------------------------------------------------------
pkg <- c('data.table', 'RMySQL')
pkg <- lapply(pkg, require, character.only = TRUE)

### Set variables ---------------------------------------------------------------------------------------------------------------
data.path <- 
    if (substr(Sys.info()['sysname'], 1, 1) == 'W') {
        'D:/cloud/OneDrive/data/UK/geography/postcodes'
    } else {
        '/home/datamaps/data/UK/geography/uprn'
    }
dt <- data.table(OA = numeric(0), N = numeric(0))

### Loop through files: load OAs only, count records by OA, append to result dataaset -------------------------------------------
f_names <- dir(data.path, full.names = TRUE)
n_files <- length(f_names)
for(idx in 1:n_files){
    print(paste('Reading file', idx, 'out of', n_files))
    t <- fread(f_names[idx], select = 'oa11')
    dt <- rbindlist( list( dt, t[, .N, .(OA = oa11)]) )
}

### Save as an update to lookups table in geography database --------------------------------------------------------------------
dbc <- dbConnect(MySQL(), group = 'dataOps', dbname = 'geography_uk')
dbSendQuery(dbc, "UPDATE lookups SET tot_uprn = 0")
dbSendQuery(dbc, "DROP TABLE IF EXISTS tmp")
dbWriteTable(dbc, 'tmp', dt, row.names = FALSE, append = TRUE)
dbSendQuery(dbc, "ALTER TABLE tmp ALTER N DROP DEFAULT")
dbSendQuery(dbc, "
    ALTER TABLE tmp
    	CHANGE COLUMN OA OA CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci' FIRST,
    	CHANGE COLUMN N N SMALLINT UNSIGNED NOT NULL AFTER OA,
    	ADD PRIMARY KEY (OA);
")
dbSendQuery(dbc, "UPDATE lookups lk JOIN tmp t ON t.OA = lk.OA SET lk.tot_uprn = t.N")
dbSendQuery(dbc, "UPDATE lookups SET tot_uprn = NULL WHERE CTRY = 'N92000002'")
dbSendQuery(dbc, "DROP TABLE tmp")
dbDisconnect(dbc)

### Clean & Exit ----------------------------------------------------------------------------------------------------------------
rm(list = ls())
gc()
