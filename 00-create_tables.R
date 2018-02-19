###############################################################
# 00- CREATE TABLES
###############################################################
library(RMySQL)
db_conn = dbConnect(MySQL(), group = 'dataOps', dbname = 'geography_uk')

# POSTCODES ---------------------------------------------------------------------------------------------------------------------
strSQL <- "
    CREATE TABLE postcodes (
    	postcode CHAR(7) NOT NULL COLLATE 'utf8_unicode_ci',
    	is_active TINYINT(1) UNSIGNED NOT NULL,
    	usertype TINYINT(1) UNSIGNED NOT NULL,
    	x_lon DECIMAL(7,6) NOT NULL,
    	y_lat DECIMAL(8,6) UNSIGNED NOT NULL,
    	OA CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	LSOA CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	MSOA CHAR(9) NULL DEFAULT NULL COLLATE 'utf8_unicode_ci',
    	LAD CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	CTY CHAR(9) NULL DEFAULT NULL COLLATE 'utf8_unicode_ci',
    	RGN CHAR(9) NULL DEFAULT NULL COLLATE 'utf8_unicode_ci',
    	CTRY CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	BUA CHAR(9) NULL DEFAULT NULL COLLATE 'utf8_unicode_ci',
    	BUAS CHAR(9) NULL DEFAULT NULL COLLATE 'utf8_unicode_ci',
    	WARD CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	CED CHAR(9) NULL DEFAULT NULL COLLATE 'utf8_unicode_ci',
    	PCON CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	LAU2 CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	TTWA CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	WPZ CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	PFA CHAR(9) NULL DEFAULT NULL COLLATE 'utf8_unicode_ci',
    	PAR CHAR(9) NULL DEFAULT NULL COLLATE 'utf8_unicode_ci',
    	PCS CHAR(5) NOT NULL COLLATE 'utf8_unicode_ci',
    	PCD CHAR(4) NOT NULL COLLATE 'utf8_unicode_ci',
    	PCA CHAR(2) NOT NULL COLLATE 'utf8_unicode_ci',
    	CCG CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	LAT CHAR(3) NOT NULL COLLATE 'utf8_unicode_ci',
    	NHSR CHAR(3) NOT NULL COLLATE 'utf8_unicode_ci',
    	PCT CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	SHA CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	PRIMARY KEY (postcode),
    	INDEX (OA),
    	INDEX (is_active),
    	INDEX (usertype)
    ) COLLATE='utf8_unicode_ci' ENGINE=MyISAM ROW_FORMAT=FIXED
"
dbSendQuery(db_conn, strSQL)

# UPRNS -------------------------------------------------------------------------------------------------------------------------
dbSendQuery(db_conn, "CREATE TABLE uprns SELECT oa FROM lookups")

# INDICES -----------------------------------------------------------------------------------------------------------------------
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
dbSendQuery(db_conn, strSQL)

# LOOKUPS (or OAs) --------------------------------------------------------------------------------------------------------------
strSQL <- "
    CREATE TABLE lookups (
    	OA CHAR(9) NOT NULL COMMENT 'Output Area' COLLATE 'utf8_unicode_ci',
    	x_lon DECIMAL(9,8) NOT NULL COMMENT 'longitude for the geographical centroid',
    	y_lat DECIMAL(10,8) UNSIGNED NOT NULL COMMENT 'latitude for the geographical centroid',
    	wx_lon DECIMAL(9,8) NULL DEFAULT NULL COMMENT 'longitude for the population weigthed centroid',
    	wy_lat DECIMAL(10,8) UNSIGNED NULL DEFAULT NULL COMMENT 'latitude for the population weigthed centroid',
    	perimeter MEDIUMINT(8) UNSIGNED NULL DEFAULT NULL,
    	area INT(10) UNSIGNED NULL DEFAULT NULL,
    	tot_uprn SMALLINT(5) UNSIGNED NULL DEFAULT NULL,
    	LSOA CHAR(9) NOT NULL COMMENT 'Lower Layer Super Output Area' COLLATE 'utf8_unicode_ci',
    	MSOA CHAR(9) NOT NULL COMMENT 'Middle Layer Super Output Area' COLLATE 'utf8_unicode_ci',
    	LAD CHAR(9) NOT NULL COMMENT 'Local Authority District (LAD) / Unitary Authority (UA) / Metropolitan District (MD) / London Borough (LB) / Council Area (CA) ' COLLATE 'utf8_unicode_ci',
    	CTY CHAR(9) NULL DEFAULT NULL COMMENT 'County (England Only)' COLLATE 'utf8_unicode_ci',
    	RGN CHAR(9) NULL DEFAULT NULL COMMENT 'Region (England Only)' COLLATE 'utf8_unicode_ci',
    	CTRY CHAR(9) NOT NULL COMMENT 'Country' COLLATE 'utf8_unicode_ci',
    	BUAS CHAR(9) NULL DEFAULT NULL COLLATE 'utf8_unicode_ci',
    	BUA CHAR(9) NULL DEFAULT NULL COLLATE 'utf8_unicode_ci',
    	MTC CHAR(9) NULL DEFAULT NULL COLLATE 'utf8_unicode_ci',
    	WARD CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	CED CHAR(9) NULL DEFAULT NULL COLLATE 'utf8_unicode_ci',
    	PCON CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	PFA CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	TTWA CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	PAR CHAR(9) NULL DEFAULT NULL COLLATE 'utf8_unicode_ci',
    	PCS CHAR(5) NOT NULL COLLATE 'utf8_unicode_ci',
    	PCD CHAR(4) NOT NULL COLLATE 'utf8_unicode_ci',
    	PCA CHAR(2) NOT NULL COLLATE 'utf8_unicode_ci',
    	LAU2 CHAR(10) NOT NULL COLLATE 'utf8_unicode_ci',
    	LAU1 CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	NTS3 CHAR(5) NOT NULL COLLATE 'utf8_unicode_ci',
    	NTS2 CHAR(4) NOT NULL COLLATE 'utf8_unicode_ci',
    	NTS1 CHAR(3) NOT NULL COLLATE 'utf8_unicode_ci',
    	CCG CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	LAT CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	NHSR CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	CCR CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	PCT CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	SHA CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	PRIMARY KEY (OA),
    	INDEX LSOA (LSOA),
    	INDEX MSOA (MSOA),
    	INDEX LAD (LAD),
    	INDEX CTY (CTY),
    	INDEX RGN (RGN),
    	INDEX CTRY (CTRY),
    	INDEX MCT (MTC),
    	INDEX WARD (WARD),
    	INDEX CED (CED),
    	INDEX PCON (PCON),
    	INDEX TTWA (TTWA),
    	INDEX PFA (PFA),
    	INDEX PCS (PCS),
    	INDEX PCD (PCD),
    	INDEX PCA (PCA),
    	INDEX PAR (PAR),
    	INDEX LAU2 (LAU2),
    	INDEX LAU1 (LAU1),
    	INDEX NTS3 (NTS3),
    	INDEX NTS2 (NTS2),
    	INDEX NTS1 (NTS1),
    	INDEX CCG (CCG),
    	INDEX LAT (LAT),
    	INDEX NHSR (NHSR),
    	INDEX CCR (CCR),
    	INDEX PCT (PCT),
    	INDEX SHA (SHA),
    	INDEX BUAS (BUAS),
    	INDEX BUA (BUA)
    ) COLLATE='utf8_unicode_ci' ENGINE=MyISAM ROW_FORMAT=FIXED
"
dbSendQuery(db_conn, strSQL)

# LOCATIONS ---------------------------------------------------------------------------------------------------------------------
strSQL <- "
    CREATE TABLE locations (
    	location_id CHAR(9) NOT NULL DEFAULT '' COLLATE 'utf8_unicode_ci',
    	name CHAR(75) NOT NULL DEFAULT '' COLLATE 'utf8_unicode_ci',
    	type_id CHAR(4) NOT NULL DEFAULT '' COLLATE 'utf8_unicode_ci',
    	parent_id CHAR(9) NOT NULL DEFAULT '' COLLATE 'utf8_unicode_ci',
    	ordering MEDIUMINT(8) UNSIGNED NULL DEFAULT NULL COMMENT 'ONS rule for official pubblication',
    	x_lon DECIMAL(8,6) NULL DEFAULT NULL COMMENT 'longitude for the weigthed centroid',
    	y_lat DECIMAL(8,6) UNSIGNED NULL DEFAULT NULL COMMENT 'latitude for the weigthed centroid',
    	wx_lon DECIMAL(8,6) NULL DEFAULT NULL COMMENT 'longitude for the population weigthed centroid',
    	wy_lat DECIMAL(8,6) UNSIGNED NULL DEFAULT NULL COMMENT 'latitude for the population weigthed centroid',
    	perimeter MEDIUMINT(8) UNSIGNED NULL DEFAULT NULL,
    	area INT(10) UNSIGNED NULL DEFAULT NULL,
    	PRIMARY KEY (location_id),
    	INDEX (type_id),
    	INDEX (parent_id)
    ) COLLATE='utf8_unicode_ci' ENGINE=MyISAM ROW_FORMAT=FIXED
"
dbSendQuery(db_conn, strSQL)

# CLEAN & EXIT ----------------------------------------------------------------------------------------------------------
dbDisconnect(db_conn)
rm(list = ls())
gc()
