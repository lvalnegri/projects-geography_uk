####################################
# UK GEOGRAPHY * 21 - Output Areas #
####################################

## Check if the following lookups need to be updated:
#  - LAD => CTY
#  - OA => PCS for Scotland (using boundaries)
#  - OA => WARD
#  - OA => PAR 
#  - LAD => CSP

####### -----------------------------------------
#### PRELIMINARIES ------------------------------

# load packages ---------------------------------
pkgs <- c('dmpkg.funs', 'data.table', 'fst', 'readODS', 'readxl', 'rgdal', 'rgeos')
invisible(lapply(pkgs, require, char = TRUE))

# set constants ---------------------------------
extp <- file.path(ext_path, 'uk', 'geography')
lkps_path <- file.path(extp, 'lookups')
loca_path <- file.path(extp, 'locations')
bnd_path <- file.path(extp, 'boundaries')

# define functions ------------------------------
get_summary_area <- function(area_type, country = TRUE){
    if(country){
        y <- uk[, .(X = get(area_type), CTRY = substring(CTRY, 1, 1))]
    } else {
        y <- uk[, .(X = get(area_type))][, CTRY := substring(X, 1, 1)]
    }
    rbindlist(list( 
        unique(y[!is.na(X), .(X, CTRY)])[, .N, CTRY], 
        data.table('--', paste( rep('-', nchar(uniqueN(y[!is.na(X)]))), collapse = '')), 
        data.table('UK', uniqueN(uk[!is.na(get(area_type)), get(area_type)]))
    ), use.names = FALSE)
}
fill_missing_oas <- function(miss, ref){
    setnames(uk, c(miss, ref), c('X', 'Y'))
    y1 <- uk[is.na(X), .(OA, Y)]
    y2 <- uk[Y %in% unique(y1$Y), .(OA, Y, X)][!is.na(X)][, .N, .(Y, X)][, .SD[which.max(N)], Y][, N := NULL]
    y <- y2[y1, on = 'Y'][, Y := NULL]
    uk[OA %in% y[, OA], X := y[.SD[['OA']], .(X), on = 'OA'] ]
    setnames(uk, c('X', 'Y'), c(miss, ref))
}

# load postcodes ----------
pc <- read_fst_idx(file.path(geouk_path, 'postcodes'), 1)

####### -----------------------------------------
#### A) Census hierachy (Output Area to LSOA, MSOA (EWS only) // LAD, RGN (E only), CTRY --------------------

### 1- OA ==> LSOA ------------------------------

message('Processing [OA=>LSOA] for England...')
eng <- fread(
        file.path(lkps_path, 'OA11_LSOA11_MSOA11_LAD11_EW_LUv2.csv'), 
        select = 1:2, 
        col.names = c('OA', 'LSOA')
)

message('Processing [OA=>LSOA] for Scotland...')
sco <- fread(
        file.path(lkps_path, '00462936.csv'), 
        select = 1:2, 
        col.names = c('OA', 'LSOA')
)

message('Processing [OA=>LSOA] for N.Ireland...')
nie <- read_ods(
        file.path(lkps_path, 'Geographic_Data_(statistical_geographies).ods'), 
        sheet = 1, 
        skip = 4
)
nie <- nie[, 1:2]

message('Bounding together [OA=>LSOA] for UK...')
uk <- rbindlist(list(eng, sco, nie), use.names = FALSE)
# check totals OA: UK 232,296, E 171,372, W 10,036, S 46,351, N 4,537
get_summary_area('OA', country = FALSE)
# check totals LSOA: UK 42,619, E 32,844, W 1,909, S 6,976, N 890
get_summary_area('LSOA', country = FALSE)

### 2- LSOA > MSOA ------------------------------

message('Processing [OA=>MSOA] for England...')
eng <- fread(
        file.path(lkps_path, 'OA11_LSOA11_MSOA11_LAD11_EW_LUv2.csv'), 
        select = c(1, 4), 
        col.names = c('OA', 'MSOA')
)

message('Processing [OA=>MSOA] for Scotland...')
sco <- fread(
        file.path(lkps_path, '00462936.csv'), 
        select = c(1, 3), 
        col.names = c('OA', 'MSOA')
)

# ===> there are no MSOA for NI

message('Bounding together [OA=>MSOA] for GB...')
uk <- rbindlist(list(eng, sco))[uk, on = 'OA']
# check totals MSOA: UK 8,480, E 6,791, W 410, S 1,279, N NA
get_summary_area('MSOA', country = FALSE)

### 3- LSOA (N) / MSOA (EWS) > LAD --------------

message('Processing [MSOA=>LAD] for England, Wales, and Scotland...')
## EWS: build from 'postcodes' table using 'MSOA' as base
eng <- build_lookups_table('MSOA', 'LAD', filter_country = 'E', save_results = TRUE)
wls <- build_lookups_table('MSOA', 'LAD', filter_country = 'W', save_results = TRUE)
sco <- build_lookups_table('MSOA', 'LAD', filter_country = 'S', save_results = TRUE)
# union of the previous dataframes
y <- rbindlist(list(eng, wls, sco))
# merge with previous uk by MSOA
uk <- y[, 1:2][uk, on = 'MSOA']

message('Processing [LSOA=>LAD] for Northern Ireland...')
## N: build from 'postcodes' table using 'LSOA' as base
nie <- build_lookups_table('LSOA', 'LAD', filter_country = 'N', save_results = TRUE)
# update LAD for NI by LSOA
uk[is.na(LAD), LAD := nie[.SD[['LSOA']], .(LAD), on = 'LSOA'] ]

# check totals LAD: UK 391, E 326, W 22, S 32, N 11
get_summary_area('LAD', country = FALSE)

### 4- LAD > CTY (E) ----------------------------

message('Processing [LAD=>CTY] for England...')
y <- fread(
        file.path(lkps_path, 'Local_Authority_District_to_County_(April_2020)_Lookup_in_England.csv'), 
        select = c(2, 4), 
        col.names = c('LAD', 'CTY')
)
# add Unitary Authority from LAD to complete England (changing E060 => E069 to keep primary key valid)
ym <- unique(uk[substr(LAD, 1, 1) == 'E', .(LAD)])[!LAD %in% y[, LAD]][order(LAD)]
ym[, CTY := gsub('E060', 'E069', LAD)]
y <- rbindlist(list(y, ym))[order(LAD)]
# merge with previous uk by LAD
uk <- y[uk, on = 'LAD']
# check totals CTY: UK 35, E 35 (plus NAs to be recoded below according to the region), W NA, S NA, N NA
get_summary_area('CTY', country = FALSE)

### 5- LAD > RGN (E) ----------------------------
message('Processing [LAD=>RGN] for England...')
# build from 'postcodes' table using 'LAD' as base
y <- build_lookups_table('LAD', 'RGN', filter_country = 'E')
# merge with previous uk by LAD
uk <- y[, 1:2][uk, on = 'LAD']
# check totals RGN: UK 9, E 9, W NA, S NA, N NA
get_summary_area('RGN', country = FALSE)

### 6- LAD > CTRY -------------------------------
message('Processing [LAD=>CTRY] for UK...')
# build from 'postcodes' table using 'LSOA' as base
y <- build_lookups_table('LAD', 'CTRY')
# merge with previous uk by LAD
uk <- uk[y[, 1:2], on = 'LAD']
# replace CTRY with acronym
ctry <- data.table( 'old' = c('E', 'W', 'S', 'N'), 'CTRY' = c('ENG', 'WLS', 'SCO', 'NIE') )
uk <- ctry[uk, on = c(old = 'CTRY')][, old := NULL]
# uk[, CTRY := substring(CTRY, 1, 1)]
# check totals CTRY: UK 4, E 1, W 1, S 1, N 1
get_summary_area('CTRY')
# reorder columns by hierarchy and rows by OA
setcolorder(uk, c('OA', 'LSOA', 'MSOA', 'LAD', 'CTY', 'RGN', 'CTRY'))
uk <- uk[order(OA)]

### 9- CTY/RGN for N/S/W ------------------------
uk[is.na(CTY), `:=`( CTY = paste0(CTRY, '_CTY'), RGN = paste0(CTRY, '_RGN') ) ]

####### -----------------------------------------
#### B) Postal hierarchy: Output Area to PCS, PCD, PCA -

### 1- OA > PCS ---------------------------------

## W: build from postcodes table using OA as base
message('Processing [OA=>PCS] for Wales...')
wls <- build_lookups_table('OA', 'PCS', filter_country = 'W', save_results = TRUE)

## N: build from postcodes table using OA as base
message('Processing [OA=>PCS] for Northern Ireland...')
nie <- build_lookups_table('OA', 'PCS', filter_country = 'N', save_results = TRUE)

## E: build from postcodes table using OA as base, then using old 2011 lookups from ONS to fill gaps
message('Processing [OA=>PCS] for England...')
eng <- build_lookups_table('OA', 'PCS', filter_country = 'E', save_results = TRUE)
y <- fread(
        file.path(lkps_path, 'OA11_PCDS11_EW_LU.csv'),
        select = 1:2,
        col.names = c('OA', 'PCS')
)
eng <- rbindlist(list( eng[, 1:2], y[OA %in% uk[CTRY == 'ENG'][!OA %in% eng[, OA], OA] ] ))

## S: build from postcodes table using OA as base, then complete using PIP with OA coords and PCS boundaries
# to stay updated, download latest boundaries @ https://www.nrscotland.gov.uk/statistics-and-data/geography/nrs-postcode-extract
message('Processing [OA=>PCS] for Scotland...')
sco <- build_lookups_table('OA', 'PCS', filter_country = 'S', save_results = TRUE)
y <- uk[CTRY == 'SCO', .(OA)]
sco <- sco[y, on = 'OA'][, .(OA, PCS)]
bnd.pcs <- readOGR(file.path(bnd_path, 'PCS'), 'SC')
bnd.oa <- readOGR(file.path(bnd_path, 'OA'), 'SC')
y <- data.table( 'OA' = as.character(bnd.oa$code), 'PCS' = as.character(over(gCentroid(bnd.oa, byid = TRUE), bnd.pcs)[, 2]) )
y[nchar(PCS) == 4, PCS := gsub(' ', '  ', PCS)]
y[nchar(PCS) == 6, PCS := gsub(' ', '', PCS)]
y <- y[ OA %in% sco[is.na(PCS), OA], .(OA, PCS) ]
sco <- rbindlist(list( sco[!is.na(PCS)], y ))

# bind together all four countrioes
message('Processing [OA=>PCS] for UK...')
y <- rbindlist(list(eng[, 1:2], wls[, 1:2], sco, nie[, 1:2]))

# merge with previous uk by OA
uk <- y[uk, on = 'OA']

# check totals CTRY: (for MAY-19) UK 9882, E 8142, W 528, S 999, N 234
get_summary_area('PCS')

### 2- PCS > PCD --------------------------------
message('Processing [PCS=>PCD] for UK...')
uk[, PCD := gsub(' .*', '', substr(PCS, 1, 4)) ]
# check totals CTRY: UK 2847, E 2146, W 203, S 436, N 80 (total missing: 2955 - 2847 = 108)
get_summary_area('PCD')

## Because of the different methods, there usually are many sectors, and some districts, missing when aggregating PCS by OAs
## Let's try to recover some of them substituting some OAs associated with districts which has multiple OAs in lookups

# load the districts
pcd <- fread(file.path(loca_path, 'PCD.csv'))

# extract the missing districts
pcd_miss <- pcd[!PCD %in% unique(uk[, PCD]), .(PCD, found = 0)][]

for(x0 in pcd_miss$PCD){
    message('========================================================')
    message('Processing missing District: <', x0, '>')
    # extract the output areas and postcode sectors associated with the missing districts, ordering by number of corresponding OAs
    x1 <- unique(pc[PCD == x0, .N, .(OA, PCS)])[order(-N)]
    message('OAs associated: ', nrow(x1))
    # starting from the sector with most OAs, look for the first district in lookups which has more than one OA associated
    for(idx in 1:nrow(x1)){ 
        message('--------------------------------------------------------')
        x2 <- x1[, .SD[idx]]
        message('Output Area: ', x2$OA )
        message('Count of OAs: ', x2$N )
        message('Sector: ', x2$PCS )
        # extract from lookups the district associated with the current OA to see if it has more than one OA associated
        x3 <- uk[OA == x2$OA, PCD]
        message('Associated District in lookups: ', x3 )
        x4 <- nrow(uk[PCD == x3])
        message('Associated Output Areas in lookups: ', x4)
        if(x4 == 1){
            message('Discarded...')
        } else {
            message('Found substitution! Updating lookups ')
            pcd_miss[PCD == x0, found := 1]
            uk[OA == x2$OA, `:=`(PCS = x2$PCS, PCD = x0)]
            break
        }
    }
    message('========================================================\n')
}
x <- nrow(pcd_miss) - sum(pcd_miss$found)
if(x > 0){
    message('There still are ', x, ' districts missing. Need to be looked at manually! See the csv files I am currently processing and saving...')
    x <- data.table( miss_PCD = character(0), miss_OA = character(0), miss_PCS = character(0), N_OAs = integer(0), lkp_PCD = character(0) )
    for(x0 in pcd_miss[found == 0]$PCD)
        x <- rbindlist(list( x, data.table( x0, unique(pc[PCD == x0, .N, .(OA, PCS)])[order(-N)], NA )), use.names = FALSE)
    x[, lkp_PCD := sapply(miss_OA, function(x) uk[OA == x, PCD])]
    fwrite(x, file.path(lkps_path, 'pcd_missing.csv'), row.names = FALSE)
}

# check totals again CTRY: UK 2932, E 2215, W 203, S 436, N 80 (total missing: 2955 - 2932 = 23)
get_summary_area('PCD')


### 3- PCD > PCT---------------------------------
message('Processing [PCD=>PCT] for UK...')
pcd <- fread(file.path(lkps_path, 'PCD_to_PCT.csv'))
# merge with previous uk by PCD
uk <- pcd[, .(PCD, PCT)][uk, on = 'PCD']
# check totals PCT: UK 1411, E 942, W 160, S 285, N 45
get_summary_area('PCT')

### 4- PCD > PCA --------------------------------
message('Processing [PCD=>PCA] for UK...')
uk[, PCA := sub('[0-9]', '', substr(PCS, 1, gregexpr("[[:digit:]]", PCS)[[1]][1] - 1) ) ]
# check totals PCA: UK 121, E 96, W 2, S 15, N 1, K 7
get_summary_area('PCA')


####### -----------------------------------------
#### C) Admin/Electoral hierarchy: Output Area to TTWA, WARD, CED (E only), PCON, PAR (EW only) ------------------------------------------------------

### LSOA > TTWA -----------------------
message('Processing [LSOA=>TTWA] for UK...')
y <- fread(
        file.path(lkps_path, 'LSOA11_TTWA11_UK_LU.csv'), 
        select = c(1, 3), 
        col.names = c('LSOA', 'TTWA')
)
# merge with previous 
uk <- y[, 1:2][uk, on = 'LSOA']
# check totals TTWA: UK : E 155, W 10, S 47, N 22
get_summary_area('TTWA')

### OA > WARD -------------------------
message('Processing [OA=>WARD] for UK...')
# build from 'postcodes' table using 'OA' as base
y <- build_lookups_table('OA', 'WARD', save_results = TRUE)
# merge with previous 
uk <- y[, 1:2][uk, on = 'OA']
# check totals WARD: UK 8887: E 7432, W 852, S 354, N 462
get_summary_area('WARD')

### OA > CED --------------------------
message('Processing [OA=>CED] for England...')
# build from 'postcodes' table using 'OA' as base
y <- build_lookups_table('OA', 'CED', filter_country = 'E', save_results = TRUE)
# merge with previous uk by OA
uk <- y[, 1:2][uk, on = 'OA']
uk[substring(CED, 7) == '999', CED := NA]
# check totals CED: UK 1717: E 1717, W NA, S NA, N NA
get_summary_area('CED')

### OA > PCON -------------------------
message('Processing [OA=>PCON] for UK...')
# build from 'postcodes' table using 'OA' as base
y <- build_lookups_table('OA', 'PCON', save_results = TRUE)
# merge with previous uk by OA
uk <- y[, 1:2][uk, on = 'OA']
# check totals CTY: UK 650: E 533, W 40, S 59, N 18
get_summary_area('PCON')

### OA > PAR --------------------------
message('Processing [OA=>PAR] for England...')
# build from 'postcodes' table using 'OA' as base
y <- build_lookups_table('OA', 'PAR', save_results = TRUE)
# merge with previous uk by OA
uk <- y[, 1:2][uk, on = 'OA']

# load missing OA>PAR associations using the last available from ONS
y <- fread(
        file.path(lkps_path, 'OA11_PAR11_LAD11_EW_LU.csv'), 
        select = 1:2, 
        col.names = c('OA', 'PAR')
)
# update only Eng NA 
uk[is.na(PAR), PAR := y[.SD[['OA']], .(PAR), on = 'OA'] ]
uk[nchar(PAR) == 0, PAR := NA]

# check totals CTY: UK 10455: E 9579, W 876, S NA, N NA
get_summary_area('PAR')

# fixing PAR and PCON missing
# yp2 <- uk[CTRY == 'ENG' & LSOA %in% uk[is.na(PAR), LSOA]][!is.na(PAR), .(LSOA, PAR, PCON)]
# uk[is.na(PAR), PAR := y[.SD[['OA']], .(PAR), on = 'OA'] ]

####### -----------------------------------------
#### D) Statistical hierarchy: Output Area to MTC (EW only), BUA (E only), BUAS (E only) ------------------------------------------------------------

### OA > MTC --------------------------
message('Processing [OA=>MTC] for England...')
# download and read lookup tables
y <- fread(
        file.path(lkps_path, 'Output_Area_2011_to_Major_Towns_and_Cities_December_2015_Lookup_in_England_and_Wales.csv'), 
        select = 1:2, 
        col.names = c('OA', 'MTC')
)
# merge with previous 
uk <- y[uk, on = 'OA'][MTC == '', MTC := NA]
# check totals CTY: UK 112, E 108, W 3, S NA, N NA, K 1 (J01000025)
get_summary_area('MTC')
unique(uk[!is.na(MTC), .(MTC, CTRY)])[,.N, .(CTRY = substring(CTRY, 1, 1))]

### OA > BUA --------------------------
message('Processing [OA=>BUA] for England and Wales...')
y <- fread(
    file.path(lkps_path, 'OA11_BUASD11_BUA11_LAD11_RGN11_EW_LU.csv'), 
    select = c(1, 4), 
    col.names = c('OA', 'BUA'), 
    na.strings = ''
)
uk <- y[uk, on = 'OA']

# check totals CTY: UK 5493, E 5055, W 427, S NA, N NA, K 11
unique(uk[, .(BUA)])[, .N, substr(BUA, 1, 1)]
get_summary_area('BUA')

### OA > BUAS -------------------------
message('Processing [OA=>BUAS] for England and Wales...')
y <- fread(
    file.path(lkps_path, 'OA11_BUASD11_BUA11_LAD11_RGN11_EW_LU.csv'), 
    select = 1:2, 
    col.names = c('OA', 'BUAS'), 
    na.strings = ''
)
uk <- y[uk, on = 'OA']

# check totals CTY: UK 1693, E 1539, W 150, S NA, N NA, K 4
unique(uk[, .(BUAS)])[, .N, substr(BUAS, 1, 1)]
get_summary_area('BUAS')


#### E) Social hierarchy PFA (EW only), CCG, STP (E only) --------------------------------------------------------------------------
### LAD > CSP --------------------------
message('Processing [LAD=>CSP] for England and Wales...')
y <- fread(
    file.path(lkps_path, 'Local_Authority_District_to_Community_Safety_Partnerships_to_Police_Force_Areas_December_2018_Lookup_in_England_and_Wales.csv'), 
    select = c(1, 3), 
    col.names = c('LAD', 'CSP'), 
    na.strings = ''
)
uk <- y[uk, on = 'LAD']

### LAD > PFA --------------------------
message('Processing [LAD=>PFA] for England and Wales...')
# build from 'postcodes' table using 'LAD' as base
y <- build_lookups_table('LAD', 'PFA', save_results = TRUE)
# merge with previous uk by OA
uk <- y[, 1:2][uk, on = 'LAD']

### LSOA > STP --------------------------
message('Processing [LSOA=>STP] for England...')
# build from 'postcodes' table using 'LSOA' as base
y <- build_lookups_table('LSOA', 'STP', filter_country = 'E', save_results = TRUE)
# merge with previous uk by OA
uk <- y[, 1:2][uk, on = 'LSOA']
uk[STP == '', STP := NA]
# check totals STP: UK , E , W , S , N 
get_summary_area('STP')

### LSOA > CCG --------------------------
message('Processing [LSOA=>CCG] for UK...')
# build from 'postcodes' table using 'LSOA' as base
y <- build_lookups_table('LSOA', 'CCG', save_results = TRUE)
# merge with previous uk by OA
uk <- y[, 1:2][uk, on = 'LSOA']
# this is a manual recode an should be checked regularly
uk[is.na(CCG), CCG := 'S03000043']
# check totals CCG: UK , E , W , S , N 
get_summary_area('CCG')

### CCG > NHSO --------------------------
message('Processing [CCG=>NHSO] for England...')
# build from 'postcodes' table using 'OA' as base
y <- build_lookups_table('CCG', 'NHSO', filter_country = 'E', save_results = TRUE)
# merge with previous uk by CCG
uk <- y[, 1:2][uk, on = 'CCG']

# check totals NHSO: UK 17, E 14, W 1 (pseudo), S 1 (pseudo), N 1 (pseudo)
get_summary_area('NHSO')

### NHSO > NHSR --------------------------
message('Processing [NHSO=>NHSR] for England...')
nhsr <- data.table(
    'NHSO' = c(
        'E39000018', 'E39000026', 'E39000032', 'E39000033', 'E39000037', 'E39000040', 'E39000041',
        'E39000042', 'E39000043', 'E39000044', 'E39000045', 'E39000046', 'E39000047', 'E39000048',
        'NIE_NHSO', 'SCO_NHSO', 'WLS_NHSO'
    ),
    'NHSR' = c(
        'E40000003', 'E40000010', 'E40000008', 'E40000008', 'E40000010', 'E40000010', 'E40000005',
        'E40000005', 'E40000006', 'E40000006', 'E40000008', 'E40000007', 'E40000009', 'E40000009',
        'NIE_NHSR', 'SCO_NHSR', 'WLS_NHSR'
    )
)
uk <- nhsr[uk, on = 'NHSO']
# check totals NHSR: UK 10, E 7, W 1 (pseudo), S 1 (pseudo), N 1 (pseudo)
get_summary_area('NHSR')

#### G) Missing codes -----------------

message('Replacing missing PCON from similar LSOA, then MSOA...')
fill_missing_oas('PCON', 'LSOA')
fill_missing_oas('PCON', 'MSOA')

message('Replacing missing WARD from similar LSOA, then MSOA...')
fill_missing_oas('WARD', 'LSOA')
fill_missing_oas('WARD', 'MSOA')


### recode all fields as factor, then save in fst format ------------------------------------------------------------------------------------
message('Save as fst...')
cols <- dbm_do('geography_uk', 'q', strSQL = 'SELECT * FROM output_areas LIMIT 0')
cols <- intersect(names(cols), names(uk))
setcolorder(uk, cols)
uk[, (cols) := lapply(.SD, factor), .SDcols = cols]
write_fst(uk, file.path(geouk_path, 'output_areas'))

# save summary table
y <- dcast(rbindlist(lapply(names(uk), function(x) cbind(type = x, unique(uk[, .(CTRY, get(x))])[, .N, CTRY]))), type~CTRY)
y <- cbind(y, 'TOTAL' = rowSums(y[, 2:5]))
fwrite(y, file.path(geo_path, 'summary_oas.csv'))

#### CLEAN AND EXIT -----------------------------
message('DONE!')
rm(list = ls())
gc()
