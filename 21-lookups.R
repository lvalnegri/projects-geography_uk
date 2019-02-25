###############################################################
# UK GEOGRAPHY * 21 - LOOKUPS
###############################################################

# load packages 
pkg <- c('data.table', 'fst', 'RMySQL')
invisible(lapply(pkg, require, character.only = TRUE))

# set constants 
data_path <- file.path(Sys.getenv('PUB_PATH'), 'dataframes/geography_uk')

# load data 
oas <- read.fst(file.path(data_path, 'output_areas'), as.data.table = TRUE)
dbc <- dbConnect(MySQL(), group = 'dataOps', dbname = 'geography_uk')
hrc <- data.table( dbGetQuery(dbc, "SELECT hierarchy_id, child_type, parent_type FROM hierarchies WHERE child_type <> 'OA'") )
dbDisconnect(dbc)

# loop over all hierarchies <> OA
lkps <- data.table(hierarchy_id = integer(0), child_id = character(0), parent_id = character(0))
for(idx in 1:nrow(hrc)){
    message('Processing hierachy ', hrc[idx, 2], ' to ', hrc[idx, 3])
    y <- unique(oas[, .( get(hrc[idx, child_type]), get(hrc[idx, parent_type]) ) ] )
    lkps <- rbindlist(list( lkps, data.table( hrc[idx, 1], y ) ))
}

# clean NAs
lkps <- lkps[!is.na(child_id)]
lkps <- lkps[!is.na(parent_id)]

# save to database
message('Saving to database...')
dbc <- dbConnect(MySQL(), group = 'dataOps', dbname = 'geography_uk')
dbSendQuery(dbc, "TRUNCATE TABLE lookups")
dbWriteTable(dbc, 'lookups', lkps, row.names = FALSE, append = TRUE)
dbDisconnect(dbc)

# recode all fields as factor, then save in fst format
message('Saving as fst...')
cols <- c('child_id', 'parent_id')
lkps[, (cols) := lapply(.SD, factor), .SDcols = cols]
write.fst(lkps, file.path(data_path, 'lookups'))

# clean and exit
message('DONE!')
rm(list = ls())
gc()
