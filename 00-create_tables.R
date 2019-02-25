###############################################################
# UK GEOGRAPHY * 00 - Create database and tables
###############################################################
# You need to provide the following CSV in data_path:
#  - hierarchies
#  - types
#  - OAC and RUC codes and names 
#  - mosaic groups and types

# Load packages ---------------------------------------------------------------------------------------------
library(RMySQL)

# Set variables ---------------------------------------------------------------------------------------------
data_path <- file.path(Sys.getenv('PUB_PATH'), 'ancillaries', 'geography_uk')

# Create database -------------------------------------------------------------------------------------------
dbc = dbConnect(MySQL(), group = 'dataOps')
dbSendQuery(dbc, 'DROP DATABASE IF EXISTS geography_uk')
dbSendQuery(dbc, 'CREATE DATABASE geography_uk')
dbDisconnect(dbc)

# Connect to database ---------------------------------------------------------------------------------------
dbc = dbConnect(MySQL(), group = 'geography_uk')

# POSTCODES -------------------------------------------------------------------------------------------------
strSQL <- "
    CREATE TABLE postcodes (
	
        postcode CHAR(7) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'postcode in 7-chars format: 4-chars outcode + 3-chars incode',
        is_active TINYINT(1) UNSIGNED NOT NULL COMMENT '0- terminated, 1- live',
        usertype TINYINT(1) UNSIGNED NOT NULL COMMENT '0- small user, 1- large user (large means addresses receiving more than 25 items per day)',
        x_lon DECIMAL(7,6) NOT NULL COMMENT 'longitude of the geometric centroid of the postcode',
        y_lat DECIMAL(8,6) UNSIGNED NOT NULL COMMENT 'latitude of the geometric centroid of the postcode',
        mosaic_type CHAR(3) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT '',
        population SMALLINT(5) UNSIGNED NULL COMMENT '',
        households SMALLINT(5) UNSIGNED NULL COMMENT '',

        OA CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Output Area (E00, W00, S00, N00)',
        LSOA CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Lower Layer Super Output Area (E01, W01, S01, N01)',
        MSOA CHAR(9) NULL DEFAULT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Middle Layer Super Output Area (E02, W02, S02; England, Wales and Scotland Only)',
        LAD CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Local Authority District (UA-E06/W06, LAD-E07, MD-E08, LB-E09, CA-S12, DCA-N09)',
        CTY CHAR(9) NULL DEFAULT NULL COLLATE 'utf8_unicode_ci' COMMENT 'County (C-E10, MC-E11, IOL-E13, plus LAD-E06; England Only)',
        RGN CHAR(9) NULL DEFAULT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Region (E12; England Only)',
        CTRY CHAR(1) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Country (E92, W92, S92, N92)',

        PCS CHAR(5) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'PostCode Sector: outcode plus 1st digit incode',
        PCD CHAR(4) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'PostCode District: same as outcode',
        PCA CHAR(2) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'PostCode Area: letters only in outcode',

        TTWA CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Travel To Work Area (E30, W22, S22, N12, K01 for overlapping zones)',
        WARD CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Electoral Ward (E05, W05, S13, N08)',
        PCON CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Westminster Parliamentary Constituency (E14, W07, S14, N06)',
        CED CHAR(9) NULL DEFAULT NULL COLLATE 'utf8_unicode_ci' COMMENT 'County Electoral Division (E58; England Only; Partial Coverage)',
        PAR CHAR(9) NULL DEFAULT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Civil Parish (E04, W04; England and Wales Only; Partial Coverage England Only)',

    	BUA CHAR(9) NULL DEFAULT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Built-up Area (E34, W37, K05 for overlapping zones; England and Wales Only; Partial Coverage)',
    	BUAS CHAR(9) NULL DEFAULT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Built-up Subdivision (E35, W38, K06 for overlapping zones; England and Wales Only; Partial Coverage)',
    	WPZ CHAR(9) NULL DEFAULT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Workplace Zone (E33, W35, S34, N19)',

    	PFA CHAR(9) NULL DEFAULT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Police Force Area (E23, W15, S32, N24)',
    	CCG CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Clinical Commissioning Group (E38, W11, S03, ZC)',
    	STP CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Sustainability and Transformation Partnership (E54; England Only)',
    	LAU2 CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Local Administrative Units 2 (E05, W05, S31, N08)',

        PRIMARY KEY (postcode),
        INDEX (OA),
        INDEX (is_active),
        INDEX (usertype),
        INDEX (mosaic_type)
		
    ) COLLATE='utf8_unicode_ci' ENGINE=MyISAM ROW_FORMAT=FIXED
"
dbSendQuery(dbc, strSQL)

# INDICES ---------------------------------------------------------------------------------------------------
strSQL <- "
    CREATE TABLE indices (
        idx TINYINT(3) UNSIGNED NOT NULL COMMENT '1- OAC, 2- RUC, 3- IMD, 4- HI',
        location_id CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
        value MEDIUMINT(8) UNSIGNED NOT NULL,
        PRIMARY KEY (location_id, idx),
        INDEX (location_id),
        INDEX (idx)
    ) COLLATE='utf8_unicode_ci' ENGINE=MyISAM ROW_FORMAT=FIXED
"
dbSendQuery(dbc, strSQL)

# OUTPUT AREAS ------------------------------------------------------------------------------------------
strSQL <- "
    CREATE TABLE output_areas (
    
        OA CHAR(9) NOT NULL COMMENT 'Output Area' COLLATE 'utf8_unicode_ci',
        x_lon DECIMAL(7,6) NULL DEFAULT NULL COMMENT 'longitude for the geometric centroid',
        y_lat DECIMAL(8,6) UNSIGNED NULL DEFAULT NULL COMMENT 'latitude for the geometric centroid',
        wx_lon DECIMAL(7,6) NULL DEFAULT NULL COMMENT 'longitude for the population weigthed centroid',
        wy_lat DECIMAL(8,6) UNSIGNED NULL DEFAULT NULL COMMENT 'latitude for the population weigthed centroid',
        perimeter MEDIUMINT(8) UNSIGNED NULL DEFAULT NULL,
        area INT(10) UNSIGNED NULL DEFAULT NULL,
    	tot_uprn SMALLINT(5) UNSIGNED NULL DEFAULT NULL COMMENT 'Total unique spatial addresses',
    	oac SMALLINT(3) UNSIGNED NULL DEFAULT NULL COMMENT 'Output Area Classification',
    	ruc TINYINT(3) UNSIGNED NULL DEFAULT NULL COMMENT 'Rural Urban Classification',
    
        LSOA CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Lower Layer Super Output Area (E01, W01, S01, N01)',
        MSOA CHAR(9) NULL DEFAULT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Middle Layer Super Output Area (E02, W02, S02; England, Wales and Scotland Only)',
        LAD CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Local Authority District (UA-E06/W06, LAD-E07, MD-E08, LB-E09, CA-S12, DCA-N09)',
        CTY CHAR(9) NULL DEFAULT NULL COLLATE 'utf8_unicode_ci' COMMENT 'County (C-E10, MC-E11, IOL-E13, plus LAD-E06; England Only)',
        RGN CHAR(9) NULL DEFAULT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Region (E12; England Only)',
        CTRY CHAR(1) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Country (E92, W92, S92, N92)',
    
        PCS CHAR(5) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'PostCode Sector: outcode plus 1st digit incode',
        PCD CHAR(4) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'PostCode District: same as outcode',
    	PCT CHAR(7) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Post Town (does not link up to PCA!)' COLLATE 'utf8_unicode_ci',
        PCA CHAR(2) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'PostCode Area: letters only in outcode',
    
        TTWA CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Travel To Work Area (E30, W22, S22, N12, K01 for overlapping zones)',
        WARD CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Electoral Ward (E05, W05, S13, N08)',
        PCON CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Westminster Parliamentary Constituency (E14, W07, S14, N06)',
        CED CHAR(9) NULL DEFAULT NULL COLLATE 'utf8_unicode_ci' COMMENT 'County Electoral Division (E58; England Only; Partial Coverage)',
        PAR CHAR(9) NULL DEFAULT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Civil Parish (E04, W04; England and Wales Only; Partial Coverage England Only)',
    
    	BUA CHAR(9) NULL DEFAULT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Built-up Area (E34, W37, K05 for overlapping zones; England and Wales Only; Partial Coverage)',
    	BUAS CHAR(9) NULL DEFAULT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Built-up Subdivision (E35, W38, K06 for overlapping zones; England and Wales Only; Partial Coverage)',
    	MTC CHAR(9) NULL DEFAULT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Major Town or Centre (J01; England and Wales Only; Partial Coverage)',
    
    	PFN SMALLINT(5) UNSIGNED NULL DEFAULT NULL COMMENT 'Police Force Neighbourhood',
    	PFA CHAR(9) NULL DEFAULT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Police Force Area (E23, W15, S32, N24)',
    
    	LAU2 CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Local Administrative Units 2 (E05, W05, S31, N08)',
    	LAU1 CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Local Administrative Units 1',
    	NTS3 CHAR(5) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Nomenclature of Territorial Units for Statistics 3',
    	NTS2 CHAR(4) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Nomenclature of Territorial Units for Statistics 2',
    	NTS1 CHAR(3) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Nomenclature of Territorial Units for Statistics 1',
    
    	CCG CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Clinical Commissioning Group (E38, W11, S03, ZC)',
    	STP CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Sustainability and Transformation Partnership (E54; England Only)',
    	
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
    
    ) COLLATE='utf8_unicode_ci' ENGINE=MyISAM ROW_FORMAT=FIXED
"
dbSendQuery(dbc, strSQL)

# LOCATIONS -------------------------------------------------------------------------------------------------
strSQL <- "
    CREATE TABLE locations (
        location_id CHAR(9) NOT NULL DEFAULT '' COLLATE 'utf8_unicode_ci',
        name CHAR(75) NOT NULL DEFAULT '' COLLATE 'utf8_unicode_ci',
        type CHAR(4) NOT NULL DEFAULT '' COLLATE 'utf8_unicode_ci',
        x_lon DECIMAL(8,6) NULL DEFAULT NULL COMMENT 'longitude for the geometric centroid',
        y_lat DECIMAL(8,6) UNSIGNED NULL DEFAULT NULL COMMENT 'latitude for the geometric centroid',
        wx_lon DECIMAL(8,6) NULL DEFAULT NULL COMMENT 'longitude for the population weigthed centroid',
        wy_lat DECIMAL(8,6) UNSIGNED NULL DEFAULT NULL COMMENT 'latitude for the population weigthed centroid',
        perimeter MEDIUMINT(8) UNSIGNED NULL DEFAULT NULL,
        area INT(10) UNSIGNED NULL DEFAULT NULL,
        PRIMARY KEY (location_id),
        INDEX (type)
    ) COLLATE='utf8_unicode_ci' ENGINE=MyISAM ROW_FORMAT=FIXED
"
dbSendQuery(dbc, strSQL)


# LOOKUPS ---------------------------------------------------------------------------------------------------
strSQL = "
    CREATE TABLE lookups (
        hierarchy_id SMALLINT(4) UNSIGNED NOT NULL COMMENT 'foreign key to hierarchies.hierarchy_id',
    	child_id CHAR(9)  NOT NULL COLLATE 'utf8_unicode_ci',
    	parent_id CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
        INDEX (hierarchy_id),
        INDEX (child_id),
        INDEX (parent_id)
    ) COLLATE='utf8_unicode_ci' ENGINE=MyISAM ROW_FORMAT=FIXED;
"
dbSendQuery(dbc, strSQL)

# HIERARCHIES ---------------------------------------------------------------------------------------------------
strSQL = "
    CREATE TABLE hierarchies (
        hierarchy_id SMALLINT(4) UNSIGNED NOT NULL,
    	child_type CHAR(4) NOT NULL COLLATE 'utf8_unicode_ci',
    	parent_type CHAR(4) NOT NULL COLLATE 'utf8_unicode_ci',
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
    ) COLLATE='utf8_unicode_ci' ENGINE=MyISAM ROW_FORMAT=FIXED;
"
dbSendQuery(dbc, strSQL)
y <- read.csv(file.path(data_path, 'hierarchies.csv'))
dbWriteTable(dbc, 'hierarchies', y, row.names = FALSE, append = TRUE)

# TYPES ---------------------------------------------------------------------------------------------------
strSQL = "
    CREATE TABLE types (
        type_code CHAR(4) NOT NULL COLLATE 'utf8_unicode_ci',
    	name CHAR(50) NOT NULL COLLATE 'utf8_unicode_ci',
    	theme CHAR(15) NOT NULL COLLATE 'utf8_unicode_ci',
        ordering TINYINT(2) UNSIGNED NOT NULL,
        PRIMARY KEY (type_code)
    ) COLLATE='utf8_unicode_ci' ENGINE=MyISAM ROW_FORMAT=FIXED;
"
dbSendQuery(dbc, strSQL)
y <- read.csv(file.path(data_path, 'types.csv'))
dbWriteTable(dbc, 'types', y, row.names = FALSE, append = TRUE)

# OAC -------------------------------------------------------------------------------------------------------
strSQL <- "
    CREATE TABLE oac (
    	subgroup_id SMALLINT(3) UNSIGNED NOT NULL,
    	subgroup CHAR(3) NOT NULL COLLATE 'utf8_unicode_ci',
    	subgroup_desc CHAR(50) NOT NULL COLLATE 'utf8_unicode_ci',
    	group_id TINYINT(2) UNSIGNED NOT NULL,
    	`group` CHAR(2) NOT NULL COLLATE 'utf8_unicode_ci',
    	group_desc CHAR(40) NOT NULL COLLATE 'utf8_unicode_ci',
    	supergroup_id TINYINT(1) UNSIGNED NOT NULL,
    	supergroup_desc CHAR(30) NOT NULL COLLATE 'utf8_unicode_ci',
    	PRIMARY KEY (subgroup_id),
    	UNIQUE INDEX subgroup (subgroup),
    	INDEX group_id (group_id),
    	INDEX `group` (`group`),
    	INDEX supergroup_id (supergroup_id)
    ) COLLATE='utf8_unicode_ci' ENGINE=MyISAM ROW_FORMAT=FIXED
"
dbSendQuery(dbc, strSQL)
y <- read.csv(file.path(data_path, 'oac.csv'))
dbWriteTable(dbc, 'oac', y, row.names = FALSE, append = TRUE)

# RUC -------------------------------------------------------------------------------------------------------
strSQL <- "
    CREATE TABLE ruc (
    	area_id TINYINT(2) UNSIGNED NOT NULL,
    	area CHAR(2) NOT NULL COLLATE 'utf8_unicode_ci',
    	name CHAR(50) NOT NULL COLLATE 'utf8_unicode_ci',
    	description CHAR(250) NOT NULL COLLATE 'utf8_unicode_ci',
    	rank CHAR(2) NOT NULL COLLATE 'utf8_unicode_ci',
    	country CHAR(2) NOT NULL COLLATE 'utf8_unicode_ci',
    	PRIMARY KEY (area_id),
    	UNIQUE INDEX area_type (area)
    ) COLLATE='utf8_unicode_ci' ENGINE=MyISAM ROW_FORMAT=FIXED
"
dbSendQuery(dbc, strSQL)
y <- read.csv(file.path(data_path, 'ruc.csv'))
dbWriteTable(dbc, 'ruc', y, row.names = FALSE, append = TRUE)

# MOSAIC: GROUPS --------------------------------------------------------------------------------------------
strSQL <- "
    CREATE TABLE mosaic_groups (
    	group_code CHAR(1) NOT NULL COLLATE 'utf8_unicode_ci',
    	group_id TINYINT(2) UNSIGNED NOT NULL,
    	name CHAR(20) NOT NULL COLLATE 'utf8_unicode_ci',
    	description CHAR(100) NOT NULL COLLATE 'utf8_unicode_ci',
    	population MEDIUMINT(8) UNSIGNED NOT NULL,
    	households MEDIUMINT(8) UNSIGNED NOT NULL,
    	PRIMARY KEY (group_id),
    	UNIQUE INDEX group_code (group_code)
    ) COLLATE='utf8_unicode_ci' ENGINE=MyISAM ROW_FORMAT=FIXED
"
dbSendQuery(dbc, strSQL)
y <- read.csv(file.path(data_path, 'mosaic_groups.csv'))
dbWriteTable(dbc, 'mosaic_groups', y, row.names = FALSE, append = TRUE)

# MOSAIC: TYPES ---------------------------------------------------------------------------------------------
strSQL <- "
    CREATE TABLE mosaic_types (
    	type_code CHAR(3) NOT NULL COLLATE 'utf8_unicode_ci',
    	type_id TINYINT(3) UNSIGNED NOT NULL,
    	name CHAR(30) NOT NULL COLLATE 'utf8_unicode_ci',
    	description CHAR(125) NOT NULL COLLATE 'utf8_unicode_ci',
    	group_code CHAR(1) NOT NULL COLLATE 'utf8_unicode_ci',
    	group_id TINYINT(2) UNSIGNED NOT NULL,
    	population MEDIUMINT(8) UNSIGNED NOT NULL,
    	households MEDIUMINT(8) UNSIGNED NOT NULL,
    	PRIMARY KEY (type_id),
    	UNIQUE INDEX type_code (type_code),
    	INDEX group_code (group_code),
    	INDEX group_id (group_id)
    ) COLLATE='utf8_unicode_ci' ENGINE=MyISAM ROW_FORMAT=FIXED
"
dbSendQuery(dbc, strSQL)
y <- read.csv(file.path(data_path, 'mosaic_types.csv'))
dbWriteTable(dbc, 'mosaic_types', y, row.names = FALSE, append = TRUE)

# # DISTANCES -------------------------------------------------------------------------------------------------
# strSQL = "
#     CREATE TABLE distances (
#         postcode CHAR(7) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'foreign key to postcodes.postcode',
#         venue_id TINYINT(2) UNSIGNED NOT NULL COMMENT 'foreign key to venues.venue_id',
#         distance MEDIUMINT(7) UNSIGNED NOT NULL COMMENT 'Vincenty (ellipsoid) great circle distance, see http://www.movable-type.co.uk/scripts/latlong-vincenty.html',
#         PRIMARY KEY (postcode, venue_id),
#         INDEX (postcode),
#         INDEX (venue_id)
#     ) COLLATE='utf8_unicode_ci' ENGINE=MyISAM ROW_FORMAT=FIXED;
# "
# dbSendQuery(dbc, strSQL)

# CLEAN & EXIT ----------------------------------------------------------------------------------------------
dbDisconnect(dbc)
rm(list = ls())
gc()



