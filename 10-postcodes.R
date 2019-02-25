#################################
# UK GEOGRAPHY * 10 - POSTCODES #
#################################

### Load packages -----------------------------------------------------------------------------------------------------------------------------------
pkg <- c('data.table', 'fst', 'RMySQL')
invisible(lapply(pkg, require, character.only = TRUE))

### Set constants -----------------------------------------------------------------------------------------------------------------------------------
data_ext <- file.path(Sys.getenv('PUB_PATH'), 'ext-data/geography_uk')
data_out <- file.path(Sys.getenv('PUB_PATH'), 'datasets/geography_uk')

### 2- load ONSPD -----------------------------------------------------------------------------------------------------------------------------------
# download latest @ http://geoportal.statistics.gov.uk/datasets?q=ONS+Postcode+Directory+(ONSPD)+zip&sort_by=updated_at
# Extract big file from *Data* directory 'ONSPD_MMM_YYYY_UK.csv' and copy it to data_ext as 'ONSPD.csv'
# load data
postcodes <- fread(
                file.path(data_ext, 'postcodes', 'ONSPD.csv'), 
                select = c(
                   'pcd', 'osgrdind', 'doterm', 'usertype', 'long', 'lat', 
                   'oa11', 'lsoa11', 'msoa11', 'oslaua', 'oscty', 'rgn', 'ctry',
                   'ttwa', 'osward', 'pcon', 'ced', 'parish', 'bua11', 'buasd11', 'wz11',
                   'pfa', 'ccg', 'stp', 'nuts'
                ),
                col.names = c(
                    'postcode', 'osgrdind', 'is_active', 'usertype', 'x_lon', 'y_lat',
                    'OA', 'LSOA', 'MSOA', 'LAD', 'CTY', 'RGN', 'CTRY', 
                    'TTWA', 'WARD', 'PCON', 'CED', 'PAR', 'BUA', 'BUAS', 'WPZ', 'PFA', 'CCG', 'STP', 'LAU2'
                ),
                na.string = ''
)

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

### 3- Add Postcode Areas, Districts, Sectors -------------------------------------------------------------------------------------------------------
postcodes[, PCA := sub('[0-9]', '', substr(postcode, 1, gregexpr("[[:digit:]]", postcode)[[1]][1] - 1) ) ]
postcodes[, PCD := gsub(' .*', '', substr(postcode, 1, 4)) ]
postcodes[, PCS := substr(postcode, 1, 5) ]

# order postcode districts
pcd <- unique(postcodes[is_active & !postcode %in% postcodes[grep('^[A-Z]{3}', postcode), postcode], .(PCD)])
pcd[, `:=`( PCDa = regmatches(pcd$PCD, regexpr('[a-zA-Z]+', pcd$PCD)), PCDn = as.numeric(regmatches(pcd$PCD, regexpr('[0-9]+', pcd$PCD))) )]
pcd <- pcd[order(PCDa, PCDn)][, ordering := 1:.N][, .(PCD, ordering)]
write.csv(pcd, file.path(data_ext, 'locations', 'PCD.csv'), row.names = FALSE)

# order postcode sectors 
pcs <- unique(postcodes[is_active & !postcode %in% postcodes[grep('^[A-Z]{3}', postcode), postcode], .(PCD, PCS)])
pcs <- pcs[pcd, on = 'PCD']
pcs <- pcs[order(ordering, PCS)][, ordering := 1:.N][, .(PCS, ordering)]
write.csv(pcs, file.path(data_ext, 'locations', 'PCS.csv'), row.names = FALSE)

# check and save total Table 2 (remember that now postcodes without grid have been deleted)
pca <- rbindlist(list(
    postcodes[, .(PCD = uniqueN(PCD), PCS = uniqueN(PCS), live = sum(is_active), terminated = sum(!is_active), total = .N), PCA],
    postcodes[, .(PCA = 'TOTAL UK', PCD = uniqueN(PCD), PCS = uniqueN(PCS), live = sum(is_active), terminated = sum(!is_active), total = .N)]        
))
write.csv(pca, file.path(data_ext, 'locations', 'pca_totals.csv'), row.names = FALSE)

### 4- CLEAN + RECODE -------------------------------------------------------------------------------------------------------------------------------

# check OA for postcodes with seemingly "wrong" associations
oas <- unique(postcodes[, .(OA, LAD)])[, .N, OA][N > 1][, OA]
oas <- postcodes[OA %in% oas]

# "fix" codes for postcode ""
# postcodes[postcode == '', `:=`(
#     LAD = '', CTY = '', RGN = '', WARD = '', CED = '', PCON = '', PAR = '', LAU2 = ''
# )]
# "fix" codes for postcode "CR3 0EA"
postcodes[postcode == 'CR3 0EA', `:=`(
    LAD = 'E09000008', CTY = 'E99999999', RGN = 'E12000007', WARD = 'E05011469', CED = 'E99999999', PCON = 'E14000656', PAR = 'E43000198', LAU2 = 'E05011469'
)]
# "fix" codes for postcode "TN163UP"
postcodes[postcode == 'TN163UP', `:=`(
    LAD = 'E09000006', CTY = 'E99999999', RGN = 'E12000007', WARD = 'E05000107', CED = 'E99999999', PCON = 'E14000872', PAR = 'E43000196', LAU2 = 'E05000107'
)]
# "fix" codes for postcode "WR127LJ"
postcodes[postcode == 'WR127LJ', `:=`(
    LAD = 'E07000079', CTY = 'E10000013', RGN = 'E12000009', WARD = 'E05010700', CED = 'E58000484', PAR = 'E04004287', LAU2 = 'E05010700'
)]
# "fix" codes for postcode "EC4Y9BE"
postcodes[postcode == 'EC4Y9BE', `:=`(
    LAD = 'E09000001', WARD = 'E05009305', PAR = 'E43000191', LAU2 = 'E05009305'
)]

# change pseudo-codes to NA (or countries?)
cols <- c('MSOA', 'CTY', 'RGN', 'CED', 'PAR', 'BUA', 'BUAS', 'PFA', 'STP')
postcodes[, 
    (cols) := lapply(.SD, function(x) 
        ifelse( x %in% c('E99999999', 'N99999999', 'S99999999', 'W99999999', 'E34999999', 'W37999999', 'E35999999', 'W38999999'), NA, x)
    ), 
    .SDcols = cols
]

### 5- SAVE RESULTS IN DATABASE ---------------------------------------------------------------------------------------------------------------------
dbc = dbConnect(MySQL(), group = 'geography_uk')
dbSendQuery(dbc, "TRUNCATE TABLE postcodes")
dbWriteTable(dbc, 'postcodes', postcodes, row.names = FALSE, append = TRUE)

### 6- SAVE RESULTS IN fst FORMAT -------------------------------------------------------------------------------------------------------------------
cols <- colnames(postcodes)
cols <- cols[6:length(cols)]
postcodes[, (cols) := lapply(.SD, factor), .SDcols = cols]
write.fst(postcodes, file.path(data_out, 'postcodes'))

### 8- IMD, OAC, RUC --------------------------------------------------------------------------------------------------------------------------------

# load values from ONSPD
idx <- fread(file.path(data_ext, 'postcodes', 'ONSPD.csv'), select = c('osgrdind', 'oa11', 'lsoa11', 'imd', 'oac11', 'ru11ind', 'ctry'))
idx <- idx[osgrdind < 9]

# select and convert OAC
oac <- unique(idx[, .(value = oac11), .(location_id = oa11)])
lk <- dbGetQuery(dbc, 'SELECT subgroup_id, subgroup FROM oac')
oac <- oac[lk, on = c(value = 'subgroup')][, value := subgroup_id][, subgroup_id := NULL]

# select and convert RUC
ruc <- unique(idx[ctry != 'N92000002', .(value = ru11ind), .(location_id = oa11)])
lk <- dbGetQuery(dbc, 'SELECT area_id, area FROM ruc')
ruc <- ruc[lk, on = c(value = 'area')][, value := area_id][, area_id := NULL]

# select IMD
imd <- unique(idx[, .(value = imd), .(location_id = lsoa11)])

# bind above together
idx <- rbind(data.frame(idx = 1, oac), data.frame(idx = 2, ruc), data.frame(idx = 3, imd))

# save to database
dbSendQuery(dbc, "DELETE FROM indices WHERE idx <= 3")
dbWriteTable(dbc, 'indices', idx, row.names = FALSE, append = TRUE)

### CLEAN & EXIT ------------------------------------------------------------------------------------------------------------------------------------
dbDisconnect(dbc)
rm(list = ls())
gc()


