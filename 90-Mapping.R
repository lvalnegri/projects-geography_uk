###############################################################
# 90- MAPPING: COMBINE SPATIAL OBJECTS AND DATA
###############################################################

### LEAFLET ----------------------------------------------------------------------------------------------------------------

# mp <- leaflet() %>%
#         setView(-96, 37.8, 4) %>%
#         fitBounds(lng1 = 1.8, lat1 = 49.9, lng2 = -8.3, lat2 = 59.0 ) %>% 
#         addTiles('http://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png')



library(rgdal)
library(leaflet)
library(htmltools)
plot.boundaries <- function(type, parent = NA, ){
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