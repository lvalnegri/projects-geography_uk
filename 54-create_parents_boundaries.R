#######################################################################################################
# UK GEOGRAPHY * 52 - BOUNDARIES: dissolve UK output area boundaries to create higher levels areas
#######################################################################################################

build.parent.boundaries <- function(parent, child = 'OA', 
                                    bnd_path = file.path(Sys.getenv('PUB_PATH'), 'boundaries/shp/UK'), 
                                    simplify = FALSE,
                                    keep.pct = 0.05
                           ){
    
    # load packages
    pkg <- c('maptools', 'rgdal', 'rmapshaper', 'RMySQL')
    invisible(lapply(pkg, require, char = TRUE))
    
    # helper function
    merge_subpoly <- function(shp, subarea){
        
        # select all child polygons contained in specified parent polygon
        shp.tmp <- subset(shp, shp[['parent']] == subarea)
        
        # delete interiors
        shp.tmp <- ms_dissolve(shp.tmp)
        
        # define new polygon id
        shp.tmp$id <- subarea
        shp.tmp <- spChFIDs(shp.tmp, as.character(shp.tmp$id))
        
        return(shp.tmp)
        
    }
    
    # load base polygons from shapefile
    message('Reading ', child, ' shapefile...')
    shp_base <- readOGR(bnd_path, layer = child)
    
    # load oas lookups
    db_conn <- dbConnect(MySQL(), group = 'dataOps', dbname = 'geography_uk')
    lkp <- dbGetQuery(db_conn, paste('SELECT DISTINCT', child, 'AS child,', parent, 'AS parent FROM output_areas') )
    dbDisconnect(db_conn)
    
    # join shapefile data slot and lookup table on the child code 
    message('Adding ', parent, ' location codes to ', child, ' data slot...')
    shp_base <- merge(shp_base, lkp, by.x = 'id', by.y = 'child')
    
    # Build the list of subareas 
    subareas <- sort(unique(shp_base[['parent']]))
    
    # Define first parent polygon
    message('Processing ', parent, ' subarea ', subareas[1], ' - number 1 out of ', length(subareas))
    shp_area <- merge_subpoly(shp_base, subareas[1])
    
    # proceed for all other parent polygons, attaching every results to previous object
    for(idx in 2:length(subareas)){
        message('Processing ', parent, ' subarea ', subareas[idx], ' - number ', idx, ' out of ', length(subareas))
        shp_area <- spRbind(shp_area, merge_subpoly(shp_base, subareas[idx]))
    }
    
    # delete the rmapshaperid from Polygons
    shp_area <- shp_area[, 'id']
    
    # if requested, simplify the polygons
    if(simplify) shp_area <- ms_simplify(shp_area, keep = keep.pct, keep_shapes = TRUE)
    
    # save Polygons as shapefile (in case, remove old shapefiles)
    message('Saving ', parent, ' shapefile...')
    if(file.exists(paste0(bnd_path, '/', parent, '.shp') ) ) 
        file.remove(paste0(bnd_path, '/', parent, '.', c('shp', 'prj', 'dbf', 'shx')))
    writeOGR(shp_area, dsn = bnd_path, layer = parent, driver = 'ESRI Shapefile')
    
}

# create boundaries for the "Census" hierarchy
build.parent.boundaries('LSOA')
build.parent.boundaries('MSOA', 'LSOA')
build.parent.boundaries('LAD', 'LSOA')   # LAD relies on MSOA only for EWS, N has no MSOA, so the aggregation must be made on LSOA
build.parent.boundaries('CTY', 'LAD')
build.parent.boundaries('RGN', 'CTY')
build.parent.boundaries('CTRY', 'LAD')   # CTRY relies on RGN only for E, NSW have no RGN, so the aggregation must be made on LAD

# create boundaries for the "postcodes" hierarchy
build.parent.boundaries('PCS')
build.parent.boundaries('PCD', 'PCS')
build.parent.boundaries('PCT', 'PCD')
build.parent.boundaries('PCA', 'PCD')

# create boundaries for the "statistical" hierarchy
build.parent.boundaries('MTC')
build.parent.boundaries('BUA')
build.parent.boundaries('BUAS')

# create boundaries for the "misc" hierarchy
build.parent.boundaries('TTWA', 'LSOA')
build.parent.boundaries('WARD')
build.parent.boundaries('CED')
build.parent.boundaries('PCON')
build.parent.boundaries('PAR')

# create boundaries for the "" hierarchy
build.parent.boundaries('PFA', 'LSOA')
build.parent.boundaries('LAU2')
build.parent.boundaries('LAU1', 'LAU2')
build.parent.boundaries('NTS3', 'LAU1')
build.parent.boundaries('NTS2', 'NTS3')
build.parent.boundaries('NTS1', 'NTS2')
build.parent.boundaries('CCG', 'LSOA')
build.parent.boundaries('STP', 'LSOA')

