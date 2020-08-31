#################################
# UK GEOGRAPHY * 11 - POSTCODES #
#################################

# SETUP -----------------------------------------

# check latest @ https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=-modified&tags=PRD_ONSPD
url_ons <- 'https://www.arcgis.com/sharing/rest/content/items/a644dd04d18f4592b7d36705f93270d8/data'
# check latest FULL @ https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=-modified&tags=PRD_NHSPD
url_nhs <- 'https://www.arcgis.com/sharing/rest/content/items/b6e6715fa1984648b5e690b6a8519e53/data'

pkg <- c('popiFun', 'data.table')
invisible(lapply(pkg, require, char = TRUE))

ext_path <- file.path(pub_path, 'ext_data', 'uk', 'geography')

get_file <- function(x, exp_name = 'ONSPD', pc_path = file.path(ext_path, 'postcodes')){
    message('\nDownloading ', exp_name, ' zip file...\n')
    tmp <- tempfile()
    download.file(x, destfile = tmp)
    fname <- unzip(tmp, list = TRUE)
    fname <- fname[order(fname$Length, decreasing = TRUE), 'Name'][1]
    message('Extracting csv file...')
    unzip(tmp, files = fname, exdir = pc_path, junkpaths = TRUE)
    unlink(tmp)
    system(paste0('mv ', pc_path, '/', basename(fname), ' ',  pc_path, '/', exp_name, '.csv'))
    message('\nDone!\n')
}

# ONSPD -----------------------------------------

get_file(url_ons)

message('Loading ONSPD data...')
pc <- fread(
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

message('Building lookalike tables as Table 1 in User Guide:')
message(' + Total dataset...')
print(pc[, .N, CTRY][order(CTRY)])
message(' + Total UK...')
print(pc[!(CTRY %in% c('L93000001', 'M83000003')), .N])
message(' + By user type: 0-Small / 1-Large users for the whole dataset...')
print(pc[, .N, usertype][order(usertype)])
message(' + By user type: 0-Small / 1-Large users, Total UK ...')
print(pc[!(CTRY %in% c('L93000001', 'M83000003')), .N, usertype])
message(' + Countries by usertypes...')
print(dcast.data.table(pc[, .N, .(CTRY, usertype)][order(CTRY, usertype)], CTRY~usertype))

message('Building lookalike tables as Table 3 in User Guide:')
print(pc[osgrdind < 9, .N, CTRY][order(CTRY)])
print(dcast.data.table(pc[osgrdind < 9, .N, .(CTRY, usertype)][order(CTRY, usertype)], CTRY~usertype))

message('Deleting postcodes without grid reference (osgrdind == 9, deletes also GI/IM), then reorder by OA and postcode...')
pc <- pc[osgrdind < 9][, osgrdind := NULL][order(OA, postcode)]

message('Recoding "is_active" as binary 0/1...')
pc[, is_active := ifelse(is.na(is_active), 1, 0)]

message('Setting "is_active" = 1 for all postcodes in output areas that only includes inactive pc...')
pc[!OA %in% unique(pc[is_active == 1, OA]), is_active := 1]

message('Calculate PC Area codes from postcodes...')
pc[, PCA := sub('[0-9]', '', substr(postcode, 1, gregexpr("[[:digit:]]", postcode)[[1]][1] - 1) ) ]
message('Calculate PC Districts codes from postcodes...')
pc[, PCD := gsub(' .*', '', substr(postcode, 1, 4)) ]
message('Calculate PC Sectors codes from postcodes...')
pc[, PCS := substr(postcode, 1, 5) ]

message('Deleting records associated witn non-geographic PC Sectors...') # check if csv file needs updating, only for FEB and AUG issues
message(' - Number of OAs before deletion: ', unique(pc[is_active == 1, .(OA)])[,.N])
message('   ...')
ng <- read.csv(file.path(ext_path, 'postcodes', 'pcs_non_geo.csv'))
pc <- pc[!PCS %in% ng$PCS]
message(' - Number of OAs after deletion: ', unique(pc[is_active == 1, .(OA)])[,.N])

message('Adding correct order to PC Districts and save as csv file...')
pcd <- unique(pc[is_active == 1 & !postcode %in% pc[grep('^[A-Z]{3}', postcode), postcode], .(PCD)])[order(PCD)]
pcd[, `:=`( 
    PCDa = regmatches(pcd$PCD, regexpr('[a-zA-Z]+', pcd$PCD)), 
    PCDn = as.numeric(regmatches(pcd$PCD, regexpr('[0-9]+', pcd$PCD))) 
)]
pcd <- pcd[order(PCDa, PCDn)][, ordering := 1:.N][, .(PCD, ordering)]
fwrite(pcd, file.path(ext_path, 'locations', 'PCD.csv'), row.names = FALSE)

message('Adding correct order to PC Sectors and save as csv file...')
pcs <- unique(pc[is_active & !postcode %in% pc[grep('^[A-Z]{3}', postcode), postcode], .(PCD, PCS)])
pcs <- pcs[pcd, on = 'PCD']
pcs <- pcs[order(ordering, PCS)][, ordering := 1:.N][, .(PCS, ordering)]
fwrite(pcs, file.path(ext_path, 'locations', 'PCS.csv'), row.names = FALSE)

message('Saving a lookalike Table 2 User Guide (remember that now postcodes without grid have been deleted)...')
pca <- rbindlist(list(
    pc[, .(
        PCD = uniqueN(PCD), 
        PCS = uniqueN(PCS), 
        live = sum(is_active), 
        terminated = sum(!is_active), 
        total = .N
    ), PCA][order(PCA)],
    pc[, .(
        PCA = 'TOTAL UK', 
        PCD = uniqueN(PCD), 
        PCS = uniqueN(PCS), 
        live = sum(is_active), 
        terminated = sum(!is_active), 
        total = .N
    )]        
))
fwrite(pca, file.path(ext_path, 'postcodes', 'pca_totals.csv'), row.names = FALSE)

message('Changing pseudo-codes to NA...')
cols <- c('MSOA', 'CTY', 'RGN', 'CED', 'PAR', 'BUA', 'BUAS', 'PFA', 'STP')
pc[,
    (cols) := lapply(.SD, function(x)
        ifelse( x %in% c('E99999999', 'N99999999', 'S99999999', 'W99999999', 'E34999999', 'W37999999', 'E35999999', 'W38999999'), NA, x)
    ),
    .SDcols = cols
]

# NHSPD -----------------------------------------

get_file(url_nhs, exp_name = 'NHSPD')

message('Loading NHSPD data...')
nhspd <- fread( 
    file.path(ext_path, 'postcodes', 'NHSPD.csv'), 
    header = FALSE,
    select = c(1, 17, 24), 
    col.names = c('postcode', 'nhsr', 'nhso'), 
    na.string = ''
)

message('Recoding postcode in 7-chars form...')
nhspd[, postcode := paste0(substr(postcode, 1, 4), substring(postcode, 6))]

message('Changing codes from NHS to ONS...') # check csv files with NHS if there are any updates
y <- fread(file.path(ext_path, 'locations', 'NHSO.csv'), select = 1:2, col.names = c('NHSO', 'nhso'))
nhspd <- y[nhspd, on = 'nhso'][, nhso := NULL]
y <- fread(file.path(ext_path, 'locations', 'NHSR.csv'), select = 1:2, col.names = c('NHSR', 'nhsr'))
nhspd <- y[nhspd, on = 'nhsr'][, nhsr := NULL]

message('Joining ONS and NHS files together...')
pc <- nhspd[pc, on = 'postcode']

message('Saving dataset in database...')
dbm_do('geography_uk', 'w', 'postcodes', pc)
pn <- dbm_do('geography_uk', 'q', 'postcodes', strSQL = 'SELECT * FROM postcodes LIMIT 0')
setcolorder(pc, intersect(names(pn), names(pc)))

message('Recoding columns as factors...')
cols <- colnames(pc)
cols <- cols[which(names(pc) == 'OA'):length(cols)]
pc[, (cols) := lapply(.SD, factor), .SDcols = cols]

message('Saving dataset as fst with index over RGN and LAD...')
write_fst_idx('postcodes', c('RGN', 'LAD'), pc, geouk_path)

# Closing ---------------------------------------

message('DONE! Cleaning...')
rm(list = ls())
gc()
