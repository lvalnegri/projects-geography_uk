#######################################
# UK GEOGRAPHY * 22 - Workplace Zones #
#######################################

# Preliminaries -----------------------------------------------------------------------------------------------------------------

# load packages 
pkg <- c('data.table', 'fst', 'RMySQL')
invisible(lapply(pkg, require, character.only = TRUE))

# set constants 
data_path <- file.path(Sys.getenv('PUB_PATH'), 'datasets', 'geography', 'uk')

# load WPZ ----------------------------------------------------------------------------------------------------------------------

# WPZ => MSOA for ENG-WLS-SCO
w1 <- fread(
        'https://opendata.arcgis.com/datasets/fde83309b6c14456846ca8fdece44a26_0.csv',
        select = c(1, 2, 4, 6),
        col.names = c('WPZ', 'wzc', 'MSOA', 'LAD'),
        na.strings = ''
)

# WPZ => LAD for NIE
w2 <- fread(
        'https://opendata.arcgis.com/datasets/3f780fd8fac24abaa69b15d4ceb67984_0.csv',
        select = c(1, 2, 4),
        col.names = c('WPZ', 'wzc', 'LAD'),
        na.strings = ''
)
w2[, MSOA := NA]
setcolorder(w2, c('WPZ', 'wzc', 'MSOA'))

# WPZ UK
wpz <- rbindlist(list( w1, w2 ))

# load other locations from oas -------------------------------------------------------------------------------------------------
oas <- read.fst(file.path(data_path, 'output_areas'), columns = c('LAD', 'CTY', 'RGN', 'CTRY'), as.data.table = TRUE)
oas <- unique(oas)
wpz <- oas[wpz, on = 'LAD'][order(WPZ)]
setcolorder(wpz, c('WPZ', 'wzc', 'MSOA'))

### save results in database ----------------------------------------------------------------------------------------------------------------
message('Save to database...')
dbc <- dbConnect(MySQL(), group = 'geouk')
dbSendQuery(dbc, "TRUNCATE TABLE workplace_zones")
dbWriteTable(dbc, 'workplace_zones', wpz, row.names = FALSE, append = TRUE)
dbDisconnect(dbc)

### recode all fields as factor, then save in fst format ------------------------------------------------------------------------------------
message('Save as fst...')
dbc <- dbConnect(MySQL(), group = 'geouk')
cols <- dbGetQuery(dbc, "SELECT * FROM workplace_zones LIMIT 0")
dbDisconnect(dbc)
cols <- intersect(names(cols), names(wpz))
setcolorder(wpz, cols)
wpz[, (cols) := lapply(.SD, factor), .SDcols = cols]
write.fst(wpz, file.path(data_path, 'workplace_zones'))

#### CLEAN AND EXIT ---------------------------------------------------------------------------------------------------------------------------------
message('DONE!')
rm(list = ls())
gc()
