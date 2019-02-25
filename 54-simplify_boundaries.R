#####################################################################
# UK GEOGRAPHY * 54 - Simplify boundaries with multiple percentages #
#####################################################################

simplify_area <- function(area, keep.pct, bnd_path = file.path(Sys.getenv('PUB_PATH'), 'boundaries/shp/UK')){
    lapply(c('maptools', 'rgdal', 'rmapshaper'), require, char = TRUE)
    out_path <- paste0(bnd_path, '/s', ifelse(keep.pct < 0.1, '0', ''), round(100 * keep.pct))
    message('===========================================')
    message('Reading s00 ', area, ' shapefile...')
    y <- readOGR(file.path(bnd_path, 's00'), layer = area)
    size_y <- object.size(y)
    feats_y <- length(y)
    message('Simplifying polygons...')
    y <- ms_simplify(y, keep = keep.pct, keep_shapes = TRUE)
    size_ys <- object.size(y)
    feats_ys <- length(y)
    if(feats_y != feats_ys) warning('ATTENTION! The number of features in the reduced polygons are less than the original ;-(')
    message('Reduction: ', 100 * round(1 - as.numeric(size_ys)/as.numeric(size_y), 3), '%')
    message('Saving ', area, ' shapefile...')
    if(dir.exists(out_path)){
        message('-------------------------------------------')
        file.remove(paste0(out_path, '/', area, '.', c('shp', 'prj', 'dbf', 'shx')))
    } else {
        dir.create(out_path)
    }
    writeOGR(y, dsn = out_path, layer = area, driver = 'ESRI Shapefile')
    message('===========================================')
}

areas <- c('LSOA', 'MSOA', 'LAD', 'CTY', 'RGN', 'CTRY', 'PCS', 'PCD', 'PCT', 'PCA', 'MTC', 'BUA', 'BUAS', 'TTWA', 'WARD', 'CED', 'PCON', 'PAR')
lapply(areas, simplify_area, 0.50)
lapply(areas, simplify_area, 0.40)
lapply(areas, simplify_area, 0.30)
lapply(areas, simplify_area, 0.20)
lapply(areas, simplify_area, 0.10)
lapply(areas, simplify_area, 0.05)
