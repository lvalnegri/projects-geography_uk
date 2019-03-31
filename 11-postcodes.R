###############################################################
# UK GEOGRAPHY * 10 - POSTCODES 
###############################################################
# You need to provide the following CSV in in_path:
#  - ONSPD
#  - NHSPD
#  - postcodes_mosaics
# You need to provide the following CSV in out_path_lc:
#  - NHSO.csv
#  - NHSR.csv

### load packages -----------------------------------------------------------------------------------------------------------------------------------
pkg <- c('data.table', 'fst', 'RMySQL')
invisible(lapply(pkg, require, character.only = TRUE))

### set constants -----------------------------------------------------------------------------------------------------------------------------------
pub_path <- Sys.getenv('PUB_PATH')
in_path <- file.path(pub_path, 'ext_data', 'geography', 'uk', 'postcodes')
out_path_lc <- file.path(pub_path, 'ext_data', 'geography', 'uk', 'locations')
out_path_pc <- file.path(pub_path, 'datasets', 'geography', 'uk')

### define functions --------------------------------------------------------------------------------------------------------------------------------
get_csv <- function(furl, cols, coln, headr = TRUE, nas = ''){
    tmp <- tempfile()
    message('Downloading file...')
    download.file(furl, tmp)
    message('Unzipping file...')
    unzip(tmp, exdir = 'tmpdir')
    y <- dir('tmpdir', recursive = TRUE, full.names = TRUE)
    message('Reading csv file...')
    y <- fread(y[which.max(file.size(y))], header = headr, select = cols, col.names = coln, na.string = nas)
    message('Done!')
    unlink(tmp)
    unlink('tmpdir', recursive = TRUE)
    y
}

### LOAD ONSPD -----------------------------------------------------------------------------------------------------------------------------------
# download latest @ http://geoportal.statistics.gov.uk/datasets?q=ONS+Postcode+Directory+(ONSPD)+zip&sort_by=updated_at
# Extract big file from *Data* directory 'ONSPD_MMM_YYYY_UK.csv' and copy it to <in_path> as 'ONSPD.csv'
# load data
postcodes <- fread(
    file.path(in_path, 'ONSPD.csv'), 
    select = c(
       'pcd', 'osgrdind', 'doterm', 'usertype', 'long', 'lat', 
       'oa11', 'lsoa11', 'msoa11', 'oslaua', 'oscty', 'rgn', 'ctry',
       'ttwa', 'osward', 'pcon', 'ced', 'parish', 'bua11', 'buasd11', 'wz11',
       'pfa', 'ccg', 'stp'
    ),
    col.names = c(
        'postcode', 'osgrdind', 'is_active', 'usertype', 'x_lon', 'y_lat',
        'OA', 'LSOA', 'MSOA', 'LAD', 'CTY', 'RGN', 'CTRY', 
        'TTWA', 'WARD', 'PCON', 'CED', 'PAR', 'BUA', 'BUAS', 'WPZ', 'PFA', 'CCG', 'STP'
    ),
    na.string = ''
)
# check url for latest file @ http://geoportal.statistics.gov.uk/datasets?q=ONS+Postcode+Directory+(ONSPD)+zip&sort_by=updated_at
# postcodes <- get_csv(
#         'https://www.arcgis.com/sharing/rest/content/items/abd42fce1e944431b4f24881b5bb048d/data',
#         c(
#            'pcd', 'osgrdind', 'doterm', 'usertype', 'long', 'lat', 
#            'oa11', 'lsoa11', 'msoa11', 'oslaua', 'oscty', 'rgn', 'ctry',
#            'ttwa', 'osward', 'pcon', 'ced', 'parish', 'bua11', 'buasd11', 'wz11',
#            'pfa', 'ccg', 'stp'
#         ),
#         c(
#             'postcode', 'osgrdind', 'is_active', 'usertype', 'x_lon', 'y_lat',
#             'OA', 'LSOA', 'MSOA', 'LAD', 'CTY', 'RGN', 'CTRY', 
#             'TTWA', 'WARD', 'PCON', 'CED', 'PAR', 'BUA', 'BUAS', 'WPZ', 'PFA', 'CCG', 'STP'
#         )
# )

## CHECK TOTALS ==> Table 1
postcodes[, .N, CTRY][order(CTRY)]                                  # TOTAL
postcodes[!(CTRY %in% c('L93000001', 'M83000003')), .N]             # Total UK
postcodes[, .N, usertype][order(usertype)]                          # 0-Small / 1-Large users, TOTAL
postcodes[!(CTRY %in% c('L93000001', 'M83000003')), .N, usertype]   # usertype TOTAL UK
dcast.data.table(postcodes[, .N, .(CTRY, usertype)][order(CTRY, usertype)], CTRY~usertype)  # Countries by usertype
## CHECK TOTALS ==> Table 3
postcodes[osgrdind < 9, .N, CTRY][order(CTRY)]
dcast.data.table(postcodes[osgrdind < 9, .N, .(CTRY, usertype)][order(CTRY, usertype)], CTRY~usertype)

# eliminates postcodes without grid reference (osgrdind == 9, deletes also GI/IM), then reorder by OA and postcode
postcodes <- postcodes[osgrdind < 9][, osgrdind := NULL][order(OA, postcode)]

# recode is_active as binary
postcodes[, is_active := ifelse(is.na(is_active), 1, 0)]

### ADD Postcode Areas, Districts, Sectors -------------------------------------------------------------------------------------------------------
postcodes[, PCA := sub('[0-9]', '', substr(postcode, 1, gregexpr("[[:digit:]]", postcode)[[1]][1] - 1) ) ]
postcodes[, PCD := gsub(' .*', '', substr(postcode, 1, 4)) ]
postcodes[, PCS := substr(postcode, 1, 5) ]

# order postcode districts
pcd <- unique(postcodes[is_active & !postcode %in% postcodes[grep('^[A-Z]{3}', postcode), postcode], .(PCD)])
pcd[, `:=`( PCDa = regmatches(pcd$PCD, regexpr('[a-zA-Z]+', pcd$PCD)), PCDn = as.numeric(regmatches(pcd$PCD, regexpr('[0-9]+', pcd$PCD))) )]
pcd <- pcd[order(PCDa, PCDn)][, ordering := 1:.N][, .(PCD, ordering)]
fwrite(pcd, file.path(out_path_lc, 'PCD.csv'), row.names = FALSE)

# order postcode sectors 
pcs <- unique(postcodes[is_active & !postcode %in% postcodes[grep('^[A-Z]{3}', postcode), postcode], .(PCD, PCS)])
pcs <- pcs[pcd, on = 'PCD']
pcs <- pcs[order(ordering, PCS)][, ordering := 1:.N][, .(PCS, ordering)]
fwrite(pcs, file.path(out_path_lc, 'PCS.csv'), row.names = FALSE)

# check and save total Table 2 (remember that now postcodes without grid have been deleted)
pca <- rbindlist(list(
    postcodes[, .(PCD = uniqueN(PCD), PCS = uniqueN(PCS), live = sum(is_active), terminated = sum(!is_active), total = .N), PCA][order(PCA)],
    postcodes[, .(PCA = 'TOTAL UK', PCD = uniqueN(PCD), PCS = uniqueN(PCS), live = sum(is_active), terminated = sum(!is_active), total = .N)]        
))
fwrite(pca, file.path(in_path, 'pca_totals.csv'), row.names = FALSE)

# change pseudo-codes to NA
cols <- c('MSOA', 'CTY', 'RGN', 'CED', 'PAR', 'BUA', 'BUAS', 'PFA', 'STP')
postcodes[,
    (cols) := lapply(.SD, function(x)
        ifelse( x %in% c('E99999999', 'N99999999', 'S99999999', 'W99999999', 'E34999999', 'W37999999', 'E35999999', 'W38999999'), NA, x)
    ),
    .SDcols = cols
]

### LOAD NHSPD -----------------------------------------------------------------------------------------------------------------------------------
# download latest @ http://geoportal.statistics.gov.uk/search?q=NHS%20Postcode%20Directory%20UK%20Full
# Extract big file from *Data* directory 'nhgYYmmm.csv' and copy it to <in_path> as 'NHSPD.csv'
# load data
nhspd <- fread( 
    file.path(in_path, 'NHSPD.csv'), 
    header = FALSE,
    select = c(1, 12, 17, 24), 
    col.names = c('postcode', 'osgrdind', 'nhsr', 'nhso'), 
    na.string = ''
)

# check url for latest file @ http://geoportal.statistics.gov.uk/search?q=NHS%20Postcode%20Directory%20UK%20Full
# nhspd <- get_csv( 
#     'https://www.arcgis.com/sharing/rest/content/items/e1dc68a2c7f64adeb834bd089bd87ca5/data', 
#     c(1, 12, 17, 24), 
#     c('postcode', 'osgrdind', 'nhsr', 'nhso'), 
#     headr = FALSE
# )

# delete non-geographic
nhspd <- nhspd[osgrdind < 9][, osgrdind := NULL]
# recode postcode in 7-chars form
nhspd[, postcode := paste0(substr(postcode, 1, 4), substring(postcode, 6))]
# load NHSO names to change codes from NHS to ONS
y <- fread(file.path(out_path_lc, 'NHSO.csv'), select = 1:2, col.names = c('NHSO', 'nhso'))
nhspd <- y[nhspd, on = 'nhso'][, nhso := NULL]
# load NHSR names to change codes from NHS to ONS
y <- fread(file.path(out_path_lc, 'NHSR.csv'), select = 1:2, col.names = c('NHSR', 'nhsr'))
nhspd <- y[nhspd, on = 'nhsr'][, nhsr := NULL]
# join with postcodes
postcodes <- nhspd[postcodes, on = 'postcode']

### add mosaic types --------------------------------------------------------------------------------------------------------------------------------
mosaics <- fread(file.path(in_path, 'postcodes_mosaics.csv'))
y <- read.fst(file.path(out_path_pc, 'mosaic_types'), columns = c('code_exp', 'code'), as.data.table = TRUE)
mosaics <- y[mosaics, on = c(code_exp = 'mosaic_type')]
postcodes <- mosaics[, .(postcode, mosaic_type = code)][postcodes, on = 'postcode']

### save results in database ------------------------------------------------------------------------------------------------------------------------
dbc <- dbConnect(MySQL(), group = 'geouk')
dbSendQuery(dbc, "TRUNCATE TABLE postcodes")
dbWriteTable(dbc, 'postcodes', postcodes, row.names = FALSE, append = TRUE)
pn <- dbGetQuery(dbc, 'SELECT * FROM postcodes LIMIT 0')
dbDisconnect(dbc)
setcolorder(postcodes, intersect(names(pn), names(postcodes)))

### recode as factors, then save results in fst format ----------------------------------------------------------------------------------------------
cols <- colnames(postcodes)
cols <- cols[which(names(postcodes) == 'OA'):length(cols)]
postcodes[, (cols) := lapply(.SD, factor), .SDcols = cols]
write.fst(postcodes, file.path(out_path_pc, 'postcodes'))

### SAVE IMD, OAC, RUC ------------------------------------------------------------------------------------------------------------------------------

# load values from ONSPD
idx <- fread(file.path(in_path, 'ONSPD.csv'), select = c('osgrdind', 'oa11', 'lsoa11', 'imd', 'oac11', 'ru11ind', 'ctry'))
idx <- idx[osgrdind < 9]

# select and convert OAC
oac <- unique(idx[, .(value = oac11), .(location_id = oa11)])
dbc <- dbConnect(MySQL(), group = 'geouk')
lk <- dbGetQuery(dbc, 'SELECT subgroup_id, subgroup FROM oac')
dbDisconnect(dbc)
oac <- oac[lk, on = c(value = 'subgroup')][, value := subgroup_id][, subgroup_id := NULL]

# select and convert RUC
ruc <- unique(idx[ctry != 'N92000002', .(value = ru11ind), .(location_id = oa11)])
dbc <- dbConnect(MySQL(), group = 'geouk')
lk <- dbGetQuery(dbc, 'SELECT area_id, area FROM ruc')
dbDisconnect(dbc)
ruc <- ruc[lk, on = c(value = 'area')][, value := area_id][, area_id := NULL]

# select IMD
imd <- unique(idx[, .(value = imd), .(location_id = lsoa11)])

# bind above together
idx <- rbind(data.frame(idx = 1, oac), data.frame(idx = 2, ruc), data.frame(idx = 3, imd))

# save to database and fst format
dbc <- dbConnect(MySQL(), group = 'geouk')
dbSendQuery(dbc, "DELETE FROM indices WHERE idx <= 3")
dbWriteTable(dbc, 'indices', idx, row.names = FALSE, append = TRUE)
dbDisconnect(dbc)

# CLEAN & EXIT ------------------------------------------------------------------------------------------------------------------
rm(list = ls())
gc()

