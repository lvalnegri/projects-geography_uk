###############################################################
# 00- CREATE TABLES
###############################################################
library(RMySQL)
db_conn = dbConnect(MySQL(), group = 'homeserver-out', dbname = 'geographyUK')

# POSTCODES ---------------------------------------------------------------------------------------------------------------------
strSQL <- "
    CREATE TABLE postcodes (
    	postcode CHAR(7) NOT NULL COLLATE 'utf8_unicode_ci',
    	is_active TINYINT(1) UNSIGNED NOT NULL,
    	usertype TINYINT(1) UNSIGNED NOT NULL,
    	X_lon DECIMAL(7,6) NOT NULL,
    	Y_lat DECIMAL(8,6) UNSIGNED NOT NULL,
    	OA CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	LSOA CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	MSOA CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	LAD CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	CTY CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	RGN CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	CTRY CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	WARD CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	PCON CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	TTWA CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	WKZ CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	PFA CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	PCS CHAR(5) NOT NULL COLLATE 'utf8_unicode_ci',
    	PCD CHAR(4) NOT NULL COLLATE 'utf8_unicode_ci',
    	PCA CHAR(2) NOT NULL COLLATE 'utf8_unicode_ci',
    	PAR CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	LAU2 CHAR(10) NOT NULL COLLATE 'utf8_unicode_ci',
    	LLSC CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	LEA CHAR(3) NOT NULL COLLATE 'utf8_unicode_ci',
    	CCG CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	LAT CHAR(3) NOT NULL COLLATE 'utf8_unicode_ci',
    	NHSR CHAR(3) NOT NULL COLLATE 'utf8_unicode_ci',
    	PCT CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	SHA CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	SHAO CHAR(3) NOT NULL COLLATE 'utf8_unicode_ci',
    	SCN CHAR(3) NOT NULL COLLATE 'utf8_unicode_ci',
    	CNR CHAR(5) NOT NULL COLLATE 'utf8_unicode_ci',
    	PRIMARY KEY (postcode),
    	INDEX (OA),
    	INDEX (is_active),
    	INDEX (usertype)
    ) COLLATE='utf8_unicode_ci' ENGINE=MyISAM ROW_FORMAT=FIXED
"
dbSendQuery(db_conn, strSQL)

# LOOKUPS (or OAs) --------------------------------------------------------------------------------------------------------------
strSQL <- "
    CREATE TABLE lookups (
    	OA CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	X_lon DECIMAL(7,6) NOT NULL,
    	Y_lat DECIMAL(8,6) UNSIGNED NOT NULL,
    	LSOA CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	MSOA CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	LAD CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	CTY CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	RGN CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	CTRY CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	MCT CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	WARD CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	PCON CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	TTWA CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	WKZ CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	PFA CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	PCS CHAR(5) NOT NULL COLLATE 'utf8_unicode_ci',
    	PCD CHAR(4) NOT NULL COLLATE 'utf8_unicode_ci',
    	PCA CHAR(2) NOT NULL COLLATE 'utf8_unicode_ci',
    	PAR CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	LAU2 CHAR(10) NOT NULL COLLATE 'utf8_unicode_ci',
    	LAU1 CHAR(10) NOT NULL COLLATE 'utf8_unicode_ci',
    	NTS3 CHAR(10) NOT NULL COLLATE 'utf8_unicode_ci',
    	NTS2 CHAR(10) NOT NULL COLLATE 'utf8_unicode_ci',
    	NTS1 CHAR(10) NOT NULL COLLATE 'utf8_unicode_ci',
    	LLSC CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	LEA CHAR(3) NOT NULL COLLATE 'utf8_unicode_ci',
    	CCG CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	LAT CHAR(3) NOT NULL COLLATE 'utf8_unicode_ci',
    	NHSR CHAR(3) NOT NULL COLLATE 'utf8_unicode_ci',
    	PCT CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	SHA CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	SHAO CHAR(3) NOT NULL COLLATE 'utf8_unicode_ci',
    	SCN CHAR(3) NOT NULL COLLATE 'utf8_unicode_ci',
    	CNR CHAR(5) NOT NULL COLLATE 'utf8_unicode_ci',
    	PRIMARY KEY (OA),
    	INDEX (LSOA),
    	INDEX (MSOA),
    	INDEX (LAD),
    	INDEX (CTY),
    	INDEX (RGN),
    	INDEX (CTRY),
    	INDEX (MCT),
    	INDEX (WARD),
    	INDEX (PCON),
    	INDEX (TTWA),
    	INDEX (WKZ),
    	INDEX (PFA),
    	INDEX (PCS),
    	INDEX (PCD),
    	INDEX (PCA),
    	INDEX (PAR),
    	INDEX (LAU2),
    	INDEX (LAU1),
    	INDEX (NTS3),
    	INDEX (NTS2),
    	INDEX (NTS1),
    	INDEX (LLSC),
    	INDEX (LEA),
    	INDEX (CCG),
    	INDEX (LAT),
    	INDEX (NHSR),
    	INDEX (PCT),
    	INDEX (SHA),
    	INDEX (SHAO),
    	INDEX (SCN),
    	INDEX (CNR)
    ) COLLATE='utf8_unicode_ci' ENGINE=MyISAM ROW_FORMAT=FIXED
"
dbSendQuery(db_conn, strSQL)

# LOCATIONS ---------------------------------------------------------------------------------------------------------------------
strSQL <- "
    CREATE TABLE locations (
    	id CHAR(15) NOT NULL COLLATE 'utf8_unicode_ci',
    	name CHAR(75) NOT NULL COLLATE 'utf8_unicode_ci',
    	area CHAR(4) NOT NULL COLLATE 'utf8_unicode_ci',
    	parent CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	X_lon DECIMAL(8,6) NOT NULL,
    	Y_lat DECIMAL(8,6) UNSIGNED NOT NULL,
    	PRIMARY KEY (id, area),
    	INDEX parent (parent),
    	INDEX type (area),
    	INDEX id (id)
    ) COLLATE='utf8_unicode_ci' ENGINE=MyISAM ROW_FORMAT=FIXED
"
dbSendQuery(db_conn, strSQL)

# INDICES -----------------------------------------------------------------------------------------------------------------------
strSQL <- "
    CREATE TABLE  (
    	loca_id CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci',
    	index TINYINT(3) UNSIGNED NOT NULL COMMENT '1- OAC, 2- RUC, 3- IMD, 4- HI',
        period MEDIUMINT(6) UNSIGNED NOT NULL,
    	value MEDIUMINT(8) UNSIGNED NOT NULL,
    	PRIMARY KEY (loca_id, period, index),
    	INDEX (loca_id),
    	INDEX (period),
    	INDEX (index)
    ) COLLATE='utf8_unicode_ci' ENGINE=MyISAM ROW_FORMAT=FIXED
"
dbSendQuery(db_conn, strSQL)

# BOUNDARIES --------------------------------------------------------------------------------------------------------------------
strSQL <- "
    CREATE TABLE boundaries (
    ) COLLATE='utf8_unicode_ci' ENGINE=MyISAM
"
dbSendQuery(db_conn, strSQL)

# BOUNDARIES <=> LOCATIONS -----------------------------------------------------------------------------------------------------
strSQL <- "
    CREATE TABLE boundaries_locations (
    ) COLLATE='utf8_unicode_ci' ENGINE=MyISAM ROW_FORMAT=FIXED
"
dbSendQuery(db_conn, strSQL)

# CLEAN & EXIT ----------------------------------------------------------------------------------------------------------
dbDisconnect(db_conn)
rm(list = ls())
gc()
