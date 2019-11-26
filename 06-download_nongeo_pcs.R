########################################################################
# UK GEOGRAPHY * 06 - DOWNLOAD LIST NON GEOGRAPHICAL POSTCODES SECTORS #
########################################################################

pkg <- c('data.table', 'tabulizer')
lapply(pkg, require, char = TRUE)

message('Downloading file and extracting tables...') # updated twice a year <JAN> + <JUL>, check PAF website for correct link www.poweredbypaf.com
y <- extract_tables('https://www.poweredbypaf.com/wp-content/uploads/2019/07/July-2019_current_non-geos-original.pdf')

message('Building dataset...') # last update ==> AUG-19
ng <- data.table(PCS = character(0))
for(idx in 1:5)
    ng <- rbindlist(list( ng, data.table(y[[idx]][-1, 2]) ))
ng <- rbindlist(list( ng, data.table(y[[6]][6, 2]) ))
ng <- rbindlist(list( ng, data.table(y[[7]][-(1:2), 2]) ))
for(idx in 8:length(y))
    ng <- rbindlist(list( ng, data.table(y[[idx]][, 2]) ))
ng <- unique(ng[PCS != ''])

message('Recoding PCS as 5-chars format...')
ng <- ng[, .(PCS = gsub(' ', '', PCS))]
ng[nchar(PCS) == 4, PCS := paste(substr(PCS, 1, 3), substring(PCS, 4))]
ng[nchar(PCS) == 3, PCS := paste0(substr(PCS, 1, 2), '  ', substring(PCS, 3))]

message('Some specific cleaning...')
ng <- ng[nchar(PCS) == 5]
ng <- rbindlist(list( ng, data.table(c('LE199', 'LE34')) ))
ng <- ng[PCS != 'NR1 3']

message('Saving as csv file...')
fwrite(ng[order(PCS)], file.path(pub_path, 'ext_data', 'uk', 'geography', 'postcodes', 'pcs_non_geo.csv'))

message('DONE! Cleaning...')
rm(list = ls())
gc()
