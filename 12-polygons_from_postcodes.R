############################################################################
# UK GEOGRAPHY * 12 - SINGLE AREA POLYGONS (AS CONVEX HULL FROM POSTCODES) #
############################################################################

pkgs <- c('popiFun', 'concaveman', 'data.table', 'fst', 'rgeos', 'sp')
lapply(pkgs, require, char = TRUE)

message('Loading data...')
cols <- c('LSOA', 'MSOA', 'LAD', 'CTY', 'PCS', 'PCD', 'PCA', 'TTWA', 'WARD', 'PCON', 'CED', 'PAR', 'BUA', 'BUAS', 'WPZ', 'PFA', 'STP', 'CCG')
cols <- c('PCS', 'PCD', 'WARD', 'PAR')
pc <- read_fst(file.path(geouk_path, 'postcodes'), columns = c('postcode', 'x_lon', 'y_lat', cols), as.data.table = TRUE)

lcn <- data.table(id = character(0), has_polygon = logical(0))
for(col in cols){
    message('\nProcessing geography type: ', col)
    ys <- levels(pc[[col]])
    yl <- list()
    for(ysl in ys){
        message('Processing location id: ', ysl)
        pcs <- unique(pc[get(col) == ysl, .(x_lon, y_lat)])
        if(nrow(pcs) <= 2){
            lcn <- rbindlist(list( lcn, data.table( ysl, FALSE) ), use.names = FALSE)
        } else {
            lcn <- rbindlist(list( lcn, data.table( ysl, TRUE) ), use.names = FALSE)
            coordinates(pcs) <- ~x_lon+y_lat
            proj4string(pcs) <- crs.gb
            yh <- concaveman(pcs, concavity = 2)
            yh <- spTransform(yh, crs.gb)
            yh <- gBuffer(yh, byid = TRUE, width = 0)
            yl[[ysl]] <- yh
        }
    }
    saveRDS(yl, file.path(bnduk_path, 'postcodes', col))
}
