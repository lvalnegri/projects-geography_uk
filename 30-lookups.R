###############################################################
# 30- LOOKUPS
###############################################################

## Load packages ----------------------------------------------------------------------------------------------------------------
pkg <- c('data.table', 'RMySQL', 'readODS', 'readxl')
invisible(lapply(pkg, require, character = TRUE))

## Define variables and functions -----------------------------------------------------------------------------------------------
data_path <- 
    if (substr(Sys.info()['sysname'], 1, 1) == 'W') {
        'D:/cloud/OneDrive/data/UK/geography/lookups/'
    } else {
        '/home/datamaps/data/UK/geography/lookups/'
    }

build_lookups_table <- function(child, parent, 
                                use_csv = FALSE, 
                                csv_path = NULL, 
                                csv_fn = 'ONSPD',
                                use_pip = FALSE,        # when TRUE uses Point-In-Point 
                                boundaries_path = NULL, # to be considered only when "use_pip" is TRUE
                                filter_country = NULL,
                                save_results = FALSE,
                                out_path = NULL
                        ){
    # - Build a lookup table child <=> parent using the postcodes CSV / DB (see file 10)
    # - This function should not be used with 'OA' as child and "use_csv" = TRUE because in the files from ONS there are 265 OAs missing (36 ENG, 229 SCO) 
    # - Always remember to check column 'pct' for values less than 100
    #
    library(data.table)
    if(use_csv){
        if(is.null(csv_path))
            data_path <- 
                if (substr(Sys.info()['sysname'], 1, 1) == 'W') {
                    'D:/cloud/OneDrive/data/UK/geography/postcodes/'
                } else {
                    '/home/datamaps/data/UK/geography/postcodes/'
                }
        if(substr(csv_path, nchar(csv_path), nchar(csv_path)) != '/') csv_path <- paste0(csv_path, '/')
        postcodes <- fread(paste0(csv_path, 'ONSPD.csv'), select = c('osgrdind', child, parent) )
        postcodes <- postcodes[osgrdind < 9]
        postcodes[, osgrdind := NULL]
    } else {
        library(RMySQL)
        dbc <- dbConnect(MySQL(), group = 'dataOps', dbname = 'geography_uk')
        postcodes <- data.table(dbGetQuery(dbc, 
                            paste(
                                "SELECT", child, ",", parent, "FROM postcodes", 
                                ifelse(is.null(filter_country), "", paste0("WHERE LEFT(CTRY, 1)  = '", substr(filter_country, 1, 1), "'") ) 
                            )
        ))
        dbDisconnect(dbc)
    }
    setnames(postcodes, c('child', 'parent'))
    y <- unique(postcodes[, .(child, parent)])[, .N, child][N == 1][, child]
    if(length(y) > 0) 
        y1 <- unique(postcodes[child %in% y, .(child, parent, pct = 100)])
    y <- unique(postcodes[, .(child, parent)])[, .N, child][N > 1][, child]
    if(length(y) > 0)
        y2 <- postcodes[child %in% y][, .N, .(child, parent)][order(child, -N)][, pct := round(100 * N / sum(N), 2), child][, .SD[1], child][, .(child, parent, pct)]
    if(!exists('y1')){
        y <- y2   
    } else if(!exists('y2')){
        y <- y1
    } else {
        y <- rbindlist(list(y1, y2))
    }
    y <- y[order(child)]
    setnames(y, c(child, parent, 'pct'))
    if(save_results){
        if(is.null(out_path))
            out_path <- 
                if (substr(Sys.info()['sysname'], 1, 1) == 'W') {
                    'D:/cloud/OneDrive/data/UK/geography/lookups/'
                } else {
                    '/home/datamaps/data/UK/geography/lookups/'
                }
        if(substr(out_path, nchar(out_path), nchar(out_path)) != '/') out_path <- paste0(out_path, '/')
        write.csv(y, paste0(out_path, child, '_to_', parent, '.csv'), row.names = FALSE)
    }
    return(y)
}


#### A) Census hierachy: Output Area to LSOA, MSOA, LAD, CTY, RGN, CTRY ---------------------------------------------------------

### Preliminary Notes:
# OA are called Small Areas in Northern Ireland
# LSOA are called Data zones in Scotland and Small Output Areas in Northern Ireland
# MSOA are called Intermediate zones in Scotland. MSOA does not exist for Northern Ireland
# Counties and Regions exists only for England

### 1 - OA ==> LSOA (We can't build the complete lookups from postcodes because there are 265 OAs missing: E 36, S 229)

## England and Wales
# download lookup tables in zip file ===> DON'T KNOW THE LINK!
# download.file('', 'lookups.zip')
# extract the correct CSV file
# unzip('lookups.zip', '')
# read lookup data
eng <- fread(paste0(data_path, 'EW/OA11_LSOA11_MSOA11_LAD11_EW_LUv2.csv'), select = 1:2, col.names = c('OA', 'LSOA'))
    
## Scotland
# download lookup tables
download.file('http://www.gov.scot/Resource/0046/00462936.csv', 'lookups.csv')
# read lookup data
sco <- fread('lookups.csv', select = 1:2, col.names = c('OA', 'LSOA'))

## N.Ireland    
# download lookup tables
download.file('http://www.ninis2.nisra.gov.uk/Download/People%20and%20Places/Geographic%20Data%20(statistical%20geographies).ods', 'lookups.csv')
# read lookup data
nie <- read_ods('lookups.csv', sheet = 1, skip = 4)
nie <- nie[, 1:2]

### UK
# union of the previous dataframes
uk <- rbindlist(list(eng, sco, nie))
# check totals OA: UK 232,296, E 171,372, W 10,036, S 46,351, N 4,537
uk[, .N, substr(OA, 1, 1)]
# check totals LSOA: UK 42,619, E 32,844, W 1,909, S 6,976, N 890
unique(uk[, .(LSOA)])[, .N, substr(LSOA, 1, 1)]

### 2 - MSOA
# build from 'postcodes' table using 'LSOA' as base
t <- build_lookups_table('LSOA', 'MSOA')
# merge with previous OA->LSOA
uk <- uk[t[, 1:2], on = 'LSOA']
# check totals MSOA: UK 8,480, E 6,791, W 410, S 1,279, N NA
unique(uk[, .(MSOA)])[, .N, substr(MSOA, 1, 1)]

### 3 - LAD 
# build from 'postcodes' table using 'LSOA' as base
t <- build_lookups_table('LSOA', 'LAD')
# merge with previous OA->LSOA->MSOA
uk <- uk[t[, 1:2], on = 'LSOA']
# check totals LAD: UK 391, E 326, W 22, S 32, N 11
unique(uk[, .(LAD)])[, .N, substr(LAD, 1, 1)]

### 4 - CTY (see below end of step 6 for a needed recoding)
download.file('https://opendata.arcgis.com/datasets/180a69233de94a8da3fb6a8a4959fcc7_0.csv', 'lookups.csv')
# read lookup data
t <- fread('lookups.csv', select = c(1, 3), col.names = c('LAD', 'CTY'))
# merge with previous OA->LSOA->MSOA
uk <- t[, 1:2][uk, on = 'LAD']
# check totals CTY: UK , E , W NA, S NA, N NA
unique(uk[, .(CTY)])[, .N, substr(CTY, 1, 1)]

### 5 - RGN
# build from 'postcodes' table using 'LSOA' as base
t <- build_lookups_table('LSOA', 'RGN')
# merge with previous OA->LSOA->MSOA
uk <- uk[t[, 1:2], on = 'LSOA']
# check totals CTY: UK 9, E 9, W NA, S NA, N NA
unique(uk[, .(RGN)])[, .N, substr(RGN, 1, 1)]
# recode fake regional CTY for English UA (E06): take regional code and substitute 8th char with '9'
uk[substr(LAD, 1, 3) == 'E06', CTY := sub("(.{7}).", "\\19", RGN)]

### 6 - RGN ==> CTRY
# build from 'postcodes' table using 'LSOA' as base
t <- build_lookups_table('LSOA', 'CTRY')
# merge with previous OA->LSOA->MSOA
uk <- uk[t[, 1:2], on = 'LSOA']
# check totals CTRY: UK 4, E 1, W 1, S 1, N 1
unique(uk[, .(CTRY)])[, .N, substr(CTRY, 1, 1)]

setcolorder(uk, c('OA', 'LSOA', 'MSOA', 'LAD', 'CTY', 'RGN', 'CTRY'))
census <- uk[order(OA)]
write.csv(uk, 'OA_census.csv', row.names = FALSE)


#### B) Statistics hierarchy: Output Area to BUAS, BUA (E only) -----------------------------------------------------------------

# download lookup tables in zip file ===> DON'T KNOW THE LINK!
# download.file('', 'lookups.zip')
# extract the correct CSV file
# unzip('lookups.zip', '')
# read lookup data
bua <- fread(paste0(data_path, 'EW/OA11_BUASD11_BUA11_LAD11_RGN11_EW_LU.csv'), select = c(1, 2, 4), col.names = c('OA', 'BUAS', 'BUA'))
bua <- bua[census[, .(OA)], on = 'OA']
bua[bua == ''] <- NA
# check totals BUAS: UK 1,693; E 1,539, W 150, K 4. Considering also the below BUA without BUAS: UK 6,621; E 6,085, W 525, K 11
unique(bua[, .(BUAS)])[, .N, substr(BUAS, 1, 1)]
# check totals BUA: UK 5,493; E 5,055, W 427, K 11
unique(bua[, .(BUA)])[, .N, substr(BUA, 1, 1)]
# check BUA with subs: UK 565; E 509, W 52, K 4 (64 of these have no population: E 58, W 6, K 0)
unique(bua[!is.na(BUAS), .(BUA)])[, .N, substr(BUA, 1, 1)]
# check BUA without subs: UK 4,928; E 4,546, W 375, K 7
unique(bua[is.na(BUAS), .(BUA)])[, .N, substr(BUA, 1, 1)]


#### C) administrative hierarchy: Output Area to MTC, WARD, PCON, PFA, TTWA, PAR ------------------------------------------------

### 1- OA => MTC (Major Towns and Cities) (starting from OA results in a few MTCs having multiple LSOAs)
# download lookup tables in zip file ===> DON'T KNOW THE LINK!
# download.file('', 'lookups.zip')
# extract the correct CSV file
# unzip('lookups.zip', '')
# read lookup data
admin <- fread(paste0(data_path, 'EW/Output_Area_2011_to_Major_Towns_and_Cities_December_2015_Lookup_in_England_and_Wales.csv'), select = 1:2, col.names = c('OA', 'MTC'))
admin <- admin[census[, .(OA, LSOA)], on = 'OA']
admin[admin == ''] <- NA
# check totals MTC: E 109, W 4
unique(admin[!is.na(MTC), .(CTRY = substr(OA, 1, 1), MTC)])

### 2- OA => WARD
# read lookup data
t <- fread('https://opendata.arcgis.com/datasets/cc93d1e3d0e249288e6a845b87d7252d_0.csv', select = c(1, 3), col.names = c('LSOA', 'WARD') )
admin <- t[admin, on = 'LSOA']
# check totals WARD: E 7,427, W 842, S , N
unique(admin[, .(WARD)])[, .N, substr(WARD, 1, 1)]

### 3- OA => PCON (Parliamentary CONstituencies)
# read lookup data
t <- fread('', select = c(1, 3), col.names = c('LSOA', '') )
admin <- t[admin, on = 'LSOA']
# check totals : E , W , S , N
unique(admin[, .()])[, .N, substr(, 1, 1)]

### 4- OA => TTWA (Travel To Work Areas)
# read lookup data
t <- fread('', select = c(1, 3), col.names = c('LSOA', '') )
admin <- t[admin, on = 'LSOA']
# check totals : E , W , S , N
unique(admin[, .()])[, .N, substr(, 1, 1)]

### 5- OA => PAR (PARishes)
# read lookup data
t <- fread('', select = c(1, 3), col.names = c('LSOA', '') )
admin <- t[admin, on = 'LSOA']
# check totals : E , W , S , N
unique(admin[, .()])[, .N, substr(, 1, 1)]


#### D) Postcodes hierarchy: Output Area to PCS, PCD, PCA ----------------------------------------

### England and Wales
# download lookup tables in zip file
download.file('http://webarchive.nationalarchives.gov.uk/20160105160709/https://geoportal.statistics.gov.uk/Docs/Lookups/Output_areas_(2011)_to_enumeration_postcode_sectors_(2011)_E+W_lookup.zip', 'lookups.zip')
# extract the correct CSV file
unzip('lookups.zip', 'OA11_PCDS11_EW_LU.csv')
# read lookup data
eng <- fread('OA11_PCDS11_EW_LU.csv')

### Scotland
# download lookup tables in zip file
download.file('http://www.nrscotland.gov.uk/files//geography/2011-census-indexes-csv.zip', 'lookups.zip')
# extract the correct CSV file
unzip('lookups.zip', 'OA_TO_HIGHER_AREAS.csv')
# read lookup data
sco <- fread('OA_TO_HIGHER_AREAS.csv', select = c('OutputArea2011Code', 'PostcodeSector2011'))
# normalize PostcodeSector2011
norm.pcs <- Vectorize(function(PCS){
    PCS <- gsub(' ', '', PCS)
    x <- nchar(PCS)
    paste0( substr(PCS, 1, x - 1), paste(rep(' ', 5 - x), collapse = ''), substr(PCS, x, x) )
})
sco[, PostcodeSector2011 := norm.pcs(PostcodeSector2011)]

### N.Ireland (1448 are not perfect fit, see pct in nie data.table for further info)
nie <- build_lookups_table('OA', 'PCS', filter_country = 'N')
nie[, pct := NULL]

### UK
# union of the previous dataframes
uk <- rbindlist(list(eng, sco, nie))
# change names to dataframe
setnames(uk, c('OA', 'PCS'))
# create codes for postcode districts and areas
uk[, PCD := gsub(' ', '', substr(PCS, 1, 4) ) ]
uk[, PCA := sub('[0-9]', '', substr(PCS, 1, gregexpr("[[:digit:]]", PCS)[[1]][1] - 1) ) ]
# save final dataframe to  CSV file
write.csv(uk[order(OA)], paste0(data_path, 'OA_postcodes.csv'), row.names = FALSE)




#### E) police hierarchy: Output Area to PFN, PFA -------------------------------------------------------------------------------

### 1- OA => PFA (Police Force Areas)
# build from postcodes
police <- build_lookups_table('OA', 'PFA')
police <- police[census[, .(OA, LSOA)], on = 'OA']
# NI SA should be all NA, recode to N23000009 (????)
police[substr(OA, 1, 1) == 'N', PFA := 'N23000009']
# associate to the 265 missing OAs the PFA connected to their LSOA
police[ unique(police[!is.na(PFA) & LSOA %in% police[is.na(PFA), LSOA], .(LSOA, PFA)]), on = 'LSOA', PFA := i.PFA]
# check totals : E 39, W 4, S 1, N 1 
unique(police[, .(PFA)])[, .N, substr(PFA, 1, 1)]

### 2- OA => PFN (Police Force Neighborhood)

# see project: <crime_incidents_uk> / file: "36-police_neighbourhood.R"


#### F) EuroStat hierarchy: Output Area to LAU2, LAu1, NUTS3, NUTS2, NUTS1 ------------------------------------------------------

## England and Wales
# download lookup table
download.file('https://opendata.arcgis.com/datasets/fa693a3a3fd440339d962778909a3aa9_0.csv', 'lookups.csv')
# read lookup data
eng <- fread('lookups.csv', select = 1:2, col.names = c('OA', 'LAU2'))

## Scotland
# download lookup tables in zip file
download.file('http://www.nrscotland.gov.uk/files//geography/2011-census-indexes-csv.zip', 'lookups.zip')
# extract the correct CSV file
unzip('lookups.zip', 'OA_TO_HIGHER_AREAS.csv')
# read lookup data
sco <- fread('OA_TO_HIGHER_AREAS.csv', select = c('OutputArea2011Code', 'LAU2011Level2Code'))

## N.Ireland
nie <- build_lookups_table('OA', 'LAU2', filter_country = 'N')
nie[, pct := NULL]

## UK
# union of the previous dataframes
euro <- rbindlist(list(eng, sco, nie))
# check totals OA: UK 232,296, E 171,372, W 10,036, S 46,351, N 4,537
unique(euro[, .(LAU2)])[, .N, substr(LAU2, 1, 1)]
# download lookup table for higher levels localities ===> DON'T KNOW THE LINK!
# download.file('', 'lookups.zip')
# extract the correct CSV file
# unzip('lookups.zip', '')
# read lookup data
t <- read_excel(paste0(data_path, 'UK/LAU217_LAU117_NUTS315_NUTS215_NUTS115_UK_LU.xlsx'))
write.csv(uk, 'D:/cloud/OneDrive/data/UK/geography/lookups/OA_to_LAU.csv', row.names = FALSE)


### Clean & Exit ---------------------------------------------------------------------------------------------------------------
file.remove(c('lookups.csv', 'lookups.zip', 'OA11_PCDS11_EW_LU.csv', 'OA_TO_HIGHER_AREAS.csv') )
rm(list = ls())
gc()
