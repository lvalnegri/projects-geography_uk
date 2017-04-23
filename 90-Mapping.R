###############################################################
# 90- MAPPING: COMBINE SPATIAL OBJECTS AND DATA
###############################################################









### LEAFLET ----------------------------------------------------------------------------------------------------------------

# bins <- c(0, 10, 20, 50, 100, 200, 500, 1000, Inf)
# pal <- colorBin("YlOrRd", domain = states$density, bins = bins)

# mp <- leaflet() %>%
#         setView(-96, 37.8, 4) %>%
#         fitBounds(lng1 = 1.8, lat1 = 49.9, lng2 = -8.3, lat2 = 59.0 ) %>% 
#         addTiles('http://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png')

leaflet(shp.area) %>%
    setView(-96, 37.8, 4) %>%
    fitBounds(lng1 = 1.8, lat1 = 49.9, lng2 = -8.3, lat2 = 59.0 ) %>%
    addTiles('http://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png') %>% 
    addPolygons(
        color = "#444444", 
        weight = 1, 
        smoothFactor = 0.5,
        opacity = 1.0, 
        fillOpacity = 0.5,
        fillColor = 'gray',
        highlightOptions = highlightOptions(
            color = "white", 
            weight = 3, 
            bringToFront = TRUE
        ),
        label = lapply(shp.area$id, htmltools::HTML),
        labelOptions = labelOptions(
            textsize = "15px",
            direction = "auto",
            style = list("font-weight" = "normal", padding = "3px 8px")
        )
    ) 


library(leaflet)
plot.boundaries <- function(type, parent, ){
    shp <- readOGR(boundaries.path, type)
    db_conn <- dbConnect(MySQL(), group = 'local', dbname = 'geographyUK')
    lkp <- dbGetQuery(db_conn, paste0('SELECT FROM locations WHERE type = "', type, '"') )
    dbDisconnect(db_conn)
    leaflet(shp) %>% 
        addTiles() %>% 
        addPolygons(
            stroke = TRUE,
            color = "white",
            weight = 1, 
            opacity = 1, 
            dashArray = '1', 
            fillColor = c('gray'), # ~pal(density),
            fillOpacity = 0.7,
            highlight = highlightOptions(
                weight = 5,
                color = "#666",
                dashArray = "",
                fillOpacity = 0.7,
                bringToFront = TRUE
            ),
            label = lapply(as.character(shp$id), HTML),
            labelOptions = labelOptions(
                style = list("font-weight" = "normal", padding = "3px 8px"),
                textsize = "15px",
                direction = "auto"
            )
        )
}