###############################################################
# 10- POSTCODES (ONSPD & NHSPD)
###############################################################

### 1- Load packages, Set variables ---------------------------------------------------------------------------------------------
pkg <- c('data.table', 'RMySQL')
invisible(lapply(pkg, require, character.only = TRUE))
data.path <- 
    if (substr(Sys.info()['sysname'], 1, 1) == 'W') {
        'D:/cloud/OneDrive/data/UK/geography/postcodes/'
    } else {
        '/home/datamaps/data/UK/geography/postcodes/'
    }

### 2- ONSPD --------------------------------------------------------------------------------------------------------------------

# load data
onspd <- fread(paste0(data.path, 'ONSPD.csv'), 
                    select = c(
                        'pcd', 'doterm', 'oscty', 'oslaua', 'osward', 'usertype', 'osgrdind', 'oshlthau', 'ctry', 'gor', 
                        'pcon', 'ttwa', 'pct', 'nuts', 'oa11', 'lsoa11', 'msoa11', 'parish', 
                        'wz11', 'ccg', 'bua11', 'buasd11', 'lat', 'long', 'pfa'
                    )
)

## CHECK TOTALS ==> Table 1
onspd[, .N, ctry][order(ctry)]                                  # TOTAL
onspd[!(ctry %in% c('L93000001', 'M83000003')), .N]             # Total UK
onspd[, .N, usertype][order(usertype)]                          # 0-Small / 1-Large users, TOTAL
onspd[!(ctry %in% c('L93000001', 'M83000003')), .N, usertype]   # usertype TOTAL UK
dcast.data.table(onspd[, .N, .(ctry, usertype)][order(ctry, usertype)], ctry~usertype)  # Countries by usertype
## CHECK TOTALS ==> Table 3
onspd[osgrdind < 9, .N, ctry][order(ctry)]
dcast.data.table(onspd[osgrdind < 9, .N, .(ctry, usertype)][order(ctry, usertype)], ctry~usertype)

# eliminates postcodes without grid reference (osgrdind == 9, deletes also GI/IM), and rename columns
onspd <- onspd[osgrdind < 9, .(
                    postcode = pcd, is_active = as.numeric(doterm == ''), usertype, x_lon = long, y_lat = lat,
                    OA = oa11, LSOA = lsoa11, MSOA = msoa11, LAD = oslaua, CTY = oscty, RGN = gor, CTRY = ctry, BUA = bua11, BUAS = buasd11,
                    WARD = osward, PCON = pcon, LAU2 = nuts, TTWA = ttwa, WPZ = wz11, PFA = pfa, PAR = parish, 
                    PCT = pct, SHA = oshlthau, CCG = ccg
)]


### 3- NHSPD. There is no header in this file, so we have to use columns position. Read User guide for more info ----------------

# load data (only the fields not already present in ONSPD: NHSR, LAT). Also CTRY to check totals
nhspd <- fread(paste0(data.path, 'NHSPD.csv'),
                    select = c(1, 12, 13, 17, 24),
                    col.names = c('postcode', 'grid', 'CTRY', 'NHSR', 'LAT'),
                    header = FALSE, 
                    na.strings = ''
)
# check totals with previous ONS table
all.equal( 
    nhspd[grid < 9, .N, CTRY][!is.na(CTRY)][order(CTRY)], 
    onspd[, .N, CTRY][order(CTRY)] 
)

# eliminates postcodes without grid reference (osgrdind == 9, deletes also GI/IM) and with no country reference
nhspd <- nhspd[grid < 9 & !is.na(CTRY)]

# correct postcodes format from 8 to 7 chars
nhspd <- nhspd[, postcode := paste0(substr(postcode, 1, 4), substr(postcode, 6, 8) ) ]

# delete grid and CTRY columns
nhspd[, `:=`(grid = NULL, CTRY = NULL) ]


### 4- JOIN TABLES --------------------------------------------------------------------------------------------------------------
postcodes <- onspd[nhspd, on = 'postcode']


### 5- Add Postcode Areas, Districts, Sectors -----------------------------------------------------------------------------------
postcodes[, PCA := sub('[0-9]', '', substr(postcode, 1, gregexpr("[[:digit:]]", postcode)[[1]][1] - 1) ) ]
postcodes[, PCD := gsub(' ', '', substr(postcode, 1, 4) ) ]
postcodes[, PCS := substr(postcode, 1, 5) ]
# check and save total Table 2 (remember that now postcodes without grid have been deleted)
write.csv(
    rbindlist(list(
        postcodes[, .(PCD = uniqueN(PCD), PCS = uniqueN(PCS), live = sum(is_active), terminated = sum(!is_active), total = .N), PCA],
        postcodes[, .(PCA = 'TOTAL UK', PCD = uniqueN(PCD), PCS = uniqueN(PCS), live = sum(is_active), terminated = sum(!is_active), total = .N)]        
    )), 
    'csv/pca_totals.csv', row.names = FALSE
)

### 6- CLEAN + RECODE -----------------------------------------------------------------------------------------------------------

# check OA for postcodes "CR3 0EA" and "TN163UP"
# fix "wrongly" attributed codes for postcode "CR3 0EA"
postcodes[OA %in% c('E00005337', 'E00003159')]
postcodes[postcode == 'CR3 0EA', `:=`(
        LAD = 'E09000008', CTY = 'E99999999', RGN = 'E12000007',
        WARD = 'E05000156', PCON = 'E14000656', LAU2 = 'E05000156', PFA = 'E23000001', PAR = 'E43000198',
        PCT = 'E16000049', SHA = 'E18000007'
)]
# fix "wrongly" attributed code for postcode "TN163UP"
postcodes[postcode == 'TN163UP', `:=`(
        LAD = 'E09000006', CTY = 'E99999999', RGN = 'E12000007',
        WARD = 'E05000107', PCON = 'E14000872', LAU2 = 'E05000107', PFA = 'E23000001', PAR = 'E43000196',
        PCT = 'E16000004', SHA = 'E18000007'
)]

# change pseudo-codes to NA (or countries?)
cols <- c('MSOA', 'CTY', 'RGN', 'BUA', 'BUAS', 'PFA', 'PAR')
postcodes[, 
        (cols) := lapply(.SD, function(x) ifelse( x %in% c('N99999999', 'S99999999', 'W99999999', 'E34999999', 'W37999999', 'E35999999', 'W38999999'), NA, x)), 
        .SDcols = cols
]

# delete first two letters 'UK' from NI code for LAU2
postcodes[CTRY == 'N92000002', LAU2 := substring(LAU2, 3)]


### 7- SAVE RESULTS -------------------------------------------------------------------------------------------------------------
dbc <- dbConnect(MySQL(), group = 'dataOps', dbname = 'geography_uk')
dbSendQuery(dbc, "TRUNCATE TABLE postcodes")
dbWriteTable(dbc, 'postcodes', postcodes, row.names = FALSE, append = TRUE)


### 8- IMD, OAC, RUC ------------------------------------------------------------------------------------------------------------
# load values from ONSPD
idx <- fread(paste0(data.path, 'ONSPD.csv'), select = c('osgrdind', 'oa11', 'lsoa11', 'imd', 'oac11', 'ru11ind', 'ctry'))
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

### 9- CLEAN & EXIT -------------------------------------------------------------------------------------------------------------
dbDisconnect(dbc)
rm(list = ls())
gc()
