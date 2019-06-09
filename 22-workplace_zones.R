#######################################
# UK GEOGRAPHY * 22 - Workplace Zones #
#######################################

# load packages 
pkg <- c('data.table', 'fst', 'RMySQL')
invisible(lapply(pkg, require, character.only = TRUE))

# set constants 
pub_path <- Sys.getenv('PUB_PATH')
lkps_path <- file.path(pub_path, 'ext_data', 'uk', 'geography', 'lookups')
data_path <- file.path(pub_path, 'datasets', 'uk', 'geography') 

# define functions
build_lookups_table <- function(child, parent, is_active = TRUE, filter_country = NULL, save_results = FALSE, out_path = lkps_path){
    # - Build a lookup table child <=> parent using the postcodes table in the UK geography DB (see script source -10-)
    # - This function should not be used with 'OA' as child because in the csv files from ONS there are 265 OAs missing (36 ENG, 229 SCO) 
    # - Always remember to check column 'pct_coverage' for values less than 100
    #
    message('Processing ', child, 's to ', parent, 's...')
    message('Reading data from database postcodes table...')
    dbc <- dbConnect(MySQL(), group = 'geouk')
    strSQL <- paste0(
        "SELECT ", child, ", ", parent, ", is_active FROM postcodes", 
        ifelse( is.null(filter_country), "", paste0( " WHERE LEFT(CTRY, 1) = '", substr(filter_country, 1, 1), "'") )
    )
    postcodes <- data.table(dbGetQuery(dbc, strSQL))
    dbDisconnect(dbc)
    if(is_active) postcodes <- postcodes[is_active == 1]
    postcodes[, is_active := NULL]
    message('Aggregating...')
    setnames(postcodes, c('child', 'parent'))
    y <- unique(postcodes[, .(child, parent)])[, .N, child][N == 1][, child]
    if(length(y) > 0){
        y1 <- unique(postcodes[child %in% y, .(child, parent, pct = 100)])
    }
    y <- unique(postcodes[, .(child, parent)])[, .N, child][N > 1][!is.na(child), child]
    if(length(y) > 0){
        y2 <- postcodes[child %in% y][, .N, .(child, parent)][order(child, -N)]
        y2 <- y2[, pct := round(100 * N / sum(N), 2), child][, .SD[1], child][, .(child, parent, pct)]
    }
    if(!exists('y1')){
        y <- y2
        exact_cov <- 0
        partial_cov <- nrow(y2)
    } else if(!exists('y2')){
        y <- y1
        exact_cov <- nrow(y1)
        partial_cov <- 0
    } else {
        y <- rbindlist(list(y1, y2))
        exact_cov <- nrow(y1)
        partial_cov <- nrow(y2)
    }
    y <- y[order(child)]
    setnames(y, c(child, parent, 'pct_coverage'))
    if(save_results){
        message('Saving results to csv file...')
        if(substr(out_path, nchar(out_path), nchar(out_path)) != '/') out_path <- paste0(out_path, '/')
        write.csv(y, paste0(out_path, child, '_to_', parent, ifelse(is.null(filter_country), '', paste0('-', filter_country)), '.csv'), row.names = FALSE)
    }
    message('Done! Found ', exact_cov, ' exact associations and ', partial_cov, ' partial coverage')
    return(y)
}

# load output areas
oas <- read.fst(file.path(data_path, 'output_areas'), as.data.table = TRUE)

# WPZ ==> MSOA (ESW) 
eng <- build_lookups_table('WPZ', 'MSOA', filter_country = 'E')
sco <- build_lookups_table('WPZ', 'MSOA', filter_country = 'S')
wls <- build_lookups_table('WPZ', 'MSOA', filter_country = 'W')
uk <- rbindlist(list( eng, sco, wls))[, 1:2]
uk <- unique(oas[CTRY != 'NIE', .(MSOA, LAD, CTY, RGN, CTRY)])[uk, on = 'MSOA']

# find missing WPZ (for ENG) using terminated postcodes
wpz.ms <- sf::read_sf(file.path(pub_path, 'boundaries', 'uk', 'shp', 's00'), layer = 'WPZ') %>% 
            filter(substr(id, 1, 1) == 'E') %>% 
            filter(!id %in% uk$WPZ) %>% 
            pull(id)
pc <- read_fst(file.path(data_path, 'postcodes'), columns = c('postcode', 'is_active', 'WPZ', 'MSOA'), as.data.table = TRUE)
wpz.ms <- pc[is_active == 0 & WPZ %in% wpz.ms][, .N, .(WPZ, MSOA)][order(-N)][, .SD[1], WPZ][, .(WPZ, MSOA)]
wpz.ms <- unique(oas[CTRY != 'NIE', .(MSOA, LAD, CTY, RGN, CTRY)])[wpz.ms, on = 'MSOA']
uk <- rbindlist(list( uk, wpz.ms ))

# ===> there should be the zone id "E33004420" still missing
if(nrow(uk[WPZ == 'E33004420'])==0)
    uk <- rbindlist(list( uk, c('E02006902', unique(uk[MSOA == 'E02006902', .(LAD, CTY, RGN, CTRY)]), 'E33004420') ))

# WPZ ==> LAD (N)
nie <- build_lookups_table('WPZ', 'LAD', filter_country = 'N', save_results = TRUE)
nie <- unique(oas[CTRY == 'NIE', .(LAD, CTY, RGN, CTRY)])[nie[, 1:2], on = 'LAD'][, MSOA := NA]

# bind all together
setcolorder(uk, 'WPZ')
setcolorder(nie, names(uk))
uk <- rbindlist(list(uk, nie))

# save results in database
message('Save to database...')
dbc <- dbConnect(MySQL(), group = 'geouk')
dbSendQuery(dbc, "TRUNCATE TABLE workplace_zones")
dbWriteTable(dbc, 'workplace_zones', uk, row.names = FALSE, append = TRUE)
dbDisconnect(dbc)

# recode all fields as factor, then save in fst format 
uk[, WPZ := factor(WPZ)]
write.fst(uk, file.path(data_path, 'workplace_zones'))

# Clean and Exit
message('DONE!')
rm(list = ls())
gc()
