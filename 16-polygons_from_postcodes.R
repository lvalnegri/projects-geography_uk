############################################################################
# UK GEOGRAPHY * 12 - SINGLE AREA POLYGONS (AS CONVEX HULL FROM POSTCODES) #
############################################################################

pkgs <- c('popiFun', 'concaveman', 'data.table', 'fst', 'rgeos', 'sp')
lapply(pkgs, require, char = TRUE)

message('Loading data...')
cols <- c('PCS', 'PCD', 'WARD', 'PAR', 'WPZ')
pc <- read_fst(file.path(geouk_path, 'postcodes'), columns = c('postcode', 'is_active', 'x_lon', 'y_lat', cols), as.data.table = TRUE)
pc <- pc[is_active == 1]

for(col in cols){
    message('\nProcessing geography type: ', col)
    ys <- levels(droplevels(pc[[col]]))
    for(ysl in ys){
        message('Processing location id: ', ysl)
        pcs <- unique(pc[get(col) == ysl, .(x_lon, y_lat)])
        coordinates(pcs) <- ~x_lon+y_lat
        if(length(pcs) <= 4){
            yh <- gConvexHull(pcs)
        } else {
            yh <- concaveman(pcs, concavity = 2)
            yh <- gBuffer(yh, byid = TRUE, width = 0)
        }
        saveRDS(yh, file.path(bnduk_path, 'postcodes', 'ch', ysl))
    }
}
