###############################################################
# 30- LOOKUPS
###############################################################

#### 0- Generic function to build lookups for child vs parent areas from postcodes CSV / DB for UK ------------------------------

build.lookups.table <- function(child, parent, 
                                use.csv = FALSE, 
                                csv.path = 'D:/cloud/OneDrive/data/UK/geography/postcodes/', 
                                csv.fn = 'ONSPD',
                                filter.regions = NA,
                                save.results = FALSE,
                                out.path = 'D:/cloud/OneDrive/data/UK/geography/lookups/'
                        ){
    #
    # This function should not be used with 'OA' as child and "use.csv" = TRUE 
    # because in the postcodes file from ONS there are 265 OAs missing (36 ENG, 229 SCO) 
    #
    library(data.table)
    if(use.csv){
        if(substr(csv.path, nchar(csv.path), nchar(csv.path)) != '/') csv.path <- paste0(csv.path, '/')
        postcodes <- fread(paste0(csv.path, 'ONSPD.csv'), select = c('osgrdind', child, parent) )
        postcodes <- postcodes[osgrdind < 9]
        postcodes[, osgrdind := NULL]
    } else {
        library(RMySQL)
        db_conn <- dbConnect(MySQL(), group = 'local', dbname = 'geographyUK')
        postcodes <- data.table( dbGetQuery(db_conn, paste('SELECT ', child, ',', parent, 'FROM postcodes') ) )
        dbDisconnect(db_conn)
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
    setnames(y, c(child, parent, 'pct'))
    if(save.results){
        if(substr(out.path, nchar(out.path), nchar(out.path)) != '/') out.path <- paste0(out.path, '/')
        write.csv(y[order(child)], paste0(out.path, child, '_to_', parent, '.csv'), row.names = FALSE)
    }
    return(y)
}
w <- build.lookups.table('LAD', 'PFA')

#### 1- Output Area to Postcode Sectors, Districts and Areas for UK -------------------------------------------------------------

# load packages
library(data.table)

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

### N.Ireland
# read postcodes data
postcodes <- fread('D:/cloud/OneDrive/data/UK/geography/postcodes/ONSPD.csv', select = c('pcd', 'osgrdind', 'ctry', 'oa11') )
# keep only irish postcodes with valid coordinates
postcodes <- postcodes[osgrdind < 9 & ctry == 'N92000002']
#delete grid and country columns
postcodes[, `:=`(osgrdind = NULL, ctry = NULL)]
# build postcode sectors
postcodes[, PCS := substr(pcd, 1, 5) ]
# extract exact lookups
y <- unique(postcodes[, .(oa11, PCS)])[, .N, oa11][N == 1][, oa11]
nie1 <- unique(postcodes[oa11 %in% y, .(oa11, PCS)])
# extract overlapping and associate each OA with the sector having more postcodes
y <- unique(postcodes[, .(oa11, PCS)])[, .N, oa11][N > 1][, oa11]
nie2 <- postcodes[oa11 %in% y][, .N, .(oa11, PCS)][order(oa11, -N)][, .SD[1], oa11][, .(oa11, PCS)]
# if you want to check the proportion of covered area:
yp <- postcodes[oa11 %in% y][, .N, .(oa11, PCS)][order(oa11, -N)][, pct := round(100 * N / sum(N), 2), oa11][, .(mp = max(pct)), oa11][order(-mp)]

### UK
# union of the previous dataframes
uk <- rbindlist(list(eng, sco, nie1, nie2))
# change names to dataframe
setnames(uk, c('OA', 'PCS'))
# create codes for postcode districts and areas
uk[, PCD := gsub(' ', '', substr(PCS, 1, 4) ) ]
uk[, PCA := sub('[0-9]', '', substr(PCS, 1, gregexpr("[[:digit:]]", PCS)[[1]][1] - 1) ) ]
# save final dataframe to  CSV file
write.csv(uk[order(OA)], 'D:/cloud/OneDrive/data/UK/geography/lookups/OA_to_PCS.csv', row.names = FALSE)

# cleaning...
file.remove(c('lookups.zip', 'OA11_PCDS11_EW_LU.csv', 'OA_TO_HIGHER_AREAS.csv') )
rm(list = ls())
gc()


#### 2- Output Area to LAU2 for UK ----------------------------------------------------------------------------------------------
library(data.table)

### England and Wales
download.file('', 'lookups.zip')
unzip('lookups.zip', '.csv')
eng <- fread('.csv')
file.remove(c('lookups.zip', '.csv'))

### Scotland
download.file('http://www.nrscotland.gov.uk/files//geography/2011-census-indexes-csv.zip', 'lookups.zip')
unzip('lookups.zip', 'OA_TO_HIGHER_AREAS.csv')
sco <- fread('OA_TO_HIGHER_AREAS.csv', select = c('OutputArea2011Code', 'LAU2011Level2Code'))
file.remove(c('lookups.zip', 'OA_TO_HIGHER_AREAS.csv'))

### N.Ireland
postcodes <- fread('D:/cloud/OneDrive/data/UK/geography/postcodes/ONSPD.csv', select = c('nuts', 'osgrdind', 'ctry', 'oa11') )
postcodes <- postcodes[osgrdind < 9 & ctry == 'N92000002']
postcodes[, `:=`(osgrdind = NULL, ctry = NULL)]
y <- unique(postcodes[, .(oa11, nuts)])[, .N, oa11][N == 1][, oa11]
nie1 <- unique(postcodes[oa11 %in% y, .(oa11, nuts)])
y <- unique(postcodes[, .(oa11, nuts)])[, .N, oa11][N > 1][, oa11]
nie2 <- postcodes[oa11 %in% y][, .N, .(oa11, nuts)][order(oa11, -N)][, .SD[1], oa11][, .(oa11, nuts)]
postcodes[oa11 %in% y][, .N, .(oa11, nuts)][order(oa11, -N)][, pct := round(100 * N / sum(N), 2), oa11][, .(mp = max(pct)), oa11][order(-mp)]

### UK
uk <- rbindlist(list(eng, sco, nie1, nie2))
setnames(uk, c('OA', 'LAU2'))
write.csv(uk, 'D:/cloud/OneDrive/data/UK/geography/lookups/OA_to_LAU.csv', row.names = FALSE)

# cleaning...
rm(list = ls())
gc()


#### 3- Output Area to PFA for England and Wales  -------------------------------------------------------------------------------
library(data.table)
postcodes <- fread('D:/cloud/OneDrive/data/UK/geography/postcodes/ONSPD.csv', select = c('pfa', 'osgrdind', 'ctry', 'oa11') )
postcodes <- postcodes[osgrdind < 9 & ctry %in% c('E92000001', 'W92000004')]
postcodes[, `:=`(osgrdind = NULL, ctry = NULL)]
y <- unique(postcodes[, .(oa11, pfa)])[, .N, oa11][N == 1][, oa11]
y1 <- unique(postcodes[oa11 %in% y, .(oa11, pfa)])
y <- unique(postcodes[, .(oa11, pfa)])[, .N, oa11][N > 1][, oa11]
y2 <- postcodes[oa11 %in% y][, .N, .(oa11, pfa)][order(oa11, -N)][, .SD[1], oa11][, .(oa11, pfa)]
postcodes[oa11 %in% y][, .N, .(oa11, pfa)][order(oa11, -N)][, pct := round(100 * N / sum(N), 2), oa11][, .(mp = max(pct)), oa11][order(-mp)]
y <- rbindlist(list(y1, y2))
setnames(y, c('OA', 'PFA'))
write.csv(y[order(OA)], 'D:/cloud/OneDrive/data/UK/geography/lookups/OA_to_PFA.csv', row.names = FALSE)
rm(list = ls())
gc()


#### 4- Output Area to PCON for UK  -------------------------------------------------------------------------------
library(data.table)
postcodes <- fread('D:/cloud/OneDrive/data/UK/geography/postcodes/ONSPD.csv', select = c('pcon', 'osgrdind', 'oa11') )
postcodes <- postcodes[osgrdind < 9]
postcodes[, osgrdind := NULL]
y <- unique(postcodes[, .(oa11, pcon)])[, .N, oa11][N == 1][, oa11]
y1 <- unique(postcodes[oa11 %in% y, .(oa11, pcon)])
y <- unique(postcodes[, .(oa11, pcon)])[, .N, oa11][N > 1][, oa11]
y2 <- postcodes[oa11 %in% y][, .N, .(oa11, pcon)][order(oa11, -N)][, .SD[1], oa11][, .(oa11, pcon)]
yp <- postcodes[oa11 %in% y][, .N, .(oa11, pcon)][order(oa11, -N)][, pct := round(100 * N / sum(N), 2), oa11][, .(mp = max(pct)), oa11][order(-mp)]
y <- rbindlist(list(y1, y2))
setnames(y, c('OA', 'PCON'))
write.csv(y[order(OA)], 'D:/cloud/OneDrive/data/UK/geography/lookups/OA_to_PCON.csv', row.names = FALSE)
rm(list = ls())
gc()


#### 5- Output Area to WARD for UK  -------------------------------------------------------------------------------
library(data.table)
postcodes <- fread('D:/cloud/OneDrive/data/UK/geography/postcodes/ONSPD.csv', select = c('osward', 'osgrdind', 'oa11') )
postcodes <- postcodes[osgrdind < 9]
postcodes[, osgrdind := NULL]
y <- unique(postcodes[, .(oa11, osward)])[, .N, oa11][N == 1][, oa11]
y1 <- unique(postcodes[oa11 %in% y, .(oa11, osward)])
y <- unique(postcodes[, .(oa11, osward)])[, .N, oa11][N > 1][, oa11]
y2 <- postcodes[oa11 %in% y][, .N, .(oa11, osward)][order(oa11, -N)][, .SD[1], oa11][, .(oa11, osward)]
yp <- postcodes[oa11 %in% y][, .N, .(oa11, osward)][order(oa11, -N)][, pct := round(100 * N / sum(N), 2), oa11][, .(mp = max(pct)), oa11][order(-mp)]
y <- rbindlist(list(y1, y2))
setnames(y, c('OA', 'WARD'))
write.csv(y[order(OA)], 'D:/cloud/OneDrive/data/UK/geography/lookups/OA_to_WARD.csv', row.names = FALSE)
rm(list = ls())
gc()
