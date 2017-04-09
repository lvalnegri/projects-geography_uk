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
The following is a comprehensive list of areas 

When an area is not assigned, pseudo codes are the following:
 - E99999999 England (ENG); 
 - W99999999 Wales (WLS) 
 - S99999999 Scotland (SCO)
 - N99999999 Northern Ireland (NIE) 
 

 - *OA*. UK. Output Area (in 
 - *LSOA*. UK.
 - *MSOA*. GB.
 - *LAD*. : 
 - *CTY*. ENG: County (only parts)
 - *RGN*. : 
 - *CTRY*. UK
 - *MCT*. : 
 - *WARD*. : 
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
 - *SHA*. 
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



