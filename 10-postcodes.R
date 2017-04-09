# There are two files, NHSPD and ONSPD, with overlapping information.
# Both contain ALL:
# - current (live) postcodes within the UK, CI and IM, as received monthly from Royal Mail.
# - terminated (closed) postcodes that have NOT been subsequently re-used by Royal Mail within the UK, and by the postal admini in CI and IM
# We'll be using only the shorter 7-char *PCD* form: 
# - outward code as 2/3/4 chars, left aligned (3rd and 4th char may be blank)
# - inward code always 3 chars (1st numeric, 2nd and 3rd alpha) – right aligned;

### 1- Load packages, Set variables ------------------------------------------------------------------------------------------
library('data.table')
library('RMySQL')
data.path <- 
    if(substr(Sys.info()['sysname'], 1, 1) == 'W'){
        'D:/cloud/OneDrive/data/UK/geography/postcodes/'
    } else {
        
    }

### 2- ONSPD ----------------------------------------------------------------------------------------------------------------

# load data
onspd <- fread(paste0(data.path, 'ONSPD.csv'), 
                    select = c(
                        'pcd', 'doterm', 'oscty', 'oslaua', 'osward', 'usertype', 'osgrdind', 'oshlthau', 'ctry', 'gor', 
                        'pcon', 'teclec', 'ttwa', 'pct', 'nuts', 'oshaprev', 'lea', 'oa11', 'lsoa11', 'msoa11', 'parish', 
                        'wz11', 'ccg', 'lat', 'long', 'pfa'
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
                    OA = oa11, LSOA = lsoa11, MSOA = msoa11, LAD = oslaua, CTY = oscty, RGN = gor, CTRY = ctry,
                    WARD = osward, PCON = pcon, LAU2 = nuts, TTWA = ttwa, WKZ = wz11, PFA = pfa, LLSC = teclec, LEA = lea, PAR = parish, 
                    PCT = pct, SHA = oshlthau, SHAO = oshaprev, CCG = ccg
)]


### 3- NHSPD. There is no header in this file, so we have to use columns position. Read USer guide for more info --------------

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


### 4- JOIN TABLES -----------------------------------------------------------------------------------------------------------
setkey(onspd, 'postcode')
setkey(nhspd, 'postcode')
postcodes <- onspd[nhspd]


### 5- Add Postcode Areas, Districts, Sectors ---------------------------------------------------------------------------------
postcodes[, PCA := sub('[0-9]', '', substr(postcode, 1, gregexpr("[[:digit:]]", postcode)[[1]][1]-1) ) ]
postcodes[, PCD := gsub(' ', '', substr(postcode, 1, 4) ) ]
postcodes[, PCS := substr(postcode, 1, 5) ]


### 6- SAVE RESULTS -----------------------------------------------------------------------------------------------------------
db_conn <- dbConnect(MySQL(), group = 'homeserver', dbname = 'geographyUK')
dbSendQuery(db_conn, "TRUNCATE TABLE postcodes")
dbWriteTable(db_conn, 'postcodes', postcodes, row.names = FALSE, append = TRUE)
dbDisconnect(db_conn)


### 7- CLEAN & EXIT ----------------------------------------------------------------------------------------------------------
rm(list = ls())
gc()

