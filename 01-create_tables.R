##################################################
# UK GEOGRAPHY * 01 - Create database and tables #
##################################################

# preliminaries ---------------------------------
pkgs <- c('popiFun', 'data.table', 'fst')
lapply(pkgs, require, char = TRUE)
in_path <- file.path(pub_path, 'ancillaries', 'uk', 'geography')
dbname <- 'geography_uk'

# create database -------------------------------
create_db(dbname)

# POSTCODES -------------------------------------
x <- "
    postcode CHAR(7) NOT NULL COMMENT 'postcode in 7-chars format: 4-chars outcode + 3-chars incode',
    is_active TINYINT(1) UNSIGNED NOT NULL,
    usertype TINYINT(1) UNSIGNED NOT NULL 
        COMMENT '0- small user, 1- large user (large means addresses receiving more than 25 items per day)',
    x_lon DECIMAL(7,6) NOT NULL COMMENT 'longitude of the geometric centroid of the postcode',
    y_lat DECIMAL(8,6) UNSIGNED NOT NULL COMMENT 'latitude of the geometric centroid of the postcode',

    OA CHAR(9) NOT NULL COMMENT 'Output Area (E00, W00, S00, N00)',
    LSOA CHAR(9) NOT NULL COMMENT 'Lower Layer Super Output Area (E01, W01, S01, N01)',
    MSOA CHAR(9) NULL DEFAULT NULL COMMENT 'Middle Layer Super Output Area (E02, W02, S02; England, Wales and Scotland Only)',
    LAD CHAR(9) NOT NULL COMMENT 'Local Authority District (UA-E06/W06, LAD-E07, MD-E08, LB-E09, CA-S12, DCA-N09)',
    CTY CHAR(9) NULL DEFAULT NULL COMMENT 'County (C-E10, MC-E11, IOL-E13, plus LAD-E06; England Only)',
    RGN CHAR(9) NULL DEFAULT NULL COMMENT 'Region (E12; England Only)',
    CTRY CHAR(1) NOT NULL COMMENT 'Country (E92, W92, S92, N92)',

    PCS CHAR(5) NULL DEFAULT NULL COMMENT 'PostCode Sector: outcode plus 1st digit incode',
    PCD CHAR(4) NULL DEFAULT NULL COMMENT 'PostCode District: same as outcode',
    PCT CHAR(7) NULL DEFAULT NULL COMMENT 'Post Town (code is auto-generated)',
    PCA CHAR(2) NULL DEFAULT NULL COMMENT 'PostCode Area: letters only in outcode',

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
	STP CHAR(9) NULL DEFAULT NULL COMMENT 'Sustainability and Transformation Partnership (E54; England Only)',
	CCG CHAR(9) NOT NULL COMMENT 'Clinical Commissioning Group (E38, W11, S03, ZC)',
	NHSO CHAR(9) NOT NULL COMMENT 'NHS Local Office (E39; England Only)',
	NHSR CHAR(9) NOT NULL COMMENT 'NHS Region (E40; England Only)',
	
	I0 INT UNSIGNED NULL DEFAULT NULL COMMENT 'HexGrid spacing half mile',
	I1 INT UNSIGNED NULL DEFAULT NULL COMMENT 'HexGrid spacing 1 mile',
	I2 INT UNSIGNED NULL DEFAULT NULL COMMENT 'HexGrid spacing 2 miles',
	I3 INT UNSIGNED NULL DEFAULT NULL COMMENT 'HexGrid spacing 3 miles',
	I4 INT UNSIGNED NULL DEFAULT NULL COMMENT 'HexGrid spacing 4 miles',
	I5 INT UNSIGNED NULL DEFAULT NULL COMMENT 'HexGrid spacing 5 miles',
	M0 INT UNSIGNED NULL DEFAULT NULL COMMENT 'HexGrid spacing half kilometre',
	M1 INT UNSIGNED NULL DEFAULT NULL COMMENT 'HexGrid spacing 1 kilometre',
	M2 INT UNSIGNED NULL DEFAULT NULL COMMENT 'HexGrid spacing 2 kilometres',
	M3 INT UNSIGNED NULL DEFAULT NULL COMMENT 'HexGrid spacing 3 kilometres',
	M4 INT UNSIGNED NULL DEFAULT NULL COMMENT 'HexGrid spacing 4 kilometres',
	M5 INT UNSIGNED NULL DEFAULT NULL COMMENT 'HexGrid spacing 5 kilometres',

    PRIMARY KEY (postcode),
    INDEX (OA),
    INDEX (is_active),
    INDEX (usertype)
"
create_dbtable('postcodes', dbname, x)

# OUTPUT AREAS ----------------------------------
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
        LAD CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Local Authority District (UA-E06/W06, LAD-E07, MD-E08, LB-E09, CA-S12, DCA-N09)',
        CTY CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'County (C-E10, MC-E11, IOL-E13, plus LAD-E060=>E069; England Only; pseudo: WLS_CTY, SCO_CTY, NIE_CTY)',
        RGN CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Region (E12; England Only; pseudo: WLS_RGN, SCO_RGN, NIE_RGN)',
        CTRY CHAR(3) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Country (E92 = ENG, W92 = WLS, S92 = SCO, N92 = NIE)',
    
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
    	CSP CHAR(9) NULL DEFAULT NULL COMMENT 'Community Safety Partnership (E22, W14; England and Wales Only)',
    	PFA CHAR(9) NULL DEFAULT NULL COMMENT 'Police Force Area (E23, W15, S32, N24)',
    	STP CHAR(9) NOT NULL COMMENT 'Sustainability and Transformation Partnership (E54; England Only)',
    	CCG CHAR(9) NOT NULL COMMENT 'Clinical Commissioning Group (E38, W11, S03, ZC)',
    	NHSO CHAR(9) NOT NULL COMMENT 'NHS Local Office (E39; England Only)',
    	NHSR CHAR(9) NOT NULL COMMENT 'NHS Region (E40; England Only)',
    	
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
    	INDEX STP (STP),
    	INDEX CCG (CCG),
    	INDEX NHSO (NHSO),
    	INDEX NHSR (NHSR)
    
    ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci ROW_FORMAT=FIXED
"
dbSendQuery(dbc, strSQL)

# WORKPLACE ZONES -------------------------------
strSQL <- "
    CREATE TABLE workplace_zones (
    
        WPZ CHAR(9) NOT NULL COMMENT 'Workplace Zone',
        x_lon DECIMAL(7,6) NULL DEFAULT NULL COMMENT 'longitude for the geometric centroid',
        y_lat DECIMAL(8,6) UNSIGNED NULL DEFAULT NULL COMMENT 'latitude for the geometric centroid',
        wx_lon DECIMAL(7,6) NULL DEFAULT NULL COMMENT 'longitude for the population weigthed centroid',
        wy_lat DECIMAL(8,6) UNSIGNED NULL DEFAULT NULL COMMENT 'latitude for the population weigthed centroid',
        perimeter MEDIUMINT(8) UNSIGNED NULL DEFAULT NULL,
        area INT(10) UNSIGNED NULL DEFAULT NULL,
    	tot_uprn SMALLINT(5) UNSIGNED NULL DEFAULT NULL COMMENT 'Total unique spatial addresses',
    	wzc CHAR(2) NULL DEFAULT NULL COMMENT 'Workplace Zones Classification: Group Code; see wzc.group_code',

        MSOA CHAR(9) NULL DEFAULT NULL COMMENT 'Middle Layer Super Output Area (E02, W02, S02; England, Wales and Scotland Only)',
        LAD CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Local Authority District (UA-E06/W06, LAD-E07, MD-E08, LB-E09, CA-S12, DCA-N09)',
        CTY CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'County (C-E10, MC-E11, IOL-E13, plus LAD-E060=>E069; England Only; pseudo: WLS_CTY, SCO_CTY, NIE_CTY)',
        RGN CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Region (E12; England Only; pseudo: WLS_RGN, SCO_RGN, NIE_RGN)',
        CTRY CHAR(3) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Country (E92 = ENG, W92 = WLS, S92 = SCO, N92 = NIE)',

        PRIMARY KEY (WPZ),
    	INDEX wzc (wzc),
        INDEX MSOA (MSOA),
        INDEX LAD (LAD),
        INDEX CTY (CTY),
        INDEX RGN (RGN),
        INDEX CTRY (CTRY)

    ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci ROW_FORMAT=FIXED
"
dbSendQuery(dbc, strSQL)

# LOCATIONS -------------------------------------
strSQL <- "
    CREATE TABLE locations (
        location_type CHAR(4) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'see location_types.location_type',
        location_id CHAR(9) NOT NULL DEFAULT '',
        name CHAR(75) NOT NULL DEFAULT '',
        x_lon DECIMAL(8,6) NULL DEFAULT NULL COMMENT 'longitude for the geometric centroid',
        y_lat DECIMAL(8,6) UNSIGNED NULL DEFAULT NULL COMMENT 'latitude for the geometric centroid',
        wx_lon DECIMAL(8,6) NULL DEFAULT NULL COMMENT 'longitude for the population weigthed centroid',
        wy_lat DECIMAL(8,6) UNSIGNED NULL DEFAULT NULL COMMENT 'latitude for the population weigthed centroid',
        perimeter MEDIUMINT(8) UNSIGNED NULL DEFAULT NULL,
        area INT(10) UNSIGNED NULL DEFAULT NULL,
        PRIMARY KEY (location_id),
        INDEX (location_type)
    ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci ROW_FORMAT=FIXED
"
dbSendQuery(dbc, strSQL)

# NEIGHBOURS ------------------------------------
strSQL = "
    CREATE TABLE neighbours (
        location_type CHAR(4) NOT NULL,
        location_id CHAR(9) NOT NULL,
        neighbour_id CHAR(9) NOT NULL,
        distance MEDIUMINT(7) UNSIGNED NOT NULL 
            COMMENT 'Vincenty (ellipsoid) great circle distance, see http://www.movable-type.co.uk/scripts/latlong-vincenty.html',
        INDEX (location_type),
        INDEX (location_id),
        INDEX (neighbour_id)
    ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci ROW_FORMAT=FIXED;
"
dbSendQuery(dbc, strSQL)

# DISTANCES -------------------------------------
strSQL = "
    CREATE TABLE distances (
        location_type CHAR(4) NOT NULL,
        location_ida CHAR(9) NOT NULL,
        location_idb CHAR(9) NOT NULL,
        distance MEDIUMINT(7) UNSIGNED NOT NULL 
            COMMENT 'Vincenty (ellipsoid) great circle distance, see http://www.movable-type.co.uk/scripts/latlong-vincenty.html',
        INDEX (location_type),
        INDEX (location_ida),
        INDEX (location_idb)
    ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci ROW_FORMAT=FIXED;
"
dbSendQuery(dbc, strSQL)

# LOOKUPS ---------------------------------------
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

# HIERARCHIES -----------------------------------
strSQL = "
    CREATE TABLE hierarchies (
        hierarchy_id SMALLINT(4) UNSIGNED NOT NULL,
    	child_type CHAR(4) NOT NULL,
    	parent_type CHAR(4) NOT NULL,
        is_exact TINYINT(1) UNSIGNED NOT NULL,
        is_direct TINYINT(1) UNSIGNED NOT NULL,
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
y <- read.csv(file.path(data_path, 'hierarchies.csv'))
dbWriteTable(dbc, 'hierarchies', y, row.names = FALSE, append = TRUE)

# LOCATION_TYPES --------------------------------
strSQL = "
    CREATE TABLE location_types (
        location_type CHAR(4) NOT NULL,
        name CHAR(50) NOT NULL,
        theme CHAR(15) NOT NULL,
        ordering TINYINT(2) UNSIGNED NOT NULL,
        count_ons MEDIUMINT UNSIGNED NOT NULL,
        count_pc MEDIUMINT UNSIGNED NOT NULL,
        count_db MEDIUMINT UNSIGNED NOT NULL,
        PRIMARY KEY (location_type)
    ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci ROW_FORMAT=FIXED;
"
dbSendQuery(dbc, strSQL)
y <- read.csv(file.path(data_path, 'location_types.csv'))
dbWriteTable(dbc, 'location_types', y, row.names = FALSE, append = TRUE)

# CLEAN & EXIT ----------------------------------
dbDisconnect(dbc)
rm(list = ls())
gc()
