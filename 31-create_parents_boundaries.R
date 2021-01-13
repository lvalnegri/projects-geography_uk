##################################################################################
# UK GEOGRAPHY * 56 - BOUNDARIES: dissolve OAs boundaries to create parent areas #
##################################################################################

build.parent.boundaries <- function(parent, child = 'OA', 
                                    by_region = FALSE,
                                    bnd_path = file.path(Sys.getenv('PUB_PATH'), 'boundaries', 'uk', 'shp', 's00')
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
    
    if(by_region){
        
        # load regions
        db_conn <- dbConnect(MySQL(), group = 'dataOps', dbname = 'geography_uk')
        rgn <- dbGetQuery(db_conn, paste('SELECT DISTINCT', child, 'AS child, RGN FROM output_areas') )
        dbDisconnect(db_conn)
        rgn.lst <- sort(unique(rgn$RGN))
        
        shp_area <- list()
            
        # cycle over regions
        for(r in rgn.lst){
        
            # load oas lookups
            db_conn <- dbConnect(MySQL(), group = 'dataOps', dbname = 'geography_uk')
            lkp <- dbGetQuery(db_conn, paste0('SELECT DISTINCT ', child, ' AS child, ', parent, ' AS parent FROM output_areas WHERE RGN = "', r, '"') )
            dbDisconnect(db_conn)
            
            # join shapefile data slot and lookup table on the child code 
            message('Adding ', parent, ' location codes to ', child, ' data slot for ', r, '...')
            shp_base.r <- subset(shp_base, shp_base@data$id %in% rgn[rgn$RGN == r, 'child'])
            shp_base.r <- merge(shp_base.r, lkp, by.x = 'id', by.y = 'child')
            
            # Build the list of subareas, proceed only if it's not null 
            subareas <- sort(unique(shp_base.r[['parent']]))
            
            if(length(subareas) > 0){
                
                # Define first parent polygon in new region area
                message('Processing ', parent, ' subarea ', subareas[1], ' - number 1 out of ', length(subareas))
                shp_area <- append(shp_area, merge_subpoly(shp_base.r, subareas[1]))
                cur_rgn <- length(shp_area)
                
                # proceed for all other parent polygons, attaching every results to previous object
                for(idx in 2:length(subareas)){
                    message('Processing ', parent, ' subarea ', subareas[idx], ' - number ', idx, ' out of ', length(subareas))
                    shp_area[[cur_rgn]] <- spRbind(shp_area[[cur_rgn]], merge_subpoly(shp_base.r, subareas[idx]))
                }
                
                # delete the rmapshaperid from Polygons
                shp_area[[cur_rgn]] <- shp_area[[cur_rgn]][, 'id']
                
            }
            
        }
        
        # merge all shapes
        shp_area <- do.call('rbind', shp_area)
        
    } else {
        
        # load child lookups
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
    
    }
        
    # save Polygons as shapefile (in case, remove old shapefiles)
    message('Saving ', parent, ' shapefile...')
    if(file.exists(paste0(bnd_path, '/', parent, '.shp') ) ) 
        file.remove(paste0(bnd_path, '/', parent, '.', c('shp', 'prj', 'dbf', 'shx')))
    writeOGR(shp_area, dsn = bnd_path, layer = parent, driver = 'ESRI Shapefile')
    
}

# create boundaries for the "Census" hierarchy
build.parent.boundaries('LSOA', by_region = TRUE)
build.parent.boundaries('MSOA', 'LSOA', by_region = TRUE)
build.parent.boundaries('LAD', 'LSOA') # LAD relies on MSOA only for EWS, N has no MSOA, so the aggregation must be made on LSOA
build.parent.boundaries('CTY', 'LAD')
build.parent.boundaries('RGN', 'CTY')
build.parent.boundaries('CTRY', 'RGN') 

# create boundaries for the "postcodes" hierarchy
build.parent.boundaries('PCS')
build.parent.boundaries('PCD', 'PCS')
build.parent.boundaries('PCT', 'PCD')
build.parent.boundaries('PCA', 'PCD')

# create boundaries for the "statistical" hierarchy
build.parent.boundaries('MTC')
build.parent.boundaries('BUA')
build.parent.boundaries('BUAS')

# create boundaries for the "admin" hierarchy
build.parent.boundaries('TTWA', 'LSOA')
build.parent.boundaries('WARD', by_region = TRUE)
build.parent.boundaries('CED')
build.parent.boundaries('PCON')
build.parent.boundaries('PAR')

# create boundaries for the "social" hierarchy
build.parent.boundaries('CSP', 'OA')
build.parent.boundaries('PFA', 'MSOA')
build.parent.boundaries('STP', 'LSOA')
build.parent.boundaries('CCG', 'LSOA')
build.parent.boundaries('NHSO', 'CCG')
build.parent.boundaries('NHSR', 'CCG')
