###############################################
# UK GEOGRAPHY * 16 - Check PCD PCT Wikipedia #
###############################################

pkg <- c('data.table', 'fst', 'rvest')
invisible(lapply(pkg, require, character.only = TRUE))

oas <- read_fst(
            file.path(Sys.getenv('PUB_PATH'), 'datasets', 'uk', 'geography', 'output_areas'),
            columns = c('PCD', 'PCT'),
            as.data.table = TRUE
)
pc <- read_fst(
            file.path(Sys.getenv('PUB_PATH'), 'datasets', 'uk', 'geography', 'postcodes'),
            columns = c('postcode', 'OA', 'PCD'),
            as.data.table = TRUE
)


y <- read_html('https://en.m.wikipedia.org/wiki/List_of_postcode_districts_in_the_United_Kingdom') %>%
    html_nodes('td') %>% 
    html_text()
y <- gsub('\n', '', y[2:length(y)]) %>% 
    matrix(byrow = TRUE, ncol = 4) %>% 
    as.data.table()

y <- y[, .(PCT = rep(V3, sapply(strsplit(V2, split = ','), length)), PCD = unlist(strsplit(V2, split = ',')) )]
y <- y[!grepl('non-geo|GY|IM', PCD)]
y[, PCD := gsub('.*\\s', '', PCD)]

ys <- unique(y[grepl('shared', PCD)])[, PCD := gsub('shared', '', PCD)][]
y <- y[!grepl('shared', PCD)]
ys <- ys[!PCD %in% y[, PCD]]
y <- rbindlist(list(y, ys))[order(PCT, PCD)]

ym <- y[!PCD %in% unique(oas$PCD), PCD]
pcm <- pc[PCD %in% ym, .N, PCD]
oam <- pc[PCD %in% pcm$PCD, .N, OA]
       
# 1: EC3A 77
# 2: EC3M 89
# 3: EC3V 84
# 4: EC4N 77
