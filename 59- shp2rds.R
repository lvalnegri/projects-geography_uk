############################################################################################
# UK GEOGRAPHY * 59 - Boundaries grouping and conversion to rds format for quicker loading #
############################################################################################

# load packages
pkg <- c('fst', 'rgdal')
invisible( lapply(pkg, require, character.only = TRUE) )

# set the directories
bnd_path  <- file.path(Sys.getenv('PUB_PATH'), 'boundaries', 'uk', 'shp')
rds_path <- file.path(Sys.getenv('PUB_PATH'), 'boundaries', 'uk', 'rds') 

# set areas names
areas <- c(
  'OA', 'LSOA', 'MSOA', 'LAD', 'CTY', 'RGN', 'CTRY', 
  'PCS', 'PCD', 'PCT', 'PCA', 
  'MTC', 'BUA', 'BUAS', 
  'TTWA', 'WARD', 'CED', 'PCON', 'PAR',
  'PFA', 'STP', 'CCG', 'NHSO', 'NHSR'
)
sel_areas <- c('LSOA', 'MSOA', 'LAD', 'CTY', 'RGN', 'CTRY', 'PCS', 'PCD', 'PCT', 'PCA', 'TTWA', 'WARD', 'PCON', 'PAR')
pct_simplify <- c('s00', paste0('s', 1:5 * 10))

# loop over all specified percentages
for(pct in pct_simplify){

  # set boundary path to simplify
  message('=======================================================')
  message('Processing boundaries simplified as ', substring(pct, 2), '%')
  smp_path <- file.path(bnd_path, pct)
  
  # load boundaries and build unique list
  message('Reading all shapefiles...')
  boundaries <- lapply(areas, function(x) readOGR(file.path(bnd_path, pct), x))
  names(boundaries) <- areas
  
  # save each area as separate file
  for(area in areas){
      message('Saving ', area, ' boundaries...')
      saveRDS(boundaries[[area]], file.path(rds_path, pct, area))
  }
  
  message('Saving all boundaries as unique RDS file...')
  saveRDS(boundaries, file.path(rds_path, pct, 'boundaries_all'))

  message('Saving selected boundaries as unique RDS file...')
  saveRDS(boundaries[sel_areas], file.path(rds_path, pct, 'boundaries'))

  message('Cleaning...')
  rm(boundaries); gc()

  message('Finished!')
  message('=======================================================')
  
}

# clean and exit
rm(list = ls())
gc()
