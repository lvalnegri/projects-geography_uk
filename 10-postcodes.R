###############################################################
# 10- POSTCODES
###############################################################

### 1- Load packages, Set variables ---------------------------------------------------------------------------------------------
pkg <- c('data.table', 'RMySQL')
pkg <- lapply(pkg, require, character.only = TRUE)
data.path <- 
    if (substr(Sys.info()['sysname'], 1, 1) == 'W') {
        'D:/cloud/OneDrive/data/UK/geography/postcodes/'
    } else {
        
    }

### 2- ONSPD --------------------------------------------------------------------------------------------------------------------

# load data
onspd <- fread(paste0(data.path, 'ONSPD.csv'), 
                    select = c(
                        'pcd', 'doterm', 'oscty', 'oslaua', 'osward', 'usertype', 'osgrdind', 'oshlthau', 'ctry', 'gor', 
                        'pcon', 'teclec', 'ttwa', 'pct', 'nuts', 'oshaprev', 'lea', 'oa11', 'lsoa11', 'msoa11', 'parish', 
                        'wz11', 'ccg', 'bua11', 'buasd11', 'lat', 'long', 'pfa'
                    )
)

# check totals (with users guide Table 1)
onspd[, .N, ctry][order(ctry)]
onspd[!(ctry %in% c('L93000001', 'M83000003')), .N]
onspd[, .N, usertype][order(usertype)]
onspd[!(ctry %in% c('L93000001', 'M83000003')), .N, usertype]
onspd[, .N, .(ctry, usertype)][order(ctry, usertype)]
onspd[osgrdind < 9, .N, ctry][order(ctry)]
onspd[osgrdind < 9, .N, .(ctry, usertype)][order(ctry, usertype)]

# eliminates postcodes without grid reference (osgrdind == 9, deletes also GI/IM), and rename columns
onspd <- onspd[osgrdind < 9, .(
                    postcode = pcd, 
                    is_active = as.numeric(doterm == ''), usertype, X_lon = long, Y_lat = lat,
                    OA = oa11, LSOA = lsoa11, MSOA = msoa11, LAD = oslaua, CTY = oscty, RGN = gor, CTRY = ctry, BUA = bua11, BUAS = buasd11,
                    WARD = osward, PCON = pcon, LAU2 = nuts, TTWA = ttwa, WKZ = wz11, PFA = pfa, LLSC = teclec, LEA = lea, PAR = parish, 
                    PCT = pct, SHA = oshlthau, SHAO = oshaprev, CCG = ccg
)]


### 3- NHSPD. There is no header in this file, so we have to use columns position. Read USer guide for more info ----------------

# load data (only the fields not already present in ONSPD: NHSR, LAT, CNR, SCN). Also CTRY to check totals
nhspd <- fread(paste0(data.path, 'NHSPD.csv'),
                    select = c(1, 12, 13, 17, 24, 30, 35),
                    col.names = c('postcode', 'grid', 'CTRY', 'NHSR', 'LAT', 'SCN', 'CNR'),
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
setkey(onspd, 'postcode')
setkey(nhspd, 'postcode')
postcodes <- onspd[nhspd]


### 5- Add Postcode Areas, Districts, Sectors -----------------------------------------------------------------------------------
postcodes[, PCA := sub('[0-9]', '', substr(postcode, 1, gregexpr("[[:digit:]]", postcode)[[1]][1] - 1) ) ]
postcodes[, PCD := gsub(' ', '', substr(postcode, 1, 4) ) ]
postcodes[, PCS := substr(postcode, 1, 5) ]


### 6- CLEAN + RECODE -----------------------------------------------------------------------------------------------------------

# check OA for postcodes "CR3 0EA" and "TN163UP"
# fix wrongly attributed codes for postcode "CR3 0EA"
postcodes[OA %in% c('E00005337', 'E00003159')]
postcodes[postcode == 'CR3 0EA', `:=`(
        LAD = 'E09000008', CTY = 'E99999999', RGN = 'E12000007',
        WARD = 'E05000156', PCON = 'E14000656', PFA = 'E23000001', PAR = 'E43000198', LAU2 = 'E05000156',
        PCT = 'E16000049', SHA = 'E18000007'
)]
# fix wrongly attributed code for postcode "TN163UP"
postcodes[postcode == 'TN163UP', `:=`(
        LAD = 'E09000006', CTY = 'E99999999', RGN = 'E12000007',
        WARD = 'E05000107', PCON = 'E14000872', PFA = 'E23000001', PAR = 'E43000196', LAU2 = 'E05000107',
        LLSC = 'E24000016', PCT = 'E16000004', SHA = 'E18000007', SHAO = 'Q07'
)]

# change pseudo-code to countries
postcodes[postcodes == 'E99999999'] <- 'E92000001'
postcodes[postcodes == 'S99999999'] <- 'S92000003'
postcodes[postcodes == 'N99999999'] <- 'N92000002'
postcodes[postcodes == 'W99999999'] <- 'W92000004'

# code as missing parts of BUA(S) not coded
postcodes[BUA %in% c('', 'E34999999', 'W37999999', 'S92000003', 'N92000002'), BUA := NA]
postcodes[BUAS %in% c('', 'E35999999', 'W38999999', 'S92000003', 'N92000002'), BUAS := NA]


### 7- SAVE RESULTS -------------------------------------------------------------------------------------------------------------
db_conn <- dbConnect(MySQL(), group = 'local', dbname = 'geographyUK')
dbSendQuery(db_conn, "TRUNCATE TABLE postcodes")
dbWriteTable(db_conn, 'postcodes', postcodes, row.names = FALSE, append = TRUE)


### 7- CLEAN & EXIT -------------------------------------------------------------------------------------------------------------
dbDisconnect(db_conn)
rm(list = ls())
gc()

### LOAD postcodes once stored
# pkg <- c('data.table', 'RMySQL')
# pkg <- lapply(pkg, require, character.only = TRUE)
# db_conn <- dbConnect(MySQL(), group = 'homeserver-out', dbname = 'geographyUK')
# postcodes <- data.table(dbReadTable(db_conn, 'postcodes'), key = 'postcode')
# dbDisconnect(db_conn)

lapply(names(postcodes)[6:length(postcodes)], function(x) postcodes[, .N, x][order(N)])
