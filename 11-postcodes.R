#################################
# UK GEOGRAPHY * 11 - POSTCODES #
#################################

### load packages ---------------------------------------------------------------------------------------------------------------
pkg <- c('data.table', 'fst', 'RMySQL', 'tabulizer')
invisible(lapply(pkg, require, character.only = TRUE))

### set constants ---------------------------------------------------------------------------------------------------------------
pub_path <- Sys.getenv('PUB_PATH')
ext_path = file.path(pub_path, 'ext_data', 'uk', 'geography')
dts_path <- file.path(pub_path, 'datasets', 'uk', 'geography')

### define functions ------------------------------------------------------------------------------------------------------------
get_file <- function(x, exp_name = 'ONSPD', pc_path = file.path(ext_path, 'postcodes')){
    message('Downloading zip file...')
    tmp <- tempfile()
    download.file(x, destfile = tmp)
    fname <- unzip(tmp, list = TRUE)
    fname <- fname[order(fname$Length, decreasing = TRUE), 'Name'][1]
    message('Extracting csv file...')
    unzip(tmp, files = fname, exdir = pc_path, junkpaths = TRUE)
    unlink(tmp)
    system(paste0('mv ', pc_path, '/', basename(fname), ' ',  pc_path, '/', exp_name, '.csv'))
    message('Done!')
}

### LOAD ONSPD ------------------------------------------------------------------------------------------------------------------

# download latest @ http://geoportal.statistics.gov.uk/datasets?q=ONS+Postcode+Directory+(ONSPD)+zip&sort_by=updated_at
get_file('https://www.arcgis.com/sharing/rest/content/items/5194b0c9d5a042789058609a4435ec7c/data')

# load data
postcodes <- fread(
    file.path(ext_path, 'postcodes', 'ONSPD.csv'), 
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

# set is_active = 1 for all postcodes in output areas that only includes inactive postcodes
postcodes[!OA %in% unique(postcodes[is_active == 1, OA]), is_active := 1]

### Postcode Areas, Districts, Sectors ------------------------------------------------------------------------------------------

# calculate codes from postcodes
postcodes[, PCA := sub('[0-9]', '', substr(postcode, 1, gregexpr("[[:digit:]]", postcode)[[1]][1] - 1) ) ]
postcodes[, PCD := gsub(' .*', '', substr(postcode, 1, 4)) ]
postcodes[, PCS := substr(postcode, 1, 5) ]

# load non-geographic PCS. the file is updated Jan and Jul, check PAF website for the correct link www.poweredbypaf.com
y <- extract_tables('https://www.poweredbypaf.com/wp-content/uploads/2019/02/Jan-2019_current_non-geos-original.pdf')

# extract tables with data at the end
for(idx1 in 1:length(y)) if(nrow(y[[idx1]]) <= 2) break
for(idx2 in idx1:length(y)) if(nrow(y[[idx2]]) > 2) break
ng <- NULL
for(idx in idx2:length(y)) ng <- rbindlist(list(ng, data.table(y[[idx]])), fill = TRUE)

# recode PCS
ng <- ng[, .(PCS = gsub(' ', '', V2))]
ng[nchar(PCS) == 4, PCS := paste(substr(PCS, 1, 3), substring(PCS, 4))]
ng[nchar(PCS) == 3, PCS := paste0(substr(PCS, 1, 2), '  ', substring(PCS, 3))]

# store number of OAs for future check
n_OAs <- unique(postcodes[is_active == 1, .(OA)])[,.N]

# delete postcodes associated with non-geo PCS
postcodes <- postcodes[!PCS %in% ng$PCS]

# set is_active = 0 for postcodes in AB1, AB2, AB3
postcodes[PCD %in% c('AB1', 'AB2', 'AB3'), is_active := 0]

# delete postcodes related to non-geographic or post-box only PCS missed in PAF file
postcodes <- 
    postcodes[!PCD %in% 
        c(paste0('BN', 50:52), paste0('CF', 25:30), 'CR90', 'LE21', 'LE41', 'N1P', 'NW1W', 'NW26', 'SE1P', 'SL60', 'ST55')
    ]

# check total OAs after deletion is still the same
n_OAs == unique(postcodes[is_active == 1, .(OA)])[,.N]

# order postcode districts
pcd <- unique(postcodes[is_active == 1 & !postcode %in% postcodes[grep('^[A-Z]{3}', postcode), postcode], .(PCD)])[order(PCD)]
pcd[, `:=`( 
    PCDa = regmatches(pcd$PCD, regexpr('[a-zA-Z]+', pcd$PCD)), 
    PCDn = as.numeric(regmatches(pcd$PCD, regexpr('[0-9]+', pcd$PCD))) 
)]
pcd <- pcd[order(PCDa, PCDn)][, ordering := 1:.N][, .(PCD, ordering)]
fwrite(pcd, file.path(ext_path, 'locations', 'PCD.csv'), row.names = FALSE)

# order postcode sectors 
pcs <- unique(postcodes[is_active & !postcode %in% postcodes[grep('^[A-Z]{3}', postcode), postcode], .(PCD, PCS)])
pcs <- pcs[pcd, on = 'PCD']
pcs <- pcs[order(ordering, PCS)][, ordering := 1:.N][, .(PCS, ordering)]
fwrite(pcs, file.path(ext_path, 'locations', 'PCS.csv'), row.names = FALSE)

# check and save total Table 2 (remember that now postcodes without grid have been deleted)
pca <- rbindlist(list(
    postcodes[, .(
        PCD = uniqueN(PCD), 
        PCS = uniqueN(PCS), 
        live = sum(is_active), 
        terminated = sum(!is_active), 
        total = .N
    ), PCA][order(PCA)],
    postcodes[, .(
        PCA = 'TOTAL UK', 
        PCD = uniqueN(PCD), 
        PCS = uniqueN(PCS), 
        live = sum(is_active), 
        terminated = sum(!is_active), 
        total = .N
    )]        
))
fwrite(pca, file.path(ext_path, 'postcodes', 'pca_totals.csv'), row.names = FALSE)

# change pseudo-codes to NA
cols <- c('MSOA', 'CTY', 'RGN', 'CED', 'PAR', 'BUA', 'BUAS', 'PFA', 'STP')
postcodes[,
    (cols) := lapply(.SD, function(x)
        ifelse( x %in% c('E99999999', 'N99999999', 'S99999999', 'W99999999', 'E34999999', 'W37999999', 'E35999999', 'W38999999'), NA, x)
    ),
    .SDcols = cols
]

### LOAD NHSPD ------------------------------------------------------------------------------------------------------------------
# download latest @ http://geoportal.statistics.gov.uk/search?q=NHS%20Postcode%20Directory%20UK%20Full
get_file('https://www.arcgis.com/sharing/rest/content/items/fd3ffbae5dfe4b9db21070486c6a0d64/data', exp_name = 'NHSPD')

# load data
nhspd <- fread( 
    file.path(ext_path, 'postcodes', 'NHSPD.csv'), 
    header = FALSE,
    select = c(1, 12, 17, 24), 
    col.names = c('postcode', 'osgrdind', 'nhsr', 'nhso'), 
    na.string = ''
)

# delete non-geographic
nhspd <- nhspd[osgrdind < 9][, osgrdind := NULL]
# recode postcode in 7-chars form
nhspd[, postcode := paste0(substr(postcode, 1, 4), substring(postcode, 6))]
# load NHSO names to change codes from NHS to ONS
y <- fread(file.path(ext_path, 'locations', 'NHSO.csv'), select = 1:2, col.names = c('NHSO', 'nhso'))
nhspd <- y[nhspd, on = 'nhso'][, nhso := NULL]
# load NHSR names to change codes from NHS to ONS
y <- fread(file.path(ext_path, 'locations', 'NHSR.csv'), select = 1:2, col.names = c('NHSR', 'nhsr'))
nhspd <- y[nhspd, on = 'nhsr'][, nhsr := NULL]
# join with postcodes
postcodes <- nhspd[postcodes, on = 'postcode']

### add mosaic types ------------------------------------------------------------------------------------------------------------
mosaics <- fread(file.path(ext_path, 'postcodes', 'postcodes_mosaics.csv'))
y <- fread(file.path(pub_path, 'ancillaries', 'uk', 'geodemographics', 'mosaic_types.csv'), select = c('code_exp', 'code'))
mosaics <- y[mosaics, on = c(code_exp = 'mosaic_type')]
postcodes <- mosaics[, .(postcode, mosaic_type = code)][postcodes, on = 'postcode']

### save results in database ----------------------------------------------------------------------------------------------------
dbc <- dbConnect(MySQL(), group = 'geouk')
dbSendQuery(dbc, "TRUNCATE TABLE postcodes")
dbWriteTable(dbc, 'postcodes', postcodes, row.names = FALSE, append = TRUE)
pn <- dbGetQuery(dbc, 'SELECT * FROM postcodes LIMIT 0')
dbDisconnect(dbc)
setcolorder(postcodes, intersect(names(pn), names(postcodes)))

### recode as factors, then save results in fst format --------------------------------------------------------------------------
cols <- colnames(postcodes)
cols <- cols[which(names(postcodes) == 'OA'):length(cols)]
postcodes[, (cols) := lapply(.SD, factor), .SDcols = cols]
write.fst(postcodes, file.path(dts_path, 'postcodes'))

# CLEAN & EXIT ------------------------------------------------------------------------------------------------------------------
rm(list = ls())
gc()


