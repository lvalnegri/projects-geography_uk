##################################################
# UK GEOGRAPHY * 01 - Create database and tables #
##################################################
# You need to provide the following CSV in in_path:
#  - hierarchies
#  - types
#  - OAC and RUC codes and names 

# Load packages -----------------------------------------------------------------------------------------------------------------
pkg <- c('data.table', 'fst', 'RMySQL')
invisible( lapply(pkg, require, char = TRUE) )

# Set variables -----------------------------------------------------------------------------------------------------------------
in_path <- file.path(Sys.getenv('PUB_PATH'), 'ancillaries', 'geography')
out_path <- file.path(Sys.getenv('PUB_PATH'), 'datasets', 'geography')

# Create database ---------------------------------------------------------------------------------------------------------------
dbc = dbConnect(MySQL(), group = 'dataOps')
dbSendQuery(dbc, 'DROP DATABASE IF EXISTS geography_uk')
dbSendQuery(dbc, 'CREATE DATABASE geography_uk')
dbDisconnect(dbc)

# Connect to database -----------------------------------------------------------------------------------------------------------
dbc = dbConnect(MySQL(), group = 'geography')

# POSTCODES ---------------------------------------------------------------------------------------------------------------------
strSQL <- "
    CREATE TABLE postcodes (
	
        postcode CHAR(7) NOT NULL COMMENT 'postcode in 7-chars format: 4-chars outcode + 3-chars incode',
        is_active TINYINT(1) UNSIGNED NOT NULL COMMENT '0- terminated, 1- live',
        usertype TINYINT(1) UNSIGNED NOT NULL 
            COMMENT '0- small user, 1- large user (large means addresses receiving more than 25 items per day)',
        x_lon DECIMAL(7,6) NOT NULL COMMENT 'longitude of the geometric centroid of the postcode',
        y_lat DECIMAL(8,6) UNSIGNED NOT NULL COMMENT 'latitude of the geometric centroid of the postcode',
        population SMALLINT(5) UNSIGNED NULL COMMENT '',
        households SMALLINT(5) UNSIGNED NULL COMMENT '',

        OA CHAR(9) NOT NULL COMMENT 'Output Area (E00, W00, S00, N00)',
        LSOA CHAR(9) NOT NULL COMMENT 'Lower Layer Super Output Area (E01, W01, S01, N01)',
        MSOA CHAR(9) NULL DEFAULT NULL COMMENT 'Middle Layer Super Output Area (E02, W02, S02; England, Wales and Scotland Only)',
        LAD CHAR(9) NOT NULL COMMENT 'Local Authority District (UA-E06/W06, LAD-E07, MD-E08, LB-E09, CA-S12, DCA-N09)',
        CTY CHAR(9) NULL DEFAULT NULL COMMENT 'County (C-E10, MC-E11, IOL-E13, plus LAD-E06; England Only)',
        RGN CHAR(9) NULL DEFAULT NULL COMMENT 'Region (E12; England Only)',
        CTRY CHAR(1) NOT NULL COMMENT 'Country (E92, W92, S92, N92)',

        PCS CHAR(5) NOT NULL COMMENT 'PostCode Sector: outcode plus 1st digit incode',
        PCD CHAR(4) NOT NULL COMMENT 'PostCode District: same as outcode',
        PCA CHAR(2) NOT NULL COMMENT 'PostCode Area: letters only in outcode',

        TTWA CHAR(9) NOT NULL COMMENT 'Travel To Work Area (E30, W22, S22, N12, K01 for overlapping zones)',
        WARD CHAR(9) NOT NULL COMMENT 'Electoral Ward (E05, W05, S13, N08)',
        PCON CHAR(9) NOT NULL COMMENT 'Westminster Parliamentary Constituency (E14, W07, S14, N06)',
        CED CHAR(9) NULL DEFAULT NULL COMMENT 'County Electoral Division (E58; England Only; Partial Coverage)',
        PAR CHAR(9) NULL DEFAULT NULL COMMENT 'Civil Parish (E04, W04; England and Wales Only; Partial Coverage England Only)',

    	BUA CHAR(9) NULL DEFAULT NULL 
    	    COMMENT 'Built-up Area (E34, W37, K05 for overlapping zones; England and Wales Only; Partial Coverage)',
    	BUAS CHAR(9) NULL DEFAULT NULL 
    	    COMMENT 'Built-up Subdivision (E35, W38, K06 for overlapping zones; England and Wales Only; Partial Coverage)',
    	WPZ CHAR(9) NULL DEFAULT NULL COMMENT 'Workplace Zone (E33, W35, S34, N19)',

    	PFA CHAR(9) NULL DEFAULT NULL COMMENT 'Police Force Area (E23, W15, S32, N24)',
    	CCG CHAR(9) NOT NULL COMMENT 'Clinical Commissioning Group (E38, W11, S03, ZC)',
    	STP CHAR(9) NOT NULL COMMENT 'Sustainability and Transformation Partnership (E54; England Only)',
    	LAU2 CHAR(9) NOT NULL COMMENT 'Local Administrative Units 2 (E05, W05, S31, N08)',

        PRIMARY KEY (postcode),
        INDEX (OA),
        INDEX (is_active),
        INDEX (usertype)

    ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci ROW_FORMAT=FIXED
"
dbSendQuery(dbc, strSQL)

# INDICES -----------------------------------------------------------------------------------------------------------------------
strSQL <- "
    CREATE TABLE indices (
        idx TINYINT(3) UNSIGNED NOT NULL COMMENT '1- OAC, 2- RUC, 3- IMD, 4- HI',
        location_id CHAR(9) NOT NULL,
        value MEDIUMINT(8) UNSIGNED NOT NULL,
        PRIMARY KEY (location_id, idx),
        INDEX (location_id),
        INDEX (idx)
    ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci ROW_FORMAT=FIXED
"
dbSendQuery(dbc, strSQL)

# OUTPUT AREAS ------------------------------------------------------------------------------------------------------------------
strSQL <- "
    CREATE TABLE output_areas (
    
        OA CHAR(9) NOT NULL COMMENT 'Output Area',
        x_lon DECIMAL(7,6) NULL DEFAULT NULL COMMENT 'longitude for the geometric centroid',
        y_lat DECIMAL(8,6) UNSIGNED NULL DEFAULT NULL COMMENT 'latitude for the geometric centroid',
        wx_lon DECIMAL(7,6) NULL DEFAULT NULL COMMENT 'longitude for the population weigthed centroid',
        wy_lat DECIMAL(8,6) UNSIGNED NULL DEFAULT NULL COMMENT 'latitude for the population weigthed centroid',
        perimeter MEDIUMINT(8) UNSIGNED NULL DEFAULT NULL,
        area INT(10) UNSIGNED NULL DEFAULT NULL,
    	tot_uprn SMALLINT(5) UNSIGNED NULL DEFAULT NULL COMMENT 'Total unique spatial addresses',
    	oac SMALLINT(3) UNSIGNED NULL DEFAULT NULL COMMENT 'Output Area Classification',
    	ruc TINYINT(3) UNSIGNED NULL DEFAULT NULL COMMENT 'Rural Urban Classification',
    
        LSOA CHAR(9) NOT NULL COMMENT 'Lower Layer Super Output Area (E01, W01, S01, N01)',
        MSOA CHAR(9) NULL DEFAULT NULL COMMENT 'Middle Layer Super Output Area (E02, W02, S02; England, Wales and Scotland Only)',
        LAD CHAR(9) NOT NULL COMMENT 'Local Authority District (UA-E06/W06, LAD-E07, MD-E08, LB-E09, CA-S12, DCA-N09)',
        CTY CHAR(9) NULL DEFAULT NULL COMMENT 'County (C-E10, MC-E11, IOL-E13, plus LAD-E06; England Only)',
        RGN CHAR(9) NULL DEFAULT NULL COMMENT 'Region (E12; England Only)',
        CTRY CHAR(1) NOT NULL COMMENT 'Country (E92, W92, S92, N92)',
    
        PCS CHAR(5) NOT NULL COMMENT 'PostCode Sector: outcode plus 1st digit incode',
        PCD CHAR(4) NOT NULL COMMENT 'PostCode District: same as outcode',
    	PCT CHAR(7) NOT NULL COMMENT 'Post Town (does not link up to PCA!)',
        PCA CHAR(2) NOT NULL COMMENT 'PostCode Area: letters only in outcode',
    
        TTWA CHAR(9) NOT NULL COMMENT 'Travel To Work Area (E30, W22, S22, N12, K01 for overlapping zones)',
        WARD CHAR(9) NOT NULL COMMENT 'Electoral Ward (E05, W05, S13, N08)',
        PCON CHAR(9) NOT NULL COMMENT 'Westminster Parliamentary Constituency (E14, W07, S14, N06)',
        CED CHAR(9) NULL DEFAULT NULL COMMENT 'County Electoral Division (E58; England Only; Partial Coverage)',
        PAR CHAR(9) NULL DEFAULT NULL COMMENT 'Civil Parish (E04, W04; England and Wales Only; Partial Coverage England Only)',
    
    	BUA CHAR(9) NULL DEFAULT NULL 
    	    COMMENT 'Built-up Area (E34, W37, K05 for overlapping zones; England and Wales Only; Partial Coverage)',
    	BUAS CHAR(9) NULL DEFAULT NULL 
    	    COMMENT 'Built-up Subdivision (E35, W38, K06 for overlapping zones; England and Wales Only; Partial Coverage)',
    	MTC CHAR(9) NULL DEFAULT NULL COMMENT 'Major Town or Centre (J01; England and Wales Only; Partial Coverage)',
    
    	PFN SMALLINT(5) UNSIGNED NULL DEFAULT NULL COMMENT 'Police Force Neighbourhood',
    	PFA CHAR(9) NULL DEFAULT NULL COMMENT 'Police Force Area (E23, W15, S32, N24)',
    
    	LAU2 CHAR(9) NOT NULL COMMENT 'Local Administrative Units 2 (E05, W05, S31, N08)',
    	LAU1 CHAR(9) NOT NULL COMMENT 'Local Administrative Units 1',
    	NTS3 CHAR(5) NOT NULL COMMENT 'Nomenclature of Territorial Units for Statistics 3',
    	NTS2 CHAR(4) NOT NULL COMMENT 'Nomenclature of Territorial Units for Statistics 2',
    	NTS1 CHAR(3) NOT NULL COMMENT 'Nomenclature of Territorial Units for Statistics 1',
    
    	CCG CHAR(9) NOT NULL COMMENT 'Clinical Commissioning Group (E38, W11, S03, ZC)',
    	STP CHAR(9) NOT NULL COMMENT 'Sustainability and Transformation Partnership (E54; England Only)',
    	
        PRIMARY KEY (OA),
    	INDEX oac (oac),
    	INDEX ruc (ruc),
        INDEX LSOA (LSOA),
        INDEX MSOA (MSOA),
        INDEX LAD (LAD),
        INDEX CTY (CTY),
        INDEX RGN (RGN),
        INDEX CTRY (CTRY),
        INDEX PCS (PCS),
        INDEX PCD (PCD),
        INDEX PCT (PCT),
        INDEX PCA (PCA),
        INDEX TTWA (TTWA),
        INDEX WARD (WARD),
        INDEX PCON (PCON),
        INDEX CED (CED),
        INDEX PAR (PAR),
        INDEX BUA (BUA),
    	INDEX BUAS (BUAS),
    	INDEX MTC (MTC),
    	INDEX PFN (PFN),
    	INDEX PFA (PFA),
    	INDEX LAU2 (LAU2),
    	INDEX LAU1 (LAU1),
    	INDEX NTS3 (NTS3),
    	INDEX NTS2 (NTS2),
    	INDEX NTS1 (NTS1),
    	INDEX CCG (CCG),
    	INDEX STP (STP)
    
    ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci ROW_FORMAT=FIXED
"
dbSendQuery(dbc, strSQL)

# LOCATIONS ---------------------------------------------------------------------------------------------------------------------
strSQL <- "
    CREATE TABLE locations (
        location_id CHAR(9) NOT NULL DEFAULT '',
        name CHAR(75) NOT NULL DEFAULT '',
        type CHAR(4) NOT NULL DEFAULT '',
        x_lon DECIMAL(8,6) NULL DEFAULT NULL COMMENT 'longitude for the geometric centroid',
        y_lat DECIMAL(8,6) UNSIGNED NULL DEFAULT NULL COMMENT 'latitude for the geometric centroid',
        wx_lon DECIMAL(8,6) NULL DEFAULT NULL COMMENT 'longitude for the population weigthed centroid',
        wy_lat DECIMAL(8,6) UNSIGNED NULL DEFAULT NULL COMMENT 'latitude for the population weigthed centroid',
        perimeter MEDIUMINT(8) UNSIGNED NULL DEFAULT NULL,
        area INT(10) UNSIGNED NULL DEFAULT NULL,
        PRIMARY KEY (location_id),
        INDEX (type)
    ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci ROW_FORMAT=FIXED
"
dbSendQuery(dbc, strSQL)

# NEIGHBOURS --------------------------------------------------------------------------------------------------------------------
strSQL = "
    CREATE TABLE neighbours (
        type_code CHAR(4) NOT NULL,
        location_id CHAR(9) NOT NULL,
        neighbour_id CHAR(9) NOT NULL,
        distance MEDIUMINT(7) UNSIGNED NOT NULL 
            COMMENT 'Vincenty (ellipsoid) great circle distance, see http://www.movable-type.co.uk/scripts/latlong-vincenty.html',
        INDEX (type_code),
        INDEX (location_id),
        INDEX (neighbour_id)
    ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci ROW_FORMAT=FIXED;
"
dbSendQuery(dbc, strSQL)

# DISTANCES ---------------------------------------------------------------------------------------------------------------------
strSQL = "
    CREATE TABLE distances (
        type_code CHAR(4) NOT NULL,
        location_a CHAR(9) NOT NULL,
        location_b CHAR(9) NOT NULL,
        distance MEDIUMINT(7) UNSIGNED NOT NULL 
            COMMENT 'Vincenty (ellipsoid) great circle distance, see http://www.movable-type.co.uk/scripts/latlong-vincenty.html',
        INDEX (type_code),
        INDEX (location_a),
        INDEX (location_b)
    ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci ROW_FORMAT=FIXED;
"
dbSendQuery(dbc, strSQL)

# LOOKUPS -----------------------------------------------------------------------------------------------------------------------
strSQL = "
    CREATE TABLE lookups (
        hierarchy_id SMALLINT(4) UNSIGNED NOT NULL COMMENT 'foreign key to hierarchies.hierarchy_id',
    	child_id CHAR(9)  NOT NULL,
    	parent_id CHAR(9) NOT NULL,
        INDEX (hierarchy_id),
        INDEX (child_id),
        INDEX (parent_id)
    ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci ROW_FORMAT=FIXED;
"
dbSendQuery(dbc, strSQL)

# HIERARCHIES -------------------------------------------------------------------------------------------------------------------
strSQL = "
    CREATE TABLE hierarchies (
        hierarchy_id SMALLINT(4) UNSIGNED NOT NULL,
    	child_type CHAR(4) NOT NULL,
    	parent_type CHAR(4) NOT NULL,
        is_exact TINYINT(1) UNSIGNED NOT NULL,
    	listing TINYINT(1) UNSIGNED NOT NULL,
    	charting TINYINT(1) UNSIGNED NOT NULL,
    	filtering TINYINT(1) UNSIGNED NOT NULL,
    	mapping TINYINT(1) UNSIGNED NOT NULL,
        countries CHAR(4) NOT NULL,
        PRIMARY KEY (hierarchy_id),
        INDEX (child_type),
        INDEX (parent_type),
        INDEX (is_exact),
        INDEX (listing),
        INDEX (charting),
        INDEX (filtering),
        INDEX (mapping),
        INDEX (countries)
    ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci ROW_FORMAT=FIXED;
"
dbSendQuery(dbc, strSQL)
y <- read.csv(file.path(in_path, 'hierarchies.csv'))
dbWriteTable(dbc, 'hierarchies', y, row.names = FALSE, append = TRUE)
write.fst(y, file.path(out_path, 'hierarchies'))

# TYPES -------------------------------------------------------------------------------------------------------------------------
strSQL = "
    CREATE TABLE types (
        type_code CHAR(4) NOT NULL,
    	name CHAR(50) NOT NULL,
    	theme CHAR(15) NOT NULL,
        ordering TINYINT(2) UNSIGNED NOT NULL,
        PRIMARY KEY (type_code)
    ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci ROW_FORMAT=FIXED;
"
dbSendQuery(dbc, strSQL)
y <- read.csv(file.path(in_path, 'types.csv'))
dbWriteTable(dbc, 'types', y, row.names = FALSE, append = TRUE)
write.fst(y, file.path(out_path, 'types'))

# OAC ---------------------------------------------------------------------------------------------------------------------------
strSQL <- "
    CREATE TABLE oac (
    	subgroup_id SMALLINT(3) UNSIGNED NOT NULL,
    	subgroup CHAR(3) NOT NULL,
    	subgroup_desc CHAR(50) NOT NULL,
    	group_id TINYINT(2) UNSIGNED NOT NULL,
    	`group` CHAR(2) NOT NULL,
    	group_desc CHAR(40) NOT NULL,
    	supergroup_id TINYINT(1) UNSIGNED NOT NULL,
    	supergroup_desc CHAR(30) NOT NULL,
    	PRIMARY KEY (subgroup_id),
    	UNIQUE INDEX subgroup (subgroup),
    	INDEX group_id (group_id),
    	INDEX `group` (`group`),
    	INDEX supergroup_id (supergroup_id)
    ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci ROW_FORMAT=FIXED
"
dbSendQuery(dbc, strSQL)
y <- fread(file.path(in_path, 'oac.csv'))
dbWriteTable(dbc, 'oac', y, row.names = FALSE, append = TRUE)
cols <- c('subgroup', 'group')
y[, (cols) := lapply(.SD, as.factor), .SDcols = cols]
write.fst(y, file.path(out_path, 'oac'))

# RUC ---------------------------------------------------------------------------------------------------------------------------
strSQL <- "
    CREATE TABLE ruc (
    	area_id TINYINT(2) UNSIGNED NOT NULL,
    	area CHAR(2) NOT NULL,
    	name CHAR(50) NOT NULL,
    	description CHAR(250) NOT NULL,
    	rank CHAR(2) NOT NULL,
    	country CHAR(2) NOT NULL,
    	PRIMARY KEY (area_id),
    	UNIQUE INDEX area_type (area)
    ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci ROW_FORMAT=FIXED
"
dbSendQuery(dbc, strSQL)
y <- fread(file.path(in_path, 'ruc.csv'))
dbWriteTable(dbc, 'ruc', y, row.names = FALSE, append = TRUE)
cols <- c('area', 'name', 'rank')
y[, (cols) := lapply(.SD, as.factor), .SDcols = cols]
write.fst(y, file.path(out_path, 'ruc'))

# CLEAN & EXIT ------------------------------------------------------------------------------------------------------------------
dbDisconnect(dbc)
rm(list = ls())
gc()
