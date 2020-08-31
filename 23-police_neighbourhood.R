##################################
# 23- BUILD POLICE NEIGHBOURHOOD #
##################################

## 1- load packages ------------------------------------------------------------------------------------------------------------
pkg <- c('popiFun', 'data.table', 'maptools', 'rgdal', 'rgeos', 'rvest')
invisible(lapply(pkg, require,  char = TRUE))

## 2- Define variables ---------------------------------------------------------------------------------------------------------
data_path <- 
    if (substr(Sys.info()['sysname'], 1, 1) == 'W') {
        'D:/cloud/OneDrive/data/UK/geography/boundaries/police'
    } else {
        '/home/datamaps/data/UK/geography/boundaries/police'
    }
boundaries_path <- 
    if(substr(Sys.info()['sysname'], 1, 1) == 'W'){
        'D:/cloud/OneDrive/data/UK/geography/boundaries'
    } else {
        '/home/datamaps/data/UK/geography/boundaries'
    }
map_prj <- '+proj=longlat +datum=WGS84'
    
## 3- Define functions ----------------------------------------------------------------------------------------------------------
get_measures <- function(shp){
    xy <- as.data.frame(gCentroid(shp))
    # should separate Northern Ireland from other countries
    shp <- spTransform(shp, CRS('+init=epsg:27700'))
    cbind( xy, gLength(shp), sapply(shp@polygons, function(x) x@Polygons[[1]]@area) )
}
get_oas <- function(shp, id){
    # align poly and oas on same projection
    proj4string(oas) <- proj4string(shp)
    # returns points inside polygon. note we have to demote the area to a simpler SpatialPolygons object first
    t <- oas[!is.na(over(oas, as(shp, "SpatialPolygons"))),]
    # If there are no points in polygon exit
    if(length(t) > 0){
        # build dataframe to save
        lk <- data.frame(OA = t$OA, neighbourhood_id = id, stringsAsFactors = FALSE)
        # open connection to db
        dbc <- dbConnect(MySQL(), group = 'dataOps', dbname = 'uk_crime')
        # save the lookups 
        dbWriteTable(dbc, 'oas', lk, row.names = FALSE, append = TRUE)
        # close connection to db
        dbDisconnect(dbc)
    }
}
convert_KML <- function(fn){
    # get the name of the neighbourhood
    n_code <- substr(fn, max(gregexpr('/', fn)[[1]]) + 1, nchar(fn) - 4)
    # get the name of the force
    n_force <- substr(fn, 1, nchar(fn) - nchar(n_code) - 5)
    n_force <- substr(n_force, max(gregexpr('/', n_force)[[1]]) + 1, nchar(n_force))
    # get the id of the force
    f_id <- forces[name == n_force, force_id]
    f_id <- paste0(rep('0', f_id < 10), f_id)
    # read the boundaries
    n_poly <- readOGR(fn) 
    n_poly <- n_poly[, 'Name']
    colnames(n_poly@data) <- c('id')
    # create vector to save in db with code, force, centroid, perimeter, area
    n_data <- cbind(n_code, f_id, get_measures(n_poly))
    names(n_data) <- c('code', 'force_id', 'x_lon', 'y_lat', 'perimeter', 'area')
    # open connection to db
    dbc <- dbConnect(MySQL(), group = 'dataOps', dbname = 'uk_crime')
    # save the boundaries 
    dbWriteTable(dbc, 'neighbourhoods', n_data, row.names = FALSE, append = TRUE)
    # get the id of the neighbourhood ==> unique key is (n_code, f_id)
    n_id <- dbGetQuery(dbc, paste0("SELECT neighbourhood_id FROM neighbourhoods WHERE code = '", n_code, "' AND force_id = '", f_id, "'") )
    # close connection to db
    dbDisconnect(dbc)
    # retrieve and save the lookups betwen OAs and neighbourhood
    get_oas(n_poly, n_id)
    # set the id in the boundaries
    n_poly@data$id <- as.numeric(n_id)
    n_poly <- spChFIDs(n_poly, as.character(n_poly$id))
    # return the polygon
    n_poly
}


## 4- load and prepare tables ---------------------------------------------------------------------------------------------------

# OA weighted centroids 
dbc <- dbConnect(MySQL(), group = 'dataOps', dbname = 'geography_uk')
oas <- data.table(dbGetQuery(dbc, "SELECT OA, x_lon, y_lat FROM lookups"))
dbDisconnect(dbc)
# build spatial references
coordinates(oas) <- ~x_lon+y_lat

# police forces
dbc <- dbConnect(MySQL(), group = 'dataOps', dbname = 'uk_crime')
forces <- data.table(dbReadTable(dbc, 'forces'))
dbDisconnect(dbc)
# align names in tables with directories  
forces[, name := gsub(' ', '-', tolower(name))]
# remove "transport police" and "scotland"
forces <- forces[!grepl('transport|scotland', name)]

# truncate neighbourhoods and lookups oas=>neighborhood
dbc <- dbConnect(MySQL(), group = 'dataOps', dbname = 'uk_crime')
dbSendQuery(dbc, 'TRUNCATE TABLE neighbourhoods')
dbSendQuery(dbc, 'TRUNCATE TABLE oas')
dbDisconnect(dbc)


## 5- process neighbourhoods boundaries -----------------------------------------------------------------------------------------

# load neighbourhoods boundaries zip file
download.file('https://data.police.uk/data/boundaries/2017-08.zip', paste0(data_path, 'KML.zip'))
# extract all the KML files in the data path
unzip(paste0(data_path, 'KML.zip'), exdir = data_path)
file.remove(paste0(data_path, 'KML.zip'))
# retrieve all filenames
fnames <- dir(data_path, full.names = TRUE, recursive = TRUE)
# load, convert and bind in one single multi-polygon 
neigh <- convert_KML(fnames[1])
for(fn in fnames[-1]){
    print(paste('Adding', substr(fn, max(gregexpr('/', fn)[[1]]) + 1, nchar(fn) - 4)))
    t <- convert_KML(fn)
    neigh <- spRbind(neigh, t)
}
# save boundaries as single shapefile (remove existing beforehand)
if(file.exists(paste0(boundaries_path, '/PFN.shp'))) file.remove(paste0(boundaries_path, '/PFN.', c('shp', 'prj', 'dbf', 'shx')))
writeOGR(neigh, boundaries_path, layer = 'PFN', driver = 'ESRI Shapefile') 



## 6- scrape neighbourhoods names -----------------------------------------------------------------------------------------------

# initialize dataframe to store neighbourhoods names
n_names <- data.table(force_id = integer(0), code = character(0), name = character(0))
# loop over forces
for(idx in 1:nrow(forces)){
    print(paste('Processing', forces[idx, name]))
    # download webpage and store only the table with list of neighbourhoods
    links <- 
        read_html(paste0('https://www.police.uk/', forces[idx, name])) %>% 
        html_nodes("#neighbourhood-list a")
    # build the code for the neighborhood
    codes <- html_attr(links, 'href') 
    codes <- substr(codes, 1, nchar(codes) - 1) 
    codes <- substring(codes, max(gregexpr('/', codes)[[1]]) + 1)
    # add to list
    n_names <- rbindlist(list(n_names, data.table(forces[idx, force_id], codes, links %>% html_text()) ))
}
# convert '%20' to space
n_names[, code := gsub('%20', ' ', code)]
# update neighbourhood table
dbc <- dbConnect(MySQL(), group = 'dataOps', dbname = 'uk_crime')
dbSendQuery(dbc, 'DROP TABLE IF EXISTS tmp')
dbWriteTable(dbc, 'tmp', n_names, row.names = FALSE, append = TRUE)
dbSendQuery(dbc, "
    ALTER TABLE `tmp`
    	CHANGE COLUMN `force_id` `force_id` TINYINT UNSIGNED NOT NULL FIRST,
    	CHANGE COLUMN `code` `code` VARCHAR(40) NOT NULL COLLATE 'utf8_unicode_ci' AFTER `force_id`,
    	CHANGE COLUMN `name` `name` VARCHAR(120) NOT NULL COLLATE 'utf8_unicode_ci' AFTER `code`,
    	ADD PRIMARY KEY (`force_id`, `code`);
")
dbSendQuery(dbc, "UPDATE neighbourhoods ng JOIN tmp t ON t.force_id = ng.force_id AND t.code = ng.code SET ng.name = t.name")
dbSendQuery(dbc, 'DROP TABLE tmp')
dbDisconnect(dbc)


## 6b- scrape neighbourhoods localities ------------------------------------------------------------------------------------------

# ===>>> this has been put aside as not really functioning:
# ===>>> from the website, you can not understand different locations with the same name in the same neighbourhood

# # read neighbourhoods table
# dbc <- dbConnect(MySQL(), group = 'dataOps', dbname = 'uk_crime')
# neighs <- data.table(dbGetQuery(dbc, 'SELECT neighbourhood_id AS n_id, code AS n_code, force_id AS f_id FROM neighbourhoods'))
# dbDisconnect(dbc)
# # initialize dataframe to store neighbourhoods names
# locations <- data.table(neighbourhood_id = numeric(0), location_pid = numeric(0), location = character(0))
# # loop over neighbourhoods
# st_idx <- 722
# for(idx in st_idx:nrow(neighs)){
#     n_code <- neighs[idx, n_code]
#     f_name <- forces[force_id == neighs[idx, f_id], name]
#     print(paste0('Processing neigh n. ', idx, ': <', n_code, '> in <', toupper(gsub('-', ' ', f_name)), '>'))
#     links <- 
#         paste0('https://www.police.uk/', f_name, '/', n_code, '/crime/locations/') %>% 
#         gsub(' ', '%20', .) %>% 
#         read_html() %>% 
#         html_nodes("th a")
#     codes <- 
#         links %>% 
#         html_attr('href') %>%  
#         substr(., 1, nchar(.) - 1) %>% 
#         substring(., max(gregexpr('/', .)[[1]]) + 1)
#     l_names <- 
#         links %>% 
#         html_text() %>%
#         gsub('\n', '', .) %>% 
#         trimws()
#     locations <- rbindlist(list(locations, data.table(neighs[idx, n_id], codes, l_names) ))
# }


## 7- find OAs (hence neighbourhood) for localities -----------------------------------------------------------------------------

# load locations coordinates
dbc <- dbConnect(MySQL(), group = 'dataOps', dbname = 'uk_crime')
locations <- data.table(dbGetQuery(dbc, "SELECT location_id, x_lon, y_lat FROM locations WHERE x_lon <> 0 OR y_lat <> 0"))
dbDisconnect(dbc)
# build spatial references
coordinates(locations) <- ~x_lon+y_lat

# load OA boundaries for UK
shp <- readOGR(boundaries_path, 'OA')
# delete Scotland
shp <- subset(shp, substr(id, 1, 1) != 'S')
# align poly and oas on same projection
proj4string(locations) <- proj4string(shp)
# returns OA polygon that includes location
t <- cbind(locations@data, over(locations, shp))

# update neighbourhood table
dbc <- dbConnect(MySQL(), group = 'dataOps', dbname = 'uk_crime')
dbSendQuery(dbc, 'DROP TABLE IF EXISTS tmp')
dbWriteTable(dbc, 'tmp', t[!is.na(t$id),], row.names = FALSE, append = TRUE)
dbSendQuery(dbc, "
    ALTER TABLE `tmp`
    	CHANGE COLUMN `location_id` `location_id` MEDIUMINT(8) UNSIGNED NOT NULL FIRST,
    	CHANGE COLUMN `id` `id` CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci' AFTER `location_id`,
    	ADD PRIMARY KEY (`location_id`);
")
dbSendQuery(dbc, "UPDATE locations lc JOIN tmp t ON t.location_id = lc.location_id SET lc.OA = t.id")
dbSendQuery(dbc, 'DROP TABLE tmp')
dbDisconnect(dbc)


## Clean & Exit -----------------------------------------------------------------------------------------------------------------
rm(list = ls())
gc()
