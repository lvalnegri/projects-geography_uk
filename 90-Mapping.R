###############################################################
# 90- MAPPING: COMBINE SPATIAL OBJECTS AND DATA
###############################################################

### LEAFLET ----------------------------------------------------------------------------------------------------------------

# mp <- leaflet() %>%
#         setView(-96, 37.8, 4) %>%
#         fitBounds(lng1 = 1.8, lat1 = 49.9, lng2 = -8.3, lat2 = 59.0 ) %>% 
#         addTiles('http://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png')



plot_boundaries <- function(type, parent.type = NA, parent.code = NA){
    pkg <- c('rgdal', 'leaflet', 'htmltools')
    invisible(lapply(pkg, require,  char = TRUE))
    shp <- readOGR(boundaries.path, type)
    if(!is.na(type)){
        db_conn <- dbConnect(MySQL(), group = 'local', dbname = 'geographyUK')
        lkp <- dbGetQuery(db_conn, paste0('SELECT FROM locations WHERE type = "', type, '"') )
        dbDisconnect(db_conn)
    }
    # bins <- c(0, 10, 20, 50, 100, 200, 500, 1000, Inf)
    # pal <- colorBin("YlOrRd", domain = states$density, bins = bins)

    leaflet(shp) %>% 
        setView(-96, 37.8, 4) %>%
        fitBounds(lng1 = 1.8, lat1 = 49.9, lng2 = -8.3, lat2 = 59.0 ) %>%
        addTiles('http://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png') %>% 
        addPolygons(
            stroke = TRUE,
            color = 'white',
            weight = 1, 
            smoothFactor = 0.5,
            opacity = 1, 
            dashArray = '1', 
            fillColor = c('gray'), # ~pal(density),
            fillOpacity = 0.7,
            highlight = highlightOptions(
                weight = 5,
                color = '#666',
                dashArray = '',
                fillOpacity = 0.7,
                bringToFront = TRUE
            ),
            label = lapply(as.character(shp$id), htmltools::HTML),
            labelOptions = labelOptions(
                style = list("font-weight" = "normal", padding = "3px 8px"),
                textsize = "15px",
                direction = "auto"
            )
        )
}


plot_points <- function(loca = 'OA', parent_id = NULL, parent_code = NULL, var_colour = NULL, var_size = NULL, var_facet = NULL){
    pkg <- c('ggmap', 'ggplot2')
    invisible(lapply(pkg, require,  char = TRUE))
    dbc <- dbConnect(MySQL(), group = 'dataOps', dbname = 'geography_uk')
    if(loca == 'OA'){
        strSQL <- "SELECT OA, wx_lon, wy_lat"
        if(!is.null(var_facet)) strSQL <- paste(strSQL, ', ', var_facet, ' AS ZF')
        strSQL <- paste(strSQL, "FROM lookups")
        if(!is.null(parent_id)) strSQL <- paste0(strSQL, " WHERE ", parent_id, " = '", parent_code, "'")
        pnts <- dbGetQuery(dbc, strSQL)
        # add auxiliary variables
        # if(!is.null(var_colour)) strSQL <- paste(strSQL, ', ', var_colour, ' AS ZC')
        # if(!is.null(var_size)) strSQL <- paste(strSQL, ', ', var_size, ' AS ZS')
    } else {
        pnts <- dbGetQuery(dbc, "SELECT location_id, wx_lon, wy_lat FROM lookups WHERE LEFT(CTRY, 1) != 'N'")
    }
    dbDisconnect(dbc)
    
    g <- ggplot(pnts, aes(wx_lon, wy_lat)) + 
            geom_point() + 
            coord_map()
    if(!is.null(var_facet)) g <- g + facet_wrap(~ ZF)
    
    g
}

plot_points(parent_id = 'CTY', parent_code = 'E13000001', var_facet = 'LAD')

