###############################################################
# 11- UPRN
###############################################################
# download in data_path most recent zip file @ http://geoportal.statistics.gov.uk/datasets?q=ONS%20Address%20Directory&sort=-updatedAt  
# ===> be sure that's the only file in the directory! <=== 

### Load packages ---------------------------------------------------------------------------------------------------------------
pkg <- c('data.table', 'RMySQL')
pkg <- lapply(pkg, require, character.only = TRUE)

### Set variables ---------------------------------------------------------------------------------------------------------------
data_path <- 
    if (substr(Sys.info()['sysname'], 1, 1) == 'W') {
        'D:/cloud/OneDrive/data/UK/geography/uprn'
    } else {
        '/home/datamaps/data/UK/geography/uprn'
    }
dt <- data.table(OA = numeric(0), N = numeric(0))

### read filename and assign current_month variable -----------------------------------------------------------------------------
fn <- list.files(data_path)
current_month <- substr(fn, 7, 9)
current_month <- which(current_month == c('JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'))
current_month <- paste0(substr(fn, 13, 14), current_month)

### unzip file ------------------------------------------------------------------------------------------------------------------
unzip(file.path(data_path, fn), exdir = data_path)

### Loop through files: load OAs only, count records by OA, append to result dataaset -------------------------------------------
f_names <- dir(file.path(data_path, 'Data'), full.names = TRUE)
n_files <- length(f_names)
for(idx in 1:n_files){
    print(paste('Reading file', idx, 'out of', n_files))
    t <- fread(f_names[idx], select = 'oa11')
    dt <- rbindlist( list( dt, t[, .N, .(OA = oa11)]) )
}

### Save totals  ----------------------------------------------------------------------------------------------------------------
dbc <- dbConnect(MySQL(), group = 'dataOps', dbname = 'geography_uk')
dbSendQuery(dbc, "DROP TABLE IF EXISTS tmp")
dbWriteTable(dbc, 'tmp', dt, row.names = FALSE, append = TRUE)
dbSendQuery(dbc, "
    ALTER TABLE tmp
    	CHANGE COLUMN OA OA CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci' FIRST,
    	CHANGE COLUMN N N SMALLINT UNSIGNED NOT NULL AFTER OA,
    	ADD PRIMARY KEY (OA);
")
# as an update to lookups table
dbSendQuery(dbc, "UPDATE lookups SET tot_uprn = 0")
dbSendQuery(dbc, "UPDATE lookups lk JOIN tmp t ON t.OA = lk.OA SET lk.tot_uprn = t.N")
dbSendQuery(dbc, "UPDATE lookups SET tot_uprn = NULL WHERE CTRY = 'N92000002'")

# as an additional column in uprns 
strSQL <- paste0("
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = 'geography_uk' AND TABLE_NAME = 'uprns' AND COLUMN_NAME = 'D", current_month, "'"
)
sql_res <- unlist(dbGetQuery(dbc, strSQL))
if(sql_res) dbSendQuery(dbc, paste0("ALTER TABLE uprns DROP COLUMN D", current_month))
dbSendQuery(dbc, paste0("ALTER TABLE uprns ADD COLUMN D", current_month, " SMALLINT(5) UNSIGNED NULL DEFAULT NULL AFTER oa"))
dbSendQuery(dbc, paste0("UPDATE uprns u JOIN tmp t ON t.OA = u.OA SET u.D", current_month, " = t.N"))

# check totals by RGN/CTRY with Table 1 in the "ONSUD User Guide"
strSQL <- "
    SELECT lk.RGN, lc.name, SUM(tot_uprn) AS c
    FROM uprns u 
    	JOIN lookups lk ON lk.OA = u.oa
    	JOIN locations lc ON lc.location_id = lk.RGN AND lc.type_id = 'RGN'
    GROUP BY RGN
"
t <- dbGetQuery(dbc, strSQL)

# remove files from disk
unlink(file.path(data_path, '*'), recursive = TRUE)

### Clean & Exit ----------------------------------------------------------------------------------------------------------------
dbSendQuery(dbc, "DROP TABLE tmp")
dbDisconnect(dbc)
rm(list = ls())
gc()
