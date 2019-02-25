####################################
# UK GEOGRAPHY * 15 - Postal Towns #
####################################

# load packages -----------------------------------------------------------------------------------------------------------------
pkg <- c('data.table', 'htmltab', 'RMySQL', 'rvest')
invisible(lapply(pkg, require, character.only = TRUE))

# set constants -----------------------------------------------------------------------------------------------------------------
data_path <- file.path(Sys.getenv('PUB_PATH'), 'ext-data/geography_uk')
from_scratch <- TRUE

# load data ---------------------------------------------------------------------------------------------------------------------
pcd <- fread(file.path(data_path, 'locations', 'PCD.csv'))

# if requested, download all post towns again -----------------------------------------------------------------------------------
if(from_scratch){
    
    # download postcode areas PCA -----------------------------------------------------------------------------------------------
    url_pref <- 'https://www.postcodes-uk.com/'
    pca <- read_html(paste0(url_pref, 'postcode-areas')) %>%
        html_nodes('.postcode_areas_list a') %>% 
        html_text() %>% 
        matrix(byrow = TRUE, ncol = 2) %>% 
        as.data.table() %>% 
        setnames(c('PCA', 'name'))
    pca[, `:=`(PCA = trimws(gsub('postcode area', '', PCA)), name = trimws(gsub('postcode area', '', name)))]
    write.csv(pca, file.path(data_path, 'locations', 'PCA.csv'), row.names = FALSE)
    
    # download postal towns PCT -----------------------------------------------------------------------------------------------------
    url_pref <- 'https://www.postcodes-uk.com/'
    pcdt <- data.table('PCD' = character(0), PCT = character(0))
    for(idx in 1:nrow(pca)){
        message('Processing postcode area ', idx, ' out of ', nrow(pca))
        pcdt <- rbindlist(list(
                    pcdt,
                    read_html(paste0(url_pref, pca[idx, PCA], '-postcode-area')) %>%
                        html_nodes('.postcode_district_list a') %>% 
                        html_text() %>% 
                        matrix(byrow = TRUE, ncol = 2) %>% 
                        as.data.table()
        ))
        Sys.sleep(1)
    }
    pcdt[, `:=`(PCD = trimws(gsub('postcode', '', PCD)), PCT = trimws(gsub('postcode', '', PCT)))]

    # save dataset to csv file in lookups ------------------------------------------------------------------------------------
    fwrite(pcdt, file.path(data_path, 'lookups', 'PCDT.csv'))
    
}

# download missed postal towns PCT from Wikipedia -------------------------------------------------------------------------------
pcdt <- fread(file.path(data_path, 'lookups', 'PCDT.csv'))
pcdt <- pcdt[pcd, on = 'PCD']
url_pref <- 'http://en.wikipedia.org/wiki'
miss <- unique(pcdt[is.na(PCT), gsub('[0-9]', '', PCD)])
pctw <- data.table('PCD' = character(0), PCT = character(0))
for(idx in 1:length(miss)){
    message('Processing postcode area ', idx, ' out of ', length(miss))
    y <- data.table( htmltab(paste0(file.path(url_pref, miss[idx]), '_postcode_area'), '//*[@id="mw-content-text"]/div/table[2]') )
    y <- y[!grepl('non-geo', Coverage)]
    if(ncol(y) == 4) y <- y[!grepl('non-geo', `Local authority area`)]
    pctw <- rbindlist(list(pctw, y[, 1:2]))
    Sys.sleep(1)
}
# clean names
pctw[, PCT := paste0( substr(PCT, 1, 1), tolower(substring(PCT, 2)) ) ]
# retain only records with missing PCT names in joint table PCDT
pctw <- pctw[ PCD %in% pcdt[is.na(PCT), PCD]]
# update first table with missing postal town names
pcdt[is.na(PCT), PCT := pctw[.SD[['PCD']], .(PCT), on = 'PCD'] ]

# manual table for last update for some districts in areas: KA, RH, S, ST -------------------------------------------------------
pctw <- data.table(
        'PCD' = c(
            paste0('KA', 7:10), paste0('KA', 13:15), 'KA19', paste0('KA', 21:30), 
            'RH10', 'RH12', 'RH13', paste0('RH', 15:19), 'RH77', 'S95', 'S99', 'ST55'
        ),
        'PCT' = c(
            'Ayr', 'Ayr', 'Prestwick', 'Troon', 'Kilwinning', 'Beith', 'Beith', 'Maybole', 'Saltcoats', 'Ardrossan', 
            'West Kilbride', 'Dalry', 'Kilbirnie', 'Girvan', 'Isle Of Arran', 'Isle Of Cumbrae', 'Largs', 'Largs', 'Crawley', 
            'Horsham', 'Horsham', 'Burgess Hill', 'Haywards Heath', 'Haywards Heath', 
            'Forest Row', 'East Grinstead', 'Redhill', 'Sheffield', 'Sheffield', 'Newcastle'
        )
)
pcdt[is.na(PCT), PCT := pctw[.SD[['PCD']], .(PCT), on = 'PCD'] ]

# create postal town primary key and save table  --------------------------------------------------------------------------------
pct <- unique(pcdt[, .(name = PCT)])[order(name)][, PCT := paste0('PCT', formatC(1:.N, width = 4, format = 'd', flag = '0'))]
setcolorder(pct, c('PCT', 'name'))
write.csv(pct, file.path(data_path, 'locations', 'PCT.csv'), row.names = FALSE)

# substitute post towns names with new ids in pcd -------------------------------------------------------------------------------
pcdt <- pct[pcdt, on = c(name = 'PCT')][, name := NULL]
setcolorder(pcdt, c('PCD', 'ordering', 'PCT'))
write.csv(pcdt, file.path(data_path, 'lookups', 'PCD_to_PCT.csv'), row.names = FALSE)
if(nrow(pcdt[is.na(PCT)])) 
    warning('CHECK pcd.csv! Not all Post Towns have been found. There still are ', nrow(pcd[is.na(PCT)]), ' missing' )

# download villages -------------------------------------------------------------------------------------------------------------
villages <- data.table('PCD' = character(0), village = character(0))
url_pref <- 'https://www.postcodes-uk.com/'
for(idx in 2457:nrow(pcd)){
    message('Processing district ', idx, ' out of ', nrow(pcd))
    pcd_vlg <- read_html(paste0(url_pref, pcd[idx, PCD], '-postcode-district')) %>%
                    html_nodes('.places-list a') %>% 
                    html_text()
    if(length(pcd_vlg) > 0)
        villages <- rbindlist(list(villages, data.table( pcd[idx, PCD], pcd_vlg ) ) )
    Sys.sleep(runif(1, 0.5, 4))
}
villages <- rbindlist( list(villages, ptw[!(PCD %in% unique(villages$PCD))]) )
write.csv(villages[order(PCD, village)], file.path(data_path, 'locations', 'villages.csv'), row.names = FALSE)


# clean and exit ----------------------------------------------------------------------------------------------------------------
rm(list = ls())
gc()

