###############################################################
# 12- Post Towns. OLD FILE, KEEP IT FOR VILLAGES ?
###############################################################
library(data.table)
library(rvest)

url_pref <- 'https://www.postcodes-uk.com/'

### download postcode areas PCA
pca <- read_html(paste0(url_pref, 'postcode-areas')) %>%
    html_nodes('.postcode_areas_list a') %>% 
    html_text() %>% 
    matrix(byrow = TRUE, ncol = 2) %>% 
    as.data.table() %>% 
    setnames(c('PCA', 'name'))
pca[, `:=`(PCA = trimws(gsub('postcode area', '', PCA)), name = trimws(gsub('postcode area', '', name)))]
write.csv(pca, 'data/pca.csv', row.names = FALSE)

### download postal towns PTW
ptw <- data.table('PCD' = character(0), PTW = character(0))
for(idx in 1:nrow(pca)){
    message('Processing postcode area ', idx, ' out of ', nrow(pca))
    ptw <- rbindlist(list(ptw,
                read_html(paste0(url_pref, pca[idx, PCA], '-postcode-area')) %>%
                    html_nodes('.postcode_district_list a') %>% 
                    html_text() %>% 
                    matrix(byrow = TRUE, ncol = 2) %>% 
                    as.data.table()
    ))
    Sys.sleep(1)
}
ptw[, `:=`(PCD = trimws(gsub('postcode', '', PCD)), PTW = trimws(gsub('postcode', '', PTW)))]
write.csv(ptw, 'data/ptw.csv', row.names = FALSE)

### download villages
villages <- data.table('PCD' = character(0), village = character(0))
for(idx in 1:nrow(ptw)){
    message('Processing district ', idx, ' out of ', nrow(ptw))
    pcd_vlg <- read_html(paste0(url_pref, ptw[idx, PCD], '-postcode-district')) %>%
                    html_nodes('.places-list a') %>% 
                    html_text()
    if(length(pcd_vlg) > 0)
        villages <- rbindlist(list(villages, data.table( ptw[idx, PCD], pcd_vlg ) ) )
    Sys.sleep(runif(1, 1, 2))
}
villages <- rbindlist( list(villages, ptw[!(PCD %in% unique(villages$PCD))]) )
write.csv(villages[order(PCD, village)], 'data/villages.csv', row.names = FALSE)

### order postcode districts
pcd <- ptw[, .(PCD)]
pcd[, `:=`( PCDa = regmatches(pcd$PCD, regexpr('[a-zA-Z]+', pcd$PCD)), PCDn = as.numeric(regmatches(pcd$PCD, regexpr('[0-9]+', pcd$PCD))) )]
pcd <- pcd[order(PCDa, PCDn)][, ordering := 1:.N][, .(PCD, ordering)]
write.csv(pcd, 'data/districts.csv', row.names = FALSE)

### Clean & Exit ----------------------------------------------------------------------------------------------------------------
rm(list = ls())
gc()
