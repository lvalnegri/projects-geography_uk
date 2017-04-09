## Geography UK


### Postcodes

There are two files, [ONSPD](http://geoportal.statistics.gov.uk/datasets?q=ONS+Postcode+Directory+(ONSPD)+zip&sort_by=updated_at) and [NHSPD](http://geoportal.statistics.gov.uk/datasets?q=NHS+Postcode+Directory+(NHSPD)+full+zip&sort_by=updated_at), with mostly overlapping information.

Both contain ALL:
 - current (*live*) postcodes within the UK, as received monthly from the various postal admin within the UK
 - terminated (*closed*) postcodes that have NOT been subsequently re-used

We'll be using only the shorter 7-char *PCD* form: 
 - *outward* code as 2/3/4 chars, left aligned (3rd and 4th char may be blank)
 - *inward* code always 3 chars (1st numeric, 2nd and 3rd alpha), right aligned


### Locations
The following is a comprehensive list of the areas stored in the database when running the script. 

When an area is not assigned, .
 
 - *OA*. UK. ENG/WLS: Output Area, SCO: Data Zone, NIE: Small Area
 - *LSOA*. UK.
 - *MSOA*. GB.
 - *LAD*. UK. ENG: Local Authority District (LAD), Unitary Authority (UA), Metropolitan District (MD), London Borough (LB); WLS: Unitary Authority (UA); SCO: Council Area (CA), NIE: District Council Area (DCA) 
 - *CTY*. ENG: County (only for UA/MD/LB, see LAD)
 - *RGN*. ENG: Region (it was previously GOR) 
 - *CTRY*. UK: Country
 - *MCT*. : 
 - *WARD*. UK: Electoral Division
 - *PCON*. : 
 - *TTWA*. : 
 - *WKZ*. : 
 - *PFA*. : 
 - *PCS*. UK
 - *PCD*. UK
 - *PCA*. UK
 - *PAR*. 
 - *LAU2*. 
 - *LAU1*. 
 - *NTS3*. 
 - *NTS2*. 
 - *NTS1*. 
 - *LLSC*. 
 - *LEA*. 
 - *CCG*. UK
 - *LAT*. 
 - *NHSR*. 
 - *PCT*. 
 - *SHA*. UK: Health Area. ENG: (Former) Strategic Health Authority (SHA, abolished in 2013); WLS: Local Health Board (LHB); SCO: Health Board (HB); NIE: Health And Social Care Board (HSCB)
 - *SHAO*. 
 - *SCN*. 
 - *CNR*. 


### Lookups (starting from Output Areas - OAs)


### Boundaries: Union and Simplify


### Boundaries: Merge and Dissolve


### Mapping: Combine Data and Boundaries

#### ggplot and ggmap 
[ggplot](http://stat405.had.co.nz/ggmap.pdf) 
[ggmap](http://github.com/dkahle/ggmap/) 

#### leaflet
[leaflet](http://rstudio.github.io/leaflet/) 

#### tmap
[tmap](http://github.com/mtennekes/tmap) 

#### ggplot + ggspatial
[ggspatial](http://github.com/paleolimbot/ggspatial) 



