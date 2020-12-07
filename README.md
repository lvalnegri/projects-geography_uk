## Geography UK


### Postcodes

There are two files:

 - [ONSPD](http://geoportal.statistics.gov.uk/datasets?q=ONS+Postcode+Directory+(ONSPD)+zip&sort_by=updated_at) 
 - [NHSPD](http://geoportal.statistics.gov.uk/datasets?q=NHS+Postcode+Directory+(NHSPD)+full+zip&sort_by=updated_at)
 
with mostly overlapping information.

Both contain ALL:
 - current (*live*) postcodes within the UK, as received monthly from the various postal admin within the UK
 - terminated (*closed*) postcodes that have NOT been subsequently re-used

We'll be using only the shorter 7-char *PCD* form: 
 - *outward* code as 2/3/4 chars, left aligned (3rd and 4th char may be blank)
 - *inward* code always 3 chars (1st numeric, 2nd and 3rd alpha), right aligned

#### Credits
Unit postcodes (PCU) remain the copyright of *Royal Mail*.  All other information on the ONSPD is *Crown* copyright.
The user should be aware of the attribution and sub-licensing requirements associated with the use of the *Code-Point* Open data (from which postcode products are derived) contained in the OS OpenData Licence, namely that the licensee:

- Must always use the following attribution statements to acknowledge the source of the information: 
   - Contains OS data © Crown copyright and database right [year] 
   - Contains Royal Mail data © Royal Mail copyright and database right [year] 
   - Contains National Statistics data © Crown copyright and database right [year] 
   
 - Must ensure that the same attribution statements are contained in any sub-licences of the Information that are granted, together with a requirement that any further sub-licences do the same. 
 
The user should also note that, following agreement with Land and Property Services (LPS) Northern Ireland, Open Government Licensing terms do not apply to NI postcodes; separate licensing terms and conditions now apply in the form of an LPS End User licence or contact LPS directly for commercial use. Please see their Licences web page for further details. 


### Locations
The following is a comprehensive list of the areas stored in the database when running the script, and for which you can find a simplified boundary file (in *RDS* format as *SpatialPolygonsDataFrame*) in the *data* subdirectory. 
 
 - **CENSUS**:
   - **WKZ**.  UK:  2011 Census Workplace Zone
   - **OA**.   UK. GB: 2011 Census Output Area (OA); NIE: 2011 Census Small Area (SA)
   - **LSOA**. UK. ENG, WLS: 2011 Census Lower Layer Super Output Area (LSOA); SCO: 2011 Census Data Zone (DZ); NIE: 2011 Census Small Output Area (SOA)
   - **MSOA**. GB. ENG, WLS: 2011 Census Middle Layer Super Output Area (MSOA); SCO: 2011 Census Intermediate Zone (I Z)
   - **LAD**.  UK. ENG: Local Authority District (LAD), Unitary Authority (UA), Metropolitan District (MD), London Borough (LB); WLS: Unitary Authority (UA); SCO: Council Area (CA), NIE: District Council Area (DCA) 
   - **CTY**.  ENG: County (only for UA/MD/LB, see LAD)
   - **RGN**.  ENG: Region
   - **CTRY**. UK: Country
   
 - **POSTCODES**
   - **PCS**. UK: Postcode Sector
   - **PCD**. UK: Postcode District
   - **PCT**. UK: Post Town
   - **PCA**. UK: Postcode Area
   
 - **ELECTORAL**
   - **PCON**. UK:  Westminster Parliamentary Constituency
   - **WARD**. UK:  Electoral Division
   - **CED**.  ENG: Electoral County
   
 - **URBAN**
   - **TTWA**. UK:  Travel to Work Area. There are also six *cross-border* areas (K01000009, ..., K01000014)
   - **MTC**.  EW:  Major Towns and Cities
   - **BUAS**. EW:  
   - **BUA**.  EW:  
   
 - **SOCIAL**
   - **PAR**. EW.  ENG: Civil Parish or Unparished; WLS: Community.
   - **PFN**. EW: Police Force Neighborhood
   - **PFA**. EW: Police Force Area
   - **FRA**. EW: Fire Rescue Authorities (Dec-2019)
   - **CSP**. EW: Community Safety Partnership (Dec-2019)
   - **LPA**. EW: Local Planning Authorities (Apr-2020)
   - **RGD**. EW: Registration Districts (Apr-2019)
   - **LRF**. EW: Local Resilience Forums (Dec-2019)
 
 - **HEALTH**
   - **CCG**. UK. ENG: Clinical Commissioning Group (CCG); WLS: Local Health Board (LHB); SCO: Community Health Partnership (CHP); NIE: Local Commissioning Group (LCG) 
   - **STP**.  
   - **NHSO**. ENG: NHS Local Office (formerly Local Area Team)
   - **NHSR**. ENG: NHS Region
   - **CIS**. ENG: Covid Infection Survey (Oct-2020)

### Lookups (starting from Output Areas - OAs)

- Postcode Sectors: 
  - ENG/WLS: see [this best-fit lookup table](https://data.gov.uk/harvest/gemini-object/e254ade3-bcc2-45e1-9590-6642c70d8815). If the link doesn't work, try instead [this archived content](https://geoportal.statistics.gov.uk/Docs/Lookups/Output_areas_(2011)_to_enumeration_postcode_sectors_(2011)_E+W_lookup.zip) still works
  - SCO: see the table OA_TO_HIGHER_AREAS in the 2011 Census Indexes database you can download from [here](https://www.nrscotland.gov.uk/statistics-and-data/geography/our-products/census-datasets/2011-census/2011-indexes) 
  - NIE

### Boundaries: Union and Simplify

Download the OAs boundaries for each country :
  - England and Wales: browse to [COA Boundaries](http://geoportal.statistics.gov.uk/datasets?q=COA%20Boundaries&sort_by=name) 
    and download the *Generalised Clipped boundaries* full dataset shapefile (~50MB).
    The projection is **British National Grid, OSGB_1936**
  - Scotland: open [2011 Census Geography](http://www.nrscotland.gov.uk/statistics-and-data/geography/our-products/census-datasets/2011-census/2011-boundaries) 
    and download the *2011 Output Area Boundaries, Extent of the Realm* zip file (~28MB).
    The projection is **British National Grid, OSGB_1936**
  - Northern Ireland: go to [NISRA Geography](http://www.nisra.gov.uk/geography/SmallAreas.htm)
    and download the *ESRI Shapefile format* zip file (~25MB) at the botttom of the page under the heading **Small Area Boundaries in GIS format**.
    The projection is **Irish Grid, GCS_TM65**

Unzip all the files, keep only the ones with the extensions: **shp** (geometry), **shx** (index), **prj** (projection), and **dbf** (data); rename the blocks as: **EW.*** (England and Wales), **SC.*** (Scotland), **NI.*** (northern Ireland).


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



