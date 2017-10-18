##############################################################################################
# Boundaries grouping and conversion to rds format for quicker loading in Shiny apps
##############################################################################################

# define functions
get.bnd.names <- function(country){
    dbc <- dbConnect(MySQL(), group = 'dataOps', dbname = 'common')
    strSQL <- paste0("SELECT path FROM paths WHERE name = 'boundaries' AND system = '", ifelse(grepl('linux', R.version$os), 'linux', 'win'), "'")
    data.path <- dbGetQuery(dbc, strSQL)
    data.path <- paste0(data.path, 'fst', '/', app.name, '/')
    shp_names <- dbGetQuery(dbc, paste0("SELECT dataset FROM fst_shiny WHERE country = '", country, "'"))
    dbDisconnect(dbc)
    return( list(data.path, shp_names) )
}
shp2rds <- function(app.name){
    lapply(c('rgdal', 'RMySQL', 'sp'), require, character.only = TRUE)
    y <- get.fst.names(app.name)
    dbc <- dbConnect(MySQL(), group = 'dataOps', dbname = app.name)
    for(dtn in unlist(y[[2]])){
        print(paste0('Reading ', dtn, '...'))
        dt <- dbReadTable(dbc, dtn)
        print(paste0('Writing ', dtn, '...'))
        write.fst(dt, paste0(y[[1]], dtn, '.fst'), 100 )
    }
    dbDisconnect(dbc)
}

# define locations whose boundaries have to be grouped and stored
loca.map <- c('CCG', 'LAT', 'NHSR', 'CCR', 'CTRY')

# load additional datasets
db_conn <- dbConnect(MySQL(), group = 'shiny', dbname = 'common')
locations <- suppressWarnings(data.table(dbReadTable(db_conn, 'locations') ) )
dbDisconnect(db_conn)

# load boundaries and build unique list
boundaries <- lapply(loca.map, function(x) readOGR(shp.path, x))
names(boundaries) <- loca.map
for(m in loca.map){
    boundaries[[m]] <- merge(boundaries[[m]], areas[, .(ons_id, nhs_id, name)], by.x = 'id', by.y = 'ons_id')
}

# save boundaries as RDS object
saveRDS(boundaries, paste0(shp.path, '/boundaries.rds'))

### How to read back and use the rds file in the app 
# country <- 'ldn'
# y <- get.bnd.names(app.name)
