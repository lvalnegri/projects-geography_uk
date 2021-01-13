###################################
# UK GEOGRAPHY * 12 - MISSING OAs #
###################################

pkgs <- c('dmpkg.funs', 'data.table', 'fst', 'leaflet')
invisible(lapply(pkgs, require, char = TRUE))

get_neighbors <- function(
                    area_id, 
                    distance = 0.5, 
                    circle = TRUE, 
                    in.miles = TRUE, 
                    active_only = TRUE
                ){
    
    pc <- get_postcode_coords(postcode)
    yb <- bounding_box(pc$x_lon, pc$y_lat, distance, in.miles)
    cols <- c('postcode', 'x_lon', 'y_lat', 'is_active')
    pcs <- read_fst(file.path(geouk_path, 'postcodes'), columns = cols, as.data.table = TRUE)
    if(active_only) pcs <- pcs[is_active == 1, -c('is_active')]
    pcs <- pcs[ x_lon >= yb[1, 1] & x_lon <= yb[1, 2] & y_lat >= yb[2, 1] & y_lat <= yb[2, 2] ]
    if(circle){
        setorder(pcs, 'postcode')
        y <- data.table(postcode = pcs$postcode, dist = pointDistance(pcs[, 2:3], pc[, 2:3], lonlat = TRUE))
        y <- y[dist > distance * ifelse(in.miles, 1609.34, 1000), postcode]
        pcs <- pcs[!postcode %in% y]
    }
    pcs
}

area_id <- 
area_type <- 'OA'
distance = 0.5
knn <- 1
circle = TRUE
in.miles = TRUE

bnd <- readRDS(file.path(bnduk_path, 'rds', 's20', area_type))
bnd <- subset(bnd, bnd$id %in% moa[is.na(status), OA])
moa <- fread(file.path(geouk_path, 'missing+empty_OAs.csv'))
pc <- read_fst(file.path(geouk_path, 'postcodes'), as.data.table = TRUE)
pcg <- readRDS(file.path(geouk_path, 'postcodes.geo'))


y <- data.table( pc$PCU, sp::over(pc, bnd) )
y <- y[!is.na(id)]
pcy <- pcg[pcg$PCU %in% y$V1,]

leaflet() %>% 
    addTiles() %>% 
    addPolygons(
        data = subset(bnd, bnd$id %in% y$id),
        label = ~id
    ) %>% 
    addCircles(
        data = pcy,
        fillColor = 'red',
        label = ~PCU
    )
