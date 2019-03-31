#############################################################################################################
# UK GEOGRAPHY * 56 - Boundaries grouping and conversion to rds format for quicker loading in Shiny apps
#############################################################################################################

# load packages
pkg <- c('fst', 'rgdal', 'sp')
invisible( lapply(pkg, require, character.only = TRUE) )

# set the directories (do NOT end any path with "/")
bnd_path  <- file.path(Sys.getenv('PUB_PATH'), 'boundaries', 'uk', 'shp', 's20')       # path for the input shapefiles 
rds_path  <- file.path(Sys.getenv('PUB_PATH'), 'boundaries', 'uk', 'rds', 's20')       # path for the output R binary files
data_path <- file.path(Sys.getenv('PUB_PATH'), 'datasets', 'geography', 'uk') # path for the lookups file

# set areas names
# areas <- list(
#     'census' = c('LSOA', 'MSOA', 'LAD', 'CTY', 'RGN', 'CTRY'), 
#     'postcodes' = c('PCS', 'PCD', 'PCT', 'PCA'),
#     'statistical ' = c('MTC', 'BUA', 'BUAS'), 
#     'admin ' = c('TTWA', 'WARD', 'CED', 'PCON', 'PAR')
# )
areas <- c('LSOA', 'MSOA', 'LAD', 'CTY', 'RGN', 'CTRY', 'PCS', 'PCD', 'PCT', 'PCA', 'MTC', 'BUA', 'BUAS', 'TTWA', 'WARD', 'CED', 'PCON', 'PAR')

# load locations names
locations <- read.fst(file.path(data_path, 'locations'))

# load boundaries and build unique list
boundaries <- lapply(areas, function(x) readOGR(bnd_path, x))
names(boundaries) <- areas

# save each area as separate file
for(area in areas){
    message('Saving ', area, ' boundaries...')
    saveRDS(boundaries[[area]], file.path(rds_path, area))
}

# save all boundaries as one object
message('Saving all areas boundaries as unique file...')
saveRDS(boundaries, file.path(rds_path, 'boundaries'))

# clean and exit
rm(list = ls())
gc()