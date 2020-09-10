############################################################################
# UK GEOGRAPHY * 19 - SINGLE AREA POLYGONS (AS CONVEX HULL FROM POSTCODES) #
############################################################################

pkgs <- c('popiFun', 'concaveman', 'data.table', 'fst', 'rgeos', 'rmapshaper', 'sp')
lapply(pkgs, require, char = TRUE)

message('Loading data...')
cols <- c('LSOA', 'MSOA', 'LAD', 'WARD', 'PAR', 'PCON', 'PFN', 'PCS', 'PCD', 'PCT')
pc <- read_fst_idx(file.path(geouk_path, 'postcodes'), 1, c('postcode', 'x_lon', 'y_lat', 'OA', cols))
bnd <- readRDS(file.path(bnduk_spath, 'OA'))

for(col in cols){
    message('\nProcessing geography type: ', col)
    ys <- levels(droplevels(pc[[col]]))
    for(ysl in ys){
        
        message('\nProcessing location id: ', ysl)
        
        message(' - by convex hull...')
        pcs <- unique(pc[get(col) == ysl, .(x_lon, y_lat)])
        coordinates(pcs) <- ~x_lon+y_lat
        if(length(pcs) <= 4){
            yh <- gConvexHull(pcs)
        } else {
            yh <- concaveman(pcs, concavity = 2)
        }
        yh <- gBuffer(yh, width = 0.0005, joinStyle = 'MITRE', capStyle = 'SQUARE')
        saveRDS(yh, file.path(bnduk_path, 'postcodes', 'ch', ysl))
        
        message(' - by output areas...')
        pcs <- unique(pc[get(col) == ysl, .(OA)])
        yb <- ms_dissolve(subset(bnd, bnd$id %in% pcs$OA))
        saveRDS(yb, file.path(bnduk_path, 'postcodes', 'oa', ysl))
        
    }
}
