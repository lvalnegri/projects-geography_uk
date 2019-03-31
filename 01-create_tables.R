##################################################
# UK GEOGRAPHY * 01 - Create database and tables #
##################################################
# You need to provide the following CSV in in_path:
#  - hierarchies
#  - location_types
#  - OAC, WZC and RUC, codes and names 
#  - mosaic groups and types, codes and names

# Load packages -----------------------------------------------------------------------------------------------------------------
pkg <- c('data.table', 'fst', 'RMySQL')
invisible( lapply(pkg, require, char = TRUE) )

# Set paths ---------------------------------------------------------------------------------------------------------------------
in_path <- file.path(Sys.getenv('PUB_PATH'), 'ancillaries', 'geography', 'uk')
out_path <- file.path(Sys.getenv('PUB_PATH'), 'datasets', 'geography', 'uk')

# Create database ---------------------------------------------------------------------------------------------------------------
dbc = dbConnect(MySQL(), group = 'dataOps')
dbSendQuery(dbc, 'DROP DATABASE IF EXISTS geography_uk')
dbSendQuery(dbc, 'CREATE DATABASE geography_uk')
dbDisconnect(dbc)

# Connect to database -----------------------------------------------------------------------------------------------------------
dbc = dbConnect(MySQL(), group = 'geouk')

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
        mosaic_type char(3) NULL DEFAULT NULL COLLATE utf8_unicode_ci COMMENT 'see mosaic_types.code',

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
    	STP CHAR(9) NOT NULL COMMENT 'Sustainability and Transformation Partnership (E54; England Only)',
    	CCG CHAR(9) NOT NULL COMMENT 'Clinical Commissioning Group (E38, W11, S03, ZC)',
    	NHSO CHAR(9) NOT NULL COMMENT 'NHS Local Office (E39; England Only)',
    	NHSR CHAR(9) NOT NULL COMMENT 'NHS Region (E40; England Only)',

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

# WORKPLACE ZONES ---------------------------------------------------------------------------------------------------------------
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
    	wzc_sgroup CHAR(2) NULL DEFAULT NULL COMMENT 'Workplace Zones Classification: Supergroup Code',
    	wzc_group CHAR(1) NULL DEFAULT NULL COMMENT 'Workplace Zones Classification: Group Code',

        MSOA CHAR(9) NULL DEFAULT NULL COMMENT 'Middle Layer Super Output Area (E02, W02, S02; England, Wales and Scotland Only)',
        LAD CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Local Authority District (UA-E06/W06, LAD-E07, MD-E08, LB-E09, CA-S12, DCA-N09)',
        CTY CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'County (C-E10, MC-E11, IOL-E13, plus LAD-E060=>E069; England Only; pseudo: WLS_CTY, SCO_CTY, NIE_CTY)',
        RGN CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Region (E12; England Only; pseudo: WLS_RGN, SCO_RGN, NIE_RGN)',
        CTRY CHAR(3) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'Country (E92 = ENG, W92 = WLS, S92 = SCO, N92 = NIE)',

        PRIMARY KEY (WPZ),
    	INDEX wzc_sgroup (wzc_sgroup),
    	INDEX wzc_group (wzc_group),
        INDEX MSOA (MSOA),
        INDEX LAD (LAD),
        INDEX CTY (CTY),
        INDEX RGN (RGN),
        INDEX CTRY (CTRY)

    ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci ROW_FORMAT=FIXED
"
dbSendQuery(dbc, strSQL)

# LOCATIONS ---------------------------------------------------------------------------------------------------------------------
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

# NEIGHBOURS --------------------------------------------------------------------------------------------------------------------
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

# DISTANCES ---------------------------------------------------------------------------------------------------------------------
strSQL = "
    CREATE TABLE distances (
        location_type CHAR(4) NOT NULL,
        location_a CHAR(9) NOT NULL,
        location_b CHAR(9) NOT NULL,
        distance MEDIUMINT(7) UNSIGNED NOT NULL 
            COMMENT 'Vincenty (ellipsoid) great circle distance, see http://www.movable-type.co.uk/scripts/latlong-vincenty.html',
        INDEX (location_type),
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
y <- read.csv(file.path(in_path, 'hierarchies.csv'))
dbWriteTable(dbc, 'hierarchies', y, row.names = FALSE, append = TRUE)
write.fst(y, file.path(out_path, 'hierarchies'))

# LOCATION_TYPES ----------------------------------------------------------------------------------------------------------------
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
y <- read.csv(file.path(in_path, 'location_types.csv'))
dbWriteTable(dbc, 'location_types', y, row.names = FALSE, append = TRUE)
write.fst(y, file.path(out_path, 'location_types'))

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

# LOCATIONS_OACS -------------------------------------------------------------------------------------------------
strSQL = "
    CREATE TABLE locations_oacs (
		location_type char(4) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'see location_types.location_type',
        location_id CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'If location_type = <OA> see output_areas.OA, else see locations.location_id',
        oac_class CHAR(1) NOT NULL COMMENT 'Su(B)group, (G)roup, Su(P)ergroup',
        oac_id TINYINT(3) UNSIGNED NOT NULL 
            COMMENT 'If oac_class = <B> see oac.subgroup_id, if oac_class = <G> see oac.group_id, if oac_class = <P> see oac.supergroup_id',
        count_pc TINYINT(3) UNSIGNED NOT NULL COMMENT 'Number of postcodes in the specified area assuming the specified mosaic class',
        pct_pc DECIMAL(5,2) UNSIGNED NOT NULL 
            COMMENT
			    'Percentage of postcodes in the specified area assuming the specified OAC class, 
			    where the reference total is the number of postcodes in the area with known OAC class',
        PRIMARY KEY (location_id, oac_class, oac_id),
        INDEX (location_type),
        INDEX (location_id),
        INDEX (oac_class),
        INDEX (oac_id)
    ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci ROW_FORMAT=FIXED
"
dbSendQuery(dbc, strSQL)

# WZC ---------------------------------------------------------------------------------------------------------------------------
strSQL <- "
    CREATE TABLE wzc (
    	sgroup_id TINYINT(1) UNSIGNED NOT NULL,
    	sgroup_code CHAR(1) NOT NULL,
    	sgroup_desc CHAR(30) NOT NULL,
    	group_id TINYINT(2) UNSIGNED NOT NULL,
    	group_code CHAR(2) NOT NULL,
    	group_desc CHAR(60) NOT NULL,
    	PRIMARY KEY (group_id),
    	UNIQUE INDEX group_code (group_code),
    	INDEX sgroup_id (sgroup_id),
    	INDEX sgroup_code (sgroup_code)
    ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci ROW_FORMAT=FIXED
"
dbSendQuery(dbc, strSQL)
y <- fread(file.path(in_path, 'wzc.csv'))
dbWriteTable(dbc, 'wzc', y, row.names = FALSE, append = TRUE)
cols <- c('sgroup_code', 'group_code')
y[, (cols) := lapply(.SD, as.factor), .SDcols = cols]
write.fst(y, file.path(out_path, 'wzc'))

# LOCATIONS_WZCs -------------------------------------------------------------------------------------------------
strSQL = "
    CREATE TABLE locations_wzcs (
		location_type char(4) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'see location_types.location_type',
        location_id CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'If location_type = <OA> see output_areas.OA, else see locations.location_id',
        wzc_class CHAR(1) NOT NULL COMMENT '(S)upergroup, (G)roup',
        wzc_id TINYINT(3) UNSIGNED NOT NULL 
            COMMENT 'If wzc_class = <G> see wzc.group_id, if wzc_class = <S> see wzc.supergroup_id',
        count_pc TINYINT(3) UNSIGNED NOT NULL COMMENT 'Number of zones in the specified area assuming the specified class',
        pct_pc DECIMAL(5,2) UNSIGNED NOT NULL 
            COMMENT
			    'Percentage of zones in the specified area assuming the specified class, 
			    where the reference total is the number of zones in the area with known class',
        PRIMARY KEY (location_id, wzc_class, wzc_id),
        INDEX (location_type),
        INDEX (location_id),
        INDEX (wzc_class),
        INDEX (wzc_id)
    ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci ROW_FORMAT=FIXED
"
dbSendQuery(dbc, strSQL)

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

# MOSAIC: GROUPS --------------------------------------------------------------------------------------------
strSQL <- "
    CREATE TABLE mosaic_groups (
    	group_id TINYINT(2) UNSIGNED NOT NULL,
    	code CHAR(1) NOT NULL COLLATE 'utf8_unicode_ci',
    	name CHAR(20) NOT NULL COLLATE 'utf8_unicode_ci',
    	code_name CHAR(21) NOT NULL COLLATE 'utf8_unicode_ci',
    	description CHAR(100) NOT NULL COLLATE 'utf8_unicode_ci',
    	long_description VARCHAR(500) NOT NULL COLLATE 'utf8_unicode_ci',
    	postcodes MEDIUMINT(8) UNSIGNED NOT NULL,
    	population MEDIUMINT(8) UNSIGNED NOT NULL,
    	households MEDIUMINT(8) UNSIGNED NOT NULL,
    	PRIMARY KEY (group_id),
    	UNIQUE INDEX code (code)
    ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci ROW_FORMAT=FIXED
"
dbSendQuery(dbc, strSQL)
y <- fread(file.path(in_path, 'mosaic_groups.csv'))
dbWriteTable(dbc, 'mosaic_groups', y, row.names = FALSE, append = TRUE)
cols <- c('code', 'name', 'code_name')
y[, (cols) := lapply(.SD, as.factor), .SDcols = cols]
write.fst(y, file.path(out_path, 'mosaic_groups'))

# MOSAIC: TYPES ---------------------------------------------------------------------------------------------
strSQL <- "
    CREATE TABLE mosaic_types (
    	type_id TINYINT(3) UNSIGNED NOT NULL,
    	code CHAR(3) NOT NULL COLLATE 'utf8_unicode_ci',
    	name CHAR(30) NOT NULL COLLATE 'utf8_unicode_ci',
    	code_name CHAR(33) NOT NULL COLLATE 'utf8_unicode_ci',
    	code_exp TINYINT(3) UNSIGNED NOT NULL,
    	description CHAR(125) NOT NULL COLLATE 'utf8_unicode_ci',
    	group_id TINYINT(2) UNSIGNED NOT NULL,
    	group_code CHAR(1) NOT NULL COLLATE 'utf8_unicode_ci',
    	postcodes MEDIUMINT(8) UNSIGNED NOT NULL,
    	population MEDIUMINT(8) UNSIGNED NOT NULL,
    	households MEDIUMINT(8) UNSIGNED NOT NULL,
    	PRIMARY KEY (type_id),
    	UNIQUE INDEX code (code),
    	INDEX group_code (group_code),
    	INDEX group_id (group_id)
    ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci ROW_FORMAT=FIXED
"
dbSendQuery(dbc, strSQL)
y <- fread(file.path(in_path, 'mosaic_types.csv'))
dbWriteTable(dbc, 'mosaic_types', y, row.names = FALSE, append = TRUE)
cols <- c('code', 'name', 'code_name', 'group_code')
y[, (cols) := lapply(.SD, as.factor), .SDcols = cols]
write.fst(y, file.path(out_path, 'mosaic_types'))

# LOCATIONS_MOSAICS -------------------------------------------------------------------------------------------------
strSQL = "
    CREATE TABLE locations_mosaics (
		location_type char(4) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'see location_types.location_type',
        location_id CHAR(9) NOT NULL COLLATE 'utf8_unicode_ci' COMMENT 'If location_type = <OA> see output_areas.OA, else see locations.location_id',
        mosaic_class CHAR(1) NOT NULL COMMENT '(T)ype or (G)roup',
        mosaic_id TINYINT(3) UNSIGNED NOT NULL COMMENT 'If mosaic_class = <G> see mosaic_groups.group_id, If mosaic_class = <T> see mosaic_types.type_id',
        count_pc TINYINT(3) UNSIGNED NOT NULL COMMENT 'Number of postcodes in the specified area assuming the specified mosaic class',
        pct_pc DECIMAL(5,2) UNSIGNED NOT NULL COMMENT
			'Percentage of postcodes in the specified area assuming the specified mosaic class, 
			 where the reference total is the number of postcodes in the area with known mosaic class',
        PRIMARY KEY (location_id, mosaic_class, mosaic_id),
        INDEX (location_type),
        INDEX (location_id),
        INDEX (mosaic_class),
        INDEX (mosaic_id)
    ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci ROW_FORMAT=FIXED
"
dbSendQuery(dbc, strSQL)

# CLEAN & EXIT ------------------------------------------------------------------------------------------------------------------
dbDisconnect(dbc)
rm(list = ls())
gc()
