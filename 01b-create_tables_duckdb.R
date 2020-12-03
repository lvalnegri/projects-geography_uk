############################################################
# UK GEOGRAPHY * 01 - Create database and tables in duckdb #
############################################################

# preliminaries ---------------------------------
pkgs <- c('popiFun', 'data.table', 'duckdb')
lapply(pkgs, require, char = TRUE)

in_path <- file.path(pub_path, 'ancillaries', 'uk', 'geography')

system(paste('rm -r', file.path(pub_path, 'databases', 'uk', 'geography.*')))
dbc <- dbConnect(duckdb(), file.path(pub_path, 'databases', 'uk', 'geography.duckdb'))

# POSTCODES -------------------------------------
dbSendQuery(dbc, "CREATE TABLE postcodes ( 

    postcode CHAR(7) NOT NULL, 
    is_active TINYINT NOT NULL, 
    usertype TINYINT NOT NULL,
    x_lon DECIMAL(7,6) NOT NULL,
    y_lat DECIMAL(8,6) NOT NULL,
    OA CHAR(9) NOT NULL,
    LSOA CHAR(9) NOT NULL,
    MSOA CHAR(9) NULL DEFAULT NULL,
    LAD CHAR(9) NOT NULL,
    CTY CHAR(9) NULL DEFAULT NULL,
    RGN CHAR(9) NULL DEFAULT NULL,
    CTRY CHAR(1) NOT NULL,
    
    PCS CHAR(5) NULL DEFAULT NULL,
    PCD CHAR(4) NULL DEFAULT NULL,
    PCT CHAR(7) NULL DEFAULT NULL,
    PCA CHAR(2) NULL DEFAULT NULL,

    TTWA CHAR(9) NOT NULL,
    WARD CHAR(9) NOT NULL,
    PCON CHAR(9) NOT NULL,
    CED CHAR(9) NULL DEFAULT NULL,
    PAR CHAR(9) NULL DEFAULT NULL,

	BUA CHAR(9) NULL DEFAULT NULL,
	BUAS CHAR(9) NULL DEFAULT NULL,
	WPZ CHAR(9) NULL DEFAULT NULL,

	PFN CHAR(9) NULL DEFAULT NULL,
	CSP CHAR(9) NULL DEFAULT NULL,
	PFA CHAR(9) NULL DEFAULT NULL,
	FRA CHAR(9) NOT NULL,
	
	CCG CHAR(9) NOT NULL,
	STP CHAR(9) NULL DEFAULT NULL,
	NHSO CHAR(9) NOT NULL,
	NHSR CHAR(9) NOT NULL,

	LPA CHAR(9) NOT NULL,
	RGD CHAR(9) NOT NULL,
	LRF CHAR(9) NOT NULL,
	
	I0 INT NULL DEFAULT NULL,
	I1 INT NULL DEFAULT NULL,
	I2 INT NULL DEFAULT NULL,
	I3 INT NULL DEFAULT NULL,
	I4 INT NULL DEFAULT NULL,
	I5 INT NULL DEFAULT NULL,
	M0 INT NULL DEFAULT NULL,
	M1 INT NULL DEFAULT NULL,
	M2 INT NULL DEFAULT NULL,
	M3 INT NULL DEFAULT NULL,
	M4 INT NULL DEFAULT NULL,
	M5 INT NULL DEFAULT NULL

)")

# OUTPUT AREAS ----------------------------------
dbSendQuery(dbc, "CREATE TABLE output_areas (
    
        OA CHAR(9) NOT NULL,
        x_lon DECIMAL(7,6) NULL DEFAULT NULL,
        y_lat DECIMAL(8,6) NULL DEFAULT NULL,
        wx_lon DECIMAL(7,6) NULL DEFAULT NULL,
        wy_lat DECIMAL(8,6) NULL DEFAULT NULL,
        perimeter MEDIUMINT NULL DEFAULT NULL,
        area INT NULL DEFAULT NULL,
    	tot_uprn SMALLINT NULL DEFAULT NULL,
    	oac SMALLINT NULL DEFAULT NULL,
    	ruc TINYINT NULL DEFAULT NULL,
    
        LSOA CHAR(9) NOT NULL,
        MSOA CHAR(9) NULL DEFAULT NULL,
        LAD CHAR(9) NOT NULL,
        CTY CHAR(9) NOT NULL,
        RGN CHAR(9) NOT NULL,
        CTRY CHAR(3) NOT NULL,
    
        PCS CHAR(5) NOT NULL,
        PCD CHAR(4) NOT NULL,
    	PCT CHAR(7) NOT NULL,
        PCA CHAR(2) NOT NULL,
    
        TTWA CHAR(9) NOT NULL,
        WARD CHAR(9) NOT NULL,
        PCON CHAR(9) NOT NULL,
        CED CHAR(9) NULL DEFAULT NULL,
        PAR CHAR(9) NULL DEFAULT NULL,
    
    	BUA CHAR(9) NULL DEFAULT NULL,
    	BUAS CHAR(9) NULL DEFAULT NULL,
    	MTC CHAR(9) NULL DEFAULT NULL,
    
    	PFN SMALLINT NULL DEFAULT NULL,
    	CSP CHAR(9) NULL DEFAULT NULL,
    	PFA CHAR(9) NULL DEFAULT NULL,
    	
    	STP CHAR(9) NOT NULL,
    	CCG CHAR(9) NOT NULL,
    	NHSO CHAR(9) NOT NULL,
    	NHSR CHAR(9) NOT NULL
    	
)")

# WORKPLACE ZONES -------------------------------
dbSendQuery(dbc, "CREATE TABLE workplace_zones (
    
    WPZ CHAR(9) NOT NULL,
    x_lon DECIMAL(7,6) NULL DEFAULT NULL,
    y_lat DECIMAL(8,6) NULL DEFAULT NULL,
    wx_lon DECIMAL(7,6) NULL DEFAULT NULL,
    wy_lat DECIMAL(8,6) NULL DEFAULT NULL,
    perimeter INT NULL DEFAULT NULL,
    area INT NULL DEFAULT NULL,
	tot_uprn SMALLINT NULL DEFAULT NULL,
	wzc CHAR(2) NULL DEFAULT NULL,

    MSOA CHAR(9) NULL DEFAULT NULL,
    LAD CHAR(9) NOT NULL,
    CTY CHAR(9) NOT NULL,
    RGN CHAR(9) NOT NULL,
    CTRY CHAR(3) NOT NULL
            
)")

# LOCATIONS -------------------------------------
dbSendQuery(dbc, "CREATE TABLE locations (

    location_type CHAR(4) NOT NULL,
    location_id CHAR(9) NOT NULL DEFAULT '',
    name CHAR(75) NOT NULL DEFAULT '',
    x_lon DECIMAL(8,6) NULL DEFAULT NULL,
    y_lat DECIMAL(8,6) NULL DEFAULT NULL,
    wx_lon DECIMAL(8,6) NULL DEFAULT NULL,
    wy_lat DECIMAL(8,6) NULL DEFAULT NULL,
    perimeter INT NULL DEFAULT NULL,
    area INT NULL DEFAULT NULL
    
)")

# NEIGHBOURS ------------------------------------
dbSendQuery(dbc, "CREATE TABLE neighbours (
    location_type CHAR(4) NOT NULL,
    location_id CHAR(9) NOT NULL,
    neighbour_id CHAR(9) NOT NULL,
    distance INT NOT NULL
)")

# DISTANCES -------------------------------------
dbSendQuery(dbc, "CREATE TABLE distances (
    location_type CHAR(4) NOT NULL,
    location_ida CHAR(9) NOT NULL,
    location_idb CHAR(9) NOT NULL,
    distance INT NOT NULL
)")

# LOOKUPS ---------------------------------------
dbSendQuery(dbc, "CREATE TABLE lookups (
    hierarchy_id SMALLINT NOT NULL,
	child_id CHAR(9) NOT NULL,
	parent_id CHAR(9) NOT NULL
)")

# HIERARCHIES -----------------------------------
dbSendQuery(dbc, "CREATE TABLE hierarchies (
    hierarchy_id SMALLINT NOT NULL,
	child_type CHAR(4) NOT NULL,
	parent_type CHAR(4) NOT NULL,
    is_exact TINYINT NOT NULL,
    is_direct TINYINT NOT NULL,
	listing TINYINT NOT NULL,
	charting TINYINT NOT NULL,
	mapping TINYINT NOT NULL,
    filtering TINYINT NOT NULL,
    countries CHAR(4) NOT NULL
)")
y <- fread(file.path(in_path, 'hierarchies.csv'))
dbWriteTable(dbc, 'hierarchies', y, append = TRUE)

# LOCATION_TYPES --------------------------------
dbSendQuery(dbc, "CREATE TABLE location_types (
        location_type CHAR(4) NOT NULL,
        name CHAR(50) NOT NULL,
        theme CHAR(15) NOT NULL,
        ordering TINYINT NOT NULL,
        count_ons INT NULL,
        count_pc INT NULL,
        count_db INT NULL
)")
y <- fread(file.path(in_path, 'location_types.csv'))
dbWriteTable(dbc, 'location_types', y, overwrite = TRUE)

# CLEAN & EXIT ----------------------------------
dbListTables(dbc)
dbDisconnect(dbc, shutdown = TRUE)

rm(list = ls())
gc()
