#################################
# UK GEOGRAPHY * 11 - POSTCODES #
#################################

# SETUP -----------------------------------------

# check latest @ https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=-modified&tags=PRD_ONSPD
url_ons <- 'https://www.arcgis.com/sharing/rest/content/items/5ec8889d7e3b4d77a9f77ab8ec27d2c2/data'
# check latest FULL @ https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=-modified&tags=PRD_NHSPD
url_nhs <- 'https://www.arcgis.com/sharing/rest/content/items/d7b33b66949b4bc9b9065de7544ae4d1/data'

pkgs <- c('dmpkg.funs', 'data.table', 'sp')
invisible(lapply(pkgs, require, char = TRUE))

setDTthreads(10)

gpath <- file.path(ext_path, 'uk', 'geography')
pc_path <- file.path(gpath, 'postcodes')
lc_path <- file.path(gpath, 'locations')
lk_path <- file.path(gpath, 'lookups')

get_file <- function(x, exp_name = 'ONSPD', pc_path = pc_path){
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

add_geo2pc <- function(furl, onsid, tpe, save_names = NULL, del_col = FALSE, update_col = FALSE){
    y <- lookup_postcodes_shp(furl, onsid, tpe, save_names)
    message('Adding new column to postcodes dataset...')
    if(update_col){
        dt_update(pc, y)
    } else {
        if(del_col) pc[, (tpe) := NULL]
        y[pc, on = 'PCU']
    }
}

# ONSPD -----------------------------------------

# get_file(url_ons)

message('Loading ONSPD data...')
pc <- fread(
    file.path(pc_path, 'ONSPD.csv'), 
    select = c(
       'pcd', 'osgrdind', 'doterm', 'usertype', 'long', 'lat', 
       'oa11', 'lsoa11', 'msoa11', 'oslaua', 'oscty', 'rgn', 'ctry',
       'ttwa', 'osward', 'pcon', 'ced', 'parish', 'bua11', 'buasd11', 'wz11',
       'pfa', 'ccg', 'stp'
    ),
    col.names = c(
        'PCU', 'osgrdind', 'is_active', 'usertype', 'x_lon', 'y_lat',
        'OA', 'LSOA', 'MSOA', 'LAD', 'CTY', 'RGN', 'CTRY', 
        'TTWA', 'WARD', 'PCON', 'CED', 'PAR', 'BUA', 'BUAS', 'WPZ', 'PFA', 'CCG', 'STP'
    ),
    na.string = '',
    key = 'PCU'
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

message('Deleting postcodes without grid reference (osgrdind == 9, deletes also GI/IM), then reorder by OA and PCU...')
pc <- pc[osgrdind < 9][, osgrdind := NULL][order(OA, PCU)]

message('Recoding "is_active" as binary 0/1...')
pc[, is_active := ifelse(is.na(is_active), 1, 0)]

message('Saving list of missing OAs plus OAs with no live postcodes')
oas <- fst::read_fst(file.path(geouk_path, 'output_areas'), columns = 'OA', as.data.table = TRUE)
fwrite(
    rbindlist(list( 
        oas[!OA %in% unique(pc$OA), .(OA, status = NA)], 
        pc[, .(status = sum(is_active)), OA][status == 0] 
    ))[order(OA)], 
    file.path(geouk_path, 'missing+empty_OAs.csv')
)

message('Setting "is_active" = 1 for all postcodes in output areas that only include inactive pc...')
pc[!OA %in% unique(pc[is_active == 1, OA]), is_active := 1]

message('Set PCD AB1/AB2/AB3 as terminated...')
pc[substr(PCU, 1, 4) %in% paste0('AB', 1:3, ' '), is_active := 0]

message('Calculate PC Area codes from active postcodes...')
pc[is_active == 1, PCA := sub('[0-9]', '', substr(PCU, 1, gregexpr("[[:digit:]]", PCU)[[1]][1] - 1) ) ]
message('Calculate PC Districts codes from postcodes...')
pc[is_active == 1, PCD := gsub(' .*', '', substr(PCU, 1, 4)) ]
message('Calculate PC Sectors codes from postcodes...')
pc[is_active == 1, PCS := substr(PCU, 1, 5) ]

# ==> PCS + PCD + PCT + PCA for terminated PCU are calculated afterwards with PiP on the new PCS boundaries

message('Deleting records associated witn non-geographic PC Sectors...') # check if csv file needs updating, only for FEB and AUG issues
message(' - Number of OAs before deletion: ', unique(pc[is_active == 1, .(OA)])[,.N])
message('   ...')
ng <- read.csv(file.path(pc_path, 'pcs_non_geo.csv'))
pc <- pc[!PCS %in% ng$PCS]
message(' - Number of OAs after deletion: ', unique(pc[is_active == 1, .(OA)])[,.N])

message('Saving a version as SpatialPoints...')
y <- pc[, .(PCU, x_lon, y_lat, is_active, OA, RGN, CTRY)]
coordinates(y) <- ~x_lon+y_lat
proj4string(y) <- crs.wgs
saveRDS(y, file.path(geouk_path, 'postcodes.geo'))
rm(y)

message('Adding correct order to PC Districts and save as csv file...')
pcd <- unique(pc[is_active == 1 & !PCU %in% pc[grep('^[A-Z]{3}', PCU), PCU], .(PCD)])[order(PCD)]
pcd[, `:=`( 
    PCDa = regmatches(pcd$PCD, regexpr('[a-zA-Z]+', pcd$PCD)), 
    PCDn = as.numeric(regmatches(pcd$PCD, regexpr('[0-9]+', pcd$PCD))) 
)]
pcd <- pcd[order(PCDa, PCDn)][, ordering := 1:.N][, .(PCD, ordering)]
fwrite(pcd, file.path(lc_path, 'PCD.csv'), row.names = FALSE)
pc[, PCD := factor(PCD, levels = pcd$PCD)]

message('Adding correct order to PC Sectors and save as csv file...')
pcs <- unique(pc[is_active & !is.na(PCD) & !PCU %in% pc[grep('^[A-Z]{3}', PCU), PCU], .(PCD, PCS)])
pcs <- pcs[pcd, on = 'PCD']
pcs <- pcs[order(ordering, PCS)][, ordering := 1:.N][, .(PCS, ordering)]
fwrite(pcs, file.path(lc_path, 'PCS.csv'), row.names = FALSE)
pc[, PCS := factor(PCS, levels = pcs$PCS)]

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
fwrite(pca, file.path(pc_path, 'pca_totals.csv'), row.names = FALSE)

message('Changing pseudo-codes to NA...')
cols <- c('MSOA', 'CTY', 'RGN', 'CED', 'PAR', 'BUA', 'BUAS', 'PFA', 'STP')
pc[,
    (cols) := lapply(.SD, function(x)
        ifelse( x %in% c('E99999999', 'N99999999', 'S99999999', 'W99999999', 'E34999999', 'W37999999', 'E35999999', 'W38999999'), NA, x)
    ),
    .SDcols = cols
]

message('Fixing PFA...')
pc[PFA == 'S23000009', PFA := 'SCO_PFA']
pc[is.na(PFA), PFA := 'NIE_PFA']

message('Fixing CTRY and RGN...')
pc[, CTRY := substr(CTRY, 1, 1)]
ctry <- data.table( 'old' = c('E', 'W', 'S', 'N'), 'CTRY' = c('ENG', 'WLS', 'SCO', 'NIE') )
pc <- ctry[pc, on = c(old = 'CTRY')][, old := NULL]
pc[is.na(RGN), RGN := paste0(CTRY, '_RGN')]


# NHSPD -----------------------------------------
# get_file(url_nhs, exp_name = 'NHSPD')

message('Loading NHSPD data...')
nhspd <- fread( 
    file.path(pc_path, 'NHSPD.csv'), 
    header = FALSE,
    select = c(1, 17, 24), 
    col.names = c('PCU', 'nhsr', 'nhso'), 
    na.string = ''
)

message('Recoding postcode in 7-chars form...')
nhspd[, PCU := paste0(substr(PCU, 1, 4), substring(PCU, 6))]

message('Changing codes from NHS to ONS...') # check csv files with NHS if there are any updates
y <- fread(file.path(lc_path, 'NHSO.csv'), select = 1:2, col.names = c('NHSO', 'nhso'))
nhspd <- y[nhspd, on = 'nhso'][, nhso := NULL]
y <- fread(file.path(lc_path, 'NHSR.csv'), select = 1:2, col.names = c('NHSR', 'nhsr'))
nhspd <- y[nhspd, on = 'nhsr'][, nhsr := NULL]

message('Joining ONS and NHS files together...')
pc <- nhspd[pc, on = 'PCU']


# ADDITIONAL GEOGRAPHIES ------------------------

message('\nAdding MTC Major Towns and Cities (Dec-2015)...')
pc <- add_geo2pc('https://opendata.arcgis.com/datasets/5048387903bc49ca964cf04cd42b790d_0.zip', 'TCITY15CD', 'MTC', 'TCITY15NM')

message('\nAdding CSP - Community Safety Partnership (Dec-2019)...')
pc <- add_geo2pc('https://opendata.arcgis.com/datasets/27f5aaeec7004397a7d1f3e4eed07d20_0.zip', 'CSP19CD', 'CSP', 'CSP19NM')

message('\nAdding LPA - Local Planning Authorities (Apr-2020)...')
pc <- add_geo2pc('https://opendata.arcgis.com/datasets/cc5941be78a8458393a03c69518b2bf9_0.zip', 'LPA19CD', 'LPA', 'LPA19NM')

message('\nAdding FRA - Fire Rescue Authorities (Dec-2019)...')
pc <- add_geo2pc('https://opendata.arcgis.com/datasets/29f3bae4f73d4b4da93a044f31b9bae8_0.zip', 'FRA19CD', 'FRA', 'FRA19NM')

message('\nAdding RGD - Registration Districts (Apr-2019)...')
pc <- add_geo2pc('https://opendata.arcgis.com/datasets/2c8500677c9842dda758c0e494d782d5_0.zip', 'regd19cd', 'RGD', 'regd19nm')

message('\nAdding LRF - Local Resilience Forums (Dec-2019)...')
pc <- add_geo2pc('https://opendata.arcgis.com/datasets/f93348856f0649e98e3a670199245e92_0.zip', 'LRF19CD', 'LRF', 'LRF19NM')

message('\nAdding CIS - Covid Infection Survey (Oct-2020)...')
pc <- add_geo2pc('https://opendata.arcgis.com/datasets/c424a13a9da640c7b0ba8f8fc8f7aedf_0.zip', 'CIS20CD', 'CIS')


# UPDATED GEOGRAPHIES ---------------------------

message('\nUpdating Local Authorities Districts (Dec-2020)...')
pc <- add_geo2pc('https://opendata.arcgis.com/datasets/3b374840ce1b4160b85b8146b610cd0c_0.zip', 'LAD20CD', 'LAD', 'LAD20NM', TRUE)
y <- pc[ LSOA %in% pc[is.na(LAD), LSOA], .N, .(LSOA, LAD)]
y <- y[ y[, .I[which.max(N)], LSOA ]$V1, 1:2 ]
pc <- pc[is.na(LAD) , LAD := y[.SD[['LSOA']], .(LAD), on = 'LSOA'] ]
pc <- dt_update(pc, y)

message('\nUpdating Electoral Wards (Dec-2020)...')
pc <- add_geo2pc('https://opendata.arcgis.com/datasets/4b2425598a1d491f81e53f76a741c334_0.zip', 'WD20CD', 'WARD', 'WD20NM', TRUE)
y <- pc[ OA %in% pc[is.na(WARD), OA], .N, .(OA, WARD)]
y <- y[ y[, .I[which.max(N)], OA ]$V1, 1:2 ]
pc <- pc[is.na(WARD) , WARD := y[.SD[['OA']], .(WARD), on = 'OA'] ]
pc <- dt_update(pc, y)
pc[OA == 'S00097491', WARD := 'S13002882'] # LSOA: S01007526 
pc[OA == 'S00129989', WARD := 'S13003091'] # LSOA: S01012480

message('\nUpdating Parishes and Non Civil Parished Areas (Dec-2020)...')
pc <- add_geo2pc('https://opendata.arcgis.com/datasets/eb0624d6fd1f499ea352f450df70b5f7_0.zip', 'PARNCP20CD', 'PAR', 'PARNCP20NM', FALSE, TRUE)

message('\n - Adding Scottish PARishes...')
y <- lookup_postcodes_shp('https://www.nrscotland.gov.uk/files/geography/products/CivilParish1930.zip', 'C91code1', 'PAR')
y <- y[!is.na(PAR)][, PAR := paste0('S040', PAR)]
pc <- pc[CTRY == 'SCO' , PAR := y[.SD[['PCU']], .(PAR), on = 'PCU'] ]


# ADD PCT Post Towns ----------------------------

message('\nAdding PCT - Post Town... (did you remember to update the lookups file?)')
pcdt <- fread(file.path(lk_path, 'PCD_to_PCT.csv'), select = c('PCD', 'PCT'))
pc <- pcdt[pc, on = 'PCD']

# ADD PFN Police Neighbourhood ------------------

message('\nAdding PFN - Police Force Neighborhood...')
message(' - loading boundaries...  (did you remember to update the boundaries?)')
nbnd <- rgdal::readOGR(file.path(gpath, 'boundaries', 'shp'), 'PFN')
message(' - filtering out Scotland...')
pcn <- pc[CTRY != 'SCO', .(PCU, x_lon, y_lat)]
message(' - converting ENW postcodes into a spatial points object...')
coordinates(pcn) <- ~x_lon+y_lat
proj4string(pcn) <- crs.wgs
message(' - performing Points in Polygon...')
y <- over(pcn, nbnd)
message(' - merging into postcodes...')
pc <- setDT(cbind(pcn@data, y))[pc, on = 'PCU']
setnames(pc, 'id', 'PFN')

# check voids using a map overlaying MSOA
# bnd <- sp::merge(nbnd, neighs, by.x = 'id', by.y = 'PFN')
# mp <- basemap(bnd = bnd, bndid = 'PFNn') 
# lsoa <- readRDS(file.path(bnduk_spath, 'LSOA'))
# lsoa <- subset(lsoa, substr(lsoa$id, 1, 1) != 'S')
# mp <- mp %>% leaflet::addPolygons(data = lsoa, fillOpacity = 0, color = 'black', label = ~id)
# pcna <- pc[CTRY != 'SCO' & is.na(PFN), .(PCU, x_lon, y_lat, LSOA, MSOA)]
# mp <- mp %>% leaflet::addCircles(data = pcna, lng = ~x_lon, lat = ~y_lat, fillOpacity = 1, color = 'black', label = ~paste(LSOA, MSOA))

# FIX NOVEMBER 2020 
pc[MSOA %in% c('E02003645', 'E02003646', 'E02003647', 'E02003648', 'E02003649', 'E02003651'), PFN := 'E23000026_007'] # Dunstable Town
pc[LSOA %in% c('E01017586', 'E01017587'), PFN := 'E23000026_007'] # Dunstable Rural
pc[LSOA %in% c('W01000614', 'W01000622'), PFN := 'W15000004_014']

# HEATHROW NON TERMINALS
pc[is.na(PFN) & LSOA %in% c('E01002443', 'E01002444'), PFN := 'E23000001_659']

message(' - adding PFN to missing postcode using similar LSOA...')
y <- unique(pc[!is.na(PFN) & LSOA %in% unique(pc[CTRY != 'SCO' & is.na(PFN), LSOA]), .N, .(LSOA, PFN)])[order(LSOA, -N)]
yd <- y[LSOA %in% y[, .N, LSOA][N > 1, LSOA]]
y <- rbindlist(list( y[LSOA %in% y[, .N, LSOA][N == 1, LSOA], .(LSOA, PFN)] , yd[yd[, .I[which.max(N)], .(LSOA)]$V1, .(LSOA, PFN)] ))
pc <- dt_update(pc, y)

message(' - adding Scottish PFN/PFA as mapping from LADs/WARDs...')
y <- fread(file.path(lk_path, 'SCO_LAD_PFA.csv'))
pc <- dt_update(pc, y)
pc[WARD == 'S13002914', PFA := 'S32000018']
pc[WARD == 'S13002934', PFA := 'S32000012']
pc[WARD == 'S13003133', PFA := 'S32000018']
y <- unique(pc[CTRY == 'SCO', .(WARD, PFA)])[order(PFA, WARD)]
y[, PFN := paste0(PFA, '_', stringr::str_pad(1:.N, 3, 'left', '0')), PFA][, PFA := NULL]
pc <- dt_update(pc, y)
fwrite(y, file.path(lk_path, 'SCO_WARD_PFN.csv'))

# save lookups and postcodes dataset
fwrite(pc[, .(PCU, PFN)], file.path(lk_path, 'PCU_to_PFN.csv'))

# FINAL CHECK -----------------------------------

# reorder columns according to general hierarchy schema
cols <- c(
    'OA', 'LSOA', 'MSOA', 'LAD', 'CTY', 'RGN', 'CTRY', 'WPZ',
    'TTWA', 'WARD', 'PCON', 'CED', 'PAR',
    'MTC', 'BUA', 'BUAS',
    'PCS', 'PCD', 'PCT', 'PCA',
    'PFN', 'PFA', 'FRA', 'CSP', 'LPA', 'RGD', 'LRF',
    'CCG', 'STP', 'NHSO', 'NHSR', 'CIS'
)
setcolorder(pc, c('PCU', 'is_active', 'usertype', 'x_lon', 'y_lat', cols))

message('\nBuilding various counts for potential country mismatches and small areas overlapping for all geographies...')
pc[pc == ''] <- NA
tot <- lapply(cols, function(x) pc[!is.na(get(x)), .N, get(x)][order(get)] )
names(tot) <- cols
acro <- lapply(cols, function(x) unique(pc[!is.na(get(x)), .(X = substr(get(x), 1, 3), CTRY)]) )
names(acro) <- cols
mm <- lapply(cols, function(x) pc[, .(X = get(x), CTRY)][!is.na(X)][, .N, .(CTRY, X)][, .N, CTRY])
ovc <- lapply(cols, function(x) pc[is_active == 1, .(OA, X = get(x))][!is.na(X)][, .N, .(OA, X)][order(OA, -N)])
names(mm) <- cols -> names(ovc) 
ov <- lapply(cols, function(x) ovc[[x]][, .N, OA][N > 1])
names(ov) <- cols
ovf <- lapply(cols, function(x) ovc[[x]][OA %in% ov[[x]][, OA]])
names(ovf) <- cols
ovu <- lapply(cols, function(x) ovf[[x]][ ovf[[x]][, .I[which.max(N)], OA ]$V1, 1:2 ])
names(ovu) <- cols

# fixing mismatches between countries and overlapping between small areas and some upper levels...
pc[CTRY == 'WLS', CIS := NA]
pc[CTRY == 'ENG' & FRA == 'W25000002', FRA := 'E31000032']
pc[OA == 'E00070946', `:=`( WARD = 'E05009473', PAR = 'E04000793', LPA = 'E60000113', RGD = 'E28000139' )]
pc[OA == 'E00147247', `:=`( WARD = 'E05008163', PAR = 'E04011304', LPA = 'E60000114', RGD = 'E28000183' )]
pc[OA %in% c('E00113093', 'E00113175', 'E00113231', 'E00113232', 'E00113240'), RGD := 'E28000135']
pc[OA %in% c('E00070771', 'E00070788', 'E00070846', 'E00070942', 'E00070953'), RGD := 'E28000139']
pc[LSOA %in% c('E01028864', 'E01028866', 'E01028888', 'E01028896', 'E01028910', 'E01028920', 'E01028925', 'E01028979', 'E01028991', 'E01033530'), RGD := 'E28000183']
pc[OA == 'W00001769', LPA := 'W43000006']
pc[LSOA %in% c('W01000329', 'W01000330'), RGD := 'W20000001']
pc[LSOA %in% c('W01000346'), RGD := 'W20000004']
pc[LSOA %in% c('W01001548', 'W01001583'), RGD := 'W20000013']
pc[LSOA %in% c('W01000417', 'W01000427', 'W01000434', 'W01000441', 'W01000443', 'W01000446', 'W01000449', 'W01001907', 'W01000484', 'W01000485', 'W01000497'), RGD := 'W20000038']
pc[OA == 'E00005337', `:=`( 
                RGN = 'E12000007', WARD = 'E05011469', PCON = 'E14000656', PAR = 'E43000198',
                PFA = 'E23000001', FRA = 'E31000046', CSP = 'E22000193', LPA = 'E60000207', LRF = 'E48000021',
                CTY = NA, CED = NA 
)]
for(x in c('LAD', 'FRA', 'CSP', 'LRF', 'CCG', 'NHSO', 'NHSR')){
    message('Fixing overlapping between OA and ', x, '...')
    y <- ovu[[x]]
    setnames(y, c('OA', x))
    pc <- dt_update(pc, y)
}

# SAVE  -----------------------------------------
message('Recoding columns as factors...')
cols <- setdiff(cols, c('PCS', 'PCD'))
pc[, (cols) := lapply(.SD, factor), .SDcols = cols]
pc[, PCD := factor(PCD, levels = pcd$PCD)]

message('Saving postcodes with various indices...')
save_postcodes(pc, TRUE)

# Closing ---------------------------------------

message('DONE! Cleaning...')
rm(list = ls())
gc()
