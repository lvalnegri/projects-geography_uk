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


### Lookups (starting from Output Areas - OAs)


### Boundaries: Union and Simplify


### Boundaries: Merge and Dissolve


### Mapping: Combine Data and Boundaries

#### Using dataframes with ggplot and ggmap 

[ggplot]() 
[ggmap](http://github.com/dkahle/ggmap/) 

#### Using Shapefiles with leaflet, tmap and ggplot + ggspatial

[leaflet](http://rstudio.github.io/leaflet/) 
[tmap](http://github.com/mtennekes/tmap) 
[ggspatial](http://github.com/paleolimbot/ggspatial) 



