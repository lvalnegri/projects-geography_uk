# load packages
pkg <- c('data.table', 'htmltools', 'leaflet', 'rgdal', 'rgeos', 'rmapshaper', 'RMySQL')
invisible( lapply(pkg, require, character.only = TRUE) )

# read OA shapefiles
wgs.proj <- '+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0'
bng.proj = '+proj=tmerc +lat_0=49 +lon_0=-2 +k=0.9996012717 +x_0=400000 +y_0=-100000 +ellps=airy +datum=OSGB36 +units=m +no_defs'
boundaries.path <- 'D:/cloud/OneDrive/data/UK/IMD/SCO'
shp <- readOGR(boundaries.path, layer = 'SIMD2016')
summary(shp)
# save data
write.csv(shp@data, paste0(boundaries.path, '/SCO_data.csv'), row.names = FALSE)
# keep in the data slot only the ONS Output Area id, renaming it as 'id'
shp <- shp[, 'DataZone']
colnames(shp@data) <- c('id')
# reassign the polygon IDs
shp <- spChFIDs(shp, as.character(shp$id))
# convert projection
shp <- spTransform(shp, CRS(wgs.proj))
# simplify polygons
shp <- ms_simplify(shp, keep = 0.1)
# delete rmapshaper added id
shp <- shp[, 'id']
# save new boundaries
writeOGR(shp, dsn = boundaries.path, layer = 'SIMD', driver = 'ESRI Shapefile')

# calculate centroids
centroids <- gCentroid(shp, byid = TRUE)
centroids <- cbind(shp@data, centroids@coords)
centroids <- as.data.table(centroids)
setnames(centroids, c('id', 'X_Lon', 'Y_Lat'))
setkey(centroids, 'id')




# read geo data
file.name <- 'BCIS Geo'
data.path <- "C:/projects/PCI/dataset/data/"
dt.geo <- fread(paste(data.path, file.name, '.csv', sep = ''), select = c('parent_unid', 'oa11'), na.strings = '' )
dt.geo <- dt.geo[!is.na(oa11)]
setnames(dt.geo, c('X9007', 'X9012'))
dt.geo <- unique(dt.geo)
setkey(dt.geo, 'X9007')
# this is necessary (for testing purposes!!!) because to each patient_id there could be associated multiple OAs
dt.geo.unqiue <- dt.geo[, .SD[1], X9007]

# read procedures data and merge with previous
db_conn <- dbConnect(MySQL(), group = 'shiny', dbname = 'PCI')
dt <- data.table(dbGetQuery(db_conn, "SELECT D3010 AS datefield, X1010 AS HSP_id, X2010, X2020, X9007 FROM dataset"))
dbDisconnect(db_conn)
setkey(dt, 'X9007')
# dt1 <- dt[dt.geo.unqiue]
dt2 <- dt.geo.unqiue[dt][!is.na(X9012)]


## results for single hospital

# choroplet
qeb.map <- dt2[HSP_id == 'QEB', .N, X9012]
shp.qeb <- subset(shp, id %in% qeb.map[, X9012])
shp.qeb <- merge(shp.qeb, qeb.map, by.x = 'id', by.y = 'X9012')
shp.qeb.bbox <- bbox(shp.qeb)
pal <- colorNumeric('YlOrRd', shp.qeb$N)
leaflet(shp.qeb) %>%
    fitBounds(shp.qeb.bbox[1], shp.qeb.bbox[2], shp.qeb.bbox[3], shp.qeb.bbox[4] ) %>% 
    addTiles('http://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png') %>% 
    addPolygons(
        stroke = TRUE,
        color = '#444444',
        opacity = 0.8,
        weight = 0.6,
        smoothFactor = 0.5,
        fill = TRUE,
        fillColor = ~pal(N),
        fillOpacity = 0.4,
        highlight = highlightOptions(
            weight = 3,
            color = '#666',
            dashArray = "",
            fillOpacity = 0.7,
            bringToFront = TRUE),
        label = lapply(paste0('N. Patients: <b>', shp.qeb$N, '</b>'), HTML),
        labelOptions = labelOptions(
            style = list("font-weight" = "normal", padding = "3px 8px"),
            textsize = "12px",
            direction = "auto"
        )
    ) %>% 
    addLegend(
        pal = pal, 
        values = ~N,
        title = 'N Patients',
        position = 'bottomright',
        opacity = 0.8
    )

# hotspot (http://rpubs.com/bhaskarvk/leaflet-heat)
qeb.hot <- dt2[HSP_id == 'QEB', .N, .(date.year = paste0('y', substr(datefield, 1, 4) ), X9012) ]
qeb.hot <- merge(qeb.hot, centroids, by = 'X9012')

# total
qeb.hot.tot <- qeb.hot[, .(N = sum(N)), .(X_Lon = x, Y_Lat = y) ]
mp <- leaflet(qeb.hot.tot) %>%
        fitBounds(shp.qeb.bbox[1], shp.qeb.bbox[2], shp.qeb.bbox[3], shp.qeb.bbox[4] ) %>% 
        addTiles('http://{s}.tiles.wmflabs.org/bw-mapnik/{z}/{x}/{y}.png') %>% 
        addHeatmap(
            lng = ~X_Lon, lat = ~Y_Lat, 
            intensity = ~N,
            blur = 20, max = 0.05, radius = 15
        )


# by year
qeb.hot.y <- dcast.data.table(qeb.hot, x + y ~ date.year, value.var = 'N')
mp <- leaflet() %>%
        fitBounds(shp.qeb.bbox[1], shp.qeb.bbox[2], shp.qeb.bbox[3], shp.qeb.bbox[4] ) %>% 
        addTiles('http://{s}.tiles.wmflabs.org/bw-mapnik/{z}/{x}/{y}.png')
for(idx in 3:17){
    m <- colnames(qeb.hot.y)[idx]
    t <- qeb.hot.y[, c(1:2, idx), with = FALSE]
    setnames(t, c('X_Lon', 'Y_Lat', 'N'))
    mp <- mp %>%
            addHeatmap(data = t[!is.na(N)],
                layerId = m, group = m,
                lng = ~X_Lon, lat = ~Y_Lat,
                blur = 20, max = 0.05, radius = 15
            )
}
mp <- mp %>% 
        addLayersControl(
            baseGroups = colnames(qeb.hot.y)[3:17],
            options = layersControlOptions(collapsed = TRUE)
        )
