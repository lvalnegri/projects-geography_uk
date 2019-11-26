#######################################
# UK GEOGRAPHY * 15 - Postal Towns
#######################################

pkg <- c('popiFun', 'data.table', 'htmltab', 'RMySQL', 'rvest')
invisible(lapply(pkg, require, character.only = TRUE))

data_path <- file.path(ext_path, 'uk', 'geography')

pcd <- fread(file.path(data_path, 'locations', 'PCD.csv'))

message('Downloading Postcode Areas (PCA)...')
url_pref <- 'https://www.postcodes-uk.com/'
pca <- read_html(paste0(url_pref, 'postcode-areas')) %>%
    html_nodes('.postcode_areas_list a') %>% 
    html_text() %>% 
    matrix(byrow = TRUE, ncol = 2) %>% 
    as.data.table() %>% 
    setnames(c('PCA', 'name'))
pca[, `:=`(PCA = trimws(gsub('postcode area', '', PCA)), name = trimws(gsub('postcode area', '', name)))]
fwrite(pca, file.path(data_path, 'locations', 'PCA.csv'), row.names = FALSE)

message('\n============================================================')
message('Downloading Postal Towns (PCT)...\n')
url_pref <- 'https://www.postcodes-uk.com/'
pcdt <- data.table('PCD' = character(0), PCT = character(0))
for(idx in 1:nrow(pca)){
    message(' - Processing postcode area ', idx, ' out of ', nrow(pca))
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

message('Saving dataset as csv file...')
fwrite(pcdt, file.path(data_path, 'lookups', 'PCDT.csv'))

message('\n============================================================')
message('Downloading missed Postal Towns from Wikipedia...')
pcdt <- fread(file.path(data_path, 'lookups', 'PCDT.csv'))
pcdt <- pcdt[pcd, on = 'PCD']
url_pref <- 'http://en.wikipedia.org/wiki'
miss <- unique(pcdt[is.na(PCT), gsub('[0-9]', '', PCD)])
pctw <- data.table('PCD' = character(0), PCT = character(0))
for(idx in 1:length(miss)){
    message(' - Processing postcode area ', idx, ' out of ', length(miss))
    y <- data.table(htmltab(
            paste0(file.path(url_pref, miss[idx]), '_postcode_area'), 
            '//*[@id="mw-content-text"]/div/table[2]'
    ))
    y <- y[!grepl('non-geo', Coverage)]
    if(ncol(y) == 4) y <- y[!grepl('non-geo', `Local authority area`)]
    pctw <- rbindlist(list(pctw, y[, 1:2]), use.names = FALSE)
    Sys.sleep(1)
}

message('\nDone! Cleaning results...')

# clean names
pctw[, PCT := paste0( substr(PCT, 1, 1), tolower(substring(PCT, 2)) ) ]

# retain only records with missing PCT names in joint table PCDT
pctw <- pctw[ PCD %in% pcdt[is.na(PCT), PCD]]

# update first table with missing postal town names
pcdt[is.na(PCT), PCT := pctw[.SD[['PCD']], .(PCT), on = 'PCD'] ]

# manual table for last update for some districts -------------------------------------------------------------------------------
pctw <- data.table(
    'PCD' = c(paste0('KA', 7:10), paste0('KA', 13:15), paste0('KA', 19:30)),
    'PCT' = c(
        'Ayr', 'Ayr', 'Prestwick', 'Troon', 'Kilwinning', 'Beith', 'Beith', 'Maybole', 'Stevenston', 'Saltcoats', 'Ardrossan', 
        'West Kilbride', 'Dalry', 'Kilbirnie', 'Girvan', 'Isle Of Arran', 'Isle Of Cumbrae', 'Largs', 'Largs'
    )
)
pcdt[is.na(PCT), PCT := pctw[.SD[['PCD']], .(PCT), on = 'PCD'] ]

message('\nCreating IDs and Saving tables as csv...')

# create postal town primary key and save table  --------------------------------------------------------------------------------
pct <- unique(pcdt[, .(name = PCT)])[order(name)][, PCT := paste0('PCT', formatC(1:.N, width = 4, format = 'd', flag = '0'))]
setcolorder(pct, c('PCT', 'name'))
fwrite(pct, file.path(data_path, 'locations', 'PCT.csv'), row.names = FALSE)

# substitute post towns names with new ids in pcd -------------------------------------------------------------------------------
pcdt <- pct[pcdt, on = c(name = 'PCT')][, name := NULL]
setcolorder(pcdt, c('PCD', 'ordering', 'PCT'))
fwrite(pcdt, file.path(data_path, 'lookups', 'PCD_to_PCT.csv'), row.names = FALSE)
if(nrow(pcdt[is.na(PCT)])) 
    warning('CHECK pcd.csv! Not all Post Towns have been found. There still are ', nrow(pcd[is.na(PCT)]), ' missing' )

message('\n============================================================')
message('Downloading villages...\n')

villages <- data.table('PCD' = character(0), village = character(0))
url_pref <- 'https://www.postcodes-uk.com/'
for(idx in 1:nrow(pcd)){
    message(' - Processing district ', pcd[idx, PCD], ' (', idx, ' out of ', nrow(pcd), ')')
    pcd_vlg <- tryCatch(
        read_html(paste0(url_pref, pcd[idx, PCD], '-postcode-district')) %>%
            html_nodes('.places-list a') %>% 
            html_text()
        , error = function(err) character(0)
    )
    if(length(pcd_vlg) > 0){
        villages <- rbindlist(list(villages, data.table( pcd[idx, PCD], pcd_vlg ) ), use.names = FALSE )
        message('   => Added ', length(pcd_vlg), ' villages (total villages so far: ', nrow(villages), ')')
    }
    Sys.sleep(runif(1, 0.5, 4))
}

message('\nDone!\nAdding PCD with no villages, then saving table as csv...')

y <- pcdt[!(PCD %in% unique(villages$PCD)), .(PCD, PCT)]
y <- pct[y, on = 'PCT'][!is.na(name), .(PCD, village = name)]
villages <- rbindlist( list(villages, y) )
fwrite(villages[order(PCD, village)], file.path(data_path, 'locations', 'villages.csv'), row.names = FALSE)

message('\nDONE! Cleaning...')
rm(list = ls())
gc()
