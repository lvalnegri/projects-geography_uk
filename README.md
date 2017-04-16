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
 
 - **OA**. UK. GB: 2011 Census Output Area (OA); NIE: 2011 Census Small Area (SA)
 - **LSOA**. UK. ENG, WLS: 2011 Census Lower Layer Super Output Area (LSOA); SCO: 2011 Census Data Zone (DZ); NIE: 2011 Census Small Output Area (SOA)
 - **MSOA**. GB. ENG, WLS: 2011 Census Middle Layer Super Output Area (MSOA); SCO: 2011 Census Intermediate Zone (I Z)
 - **LAD**. UK. ENG: Local Authority District (LAD), Unitary Authority (UA), Metropolitan District (MD), London Borough (LB); WLS: Unitary Authority (UA); SCO: Council Area (CA), NIE: District Council Area (DCA) 
 - **CTY**. ENG: County (only for UA/MD/LB, see LAD)
 - **RGN**. ENG: Region (in the ONS file it is coded as *GOR*) 
 - **CTRY**. UK: Country
 - **MTC**. EW: Major Towns and Cities
 - **WARD**. UK: Electoral Division
 - **PCON**. UK: Westminster Parliamentary Constituency
 - **TTWA**. UK: Travel to Work Area. There are also six *cross-border* areas (K01000009, ..., K01000014)
 - **WKZ**. UK: 2011 Census Workplace Zone
 - **PFA**. EW: Police Force Area
 - **PCS**. UK: Postcode Sector
 - **PCD**. UK: Postcode District
 - **PCA**. UK: Postcode Area
 - **PAR**. EW. ENG: Civil Parish or Unparished; WLS: Community.
 - **LAU2**. UK: Eurostat Local Administrative Units, lower level 2: Municipalities or equivalents (formerly NUTS5)
 - **LAU1**. UK: Eurostat Local Administrative Units, upper level 1 (formerly NUTS4)
 - **NTS3**. UK: Eurostat Territorial Units For Statistics Level 3: Small Regions
 - **NTS2**. UK: Eurostat Territorial Units For Statistics Level 2: Basic Regions
 - **NTS1**. UK: Eurostat Territorial Units For Statistics Level 1: Major Regions
 - **LLSC**. GB. ENG: Local Learning and Skills Council (LLSC); WLS: Dept. Children, Education, Lifelong Learning and Skills (DCELLS); SCO: Enterprise Region (ER) 
 - **LEA**. UK: Old Local Education Authority. GB: Local Education Authority (LEA); NIE: Education and Library Board (ELB) 
 - **CCG**. UK. ENG: Clinical Commissioning Group (CCG); WLS: Local Health Board (LHB); SCO: Community Health Partnership (CHP); NIE: Local Commissioning Group (LCG) 
 - **LAT**. ENG: NHS Region (formerly Local Area Team)
 - **NCR**. ENG: NHS Commissioning Region
 - **PCT**. UK. ENG: Primary Care Trust (PCT), Care Trust (Plus) (CT); WLS: Local Health Board (LHB), SCO: Community Health Partnership (CHP), NIE: Local Commissioning Group (LCG) 
 - **SHA**. UK: Health Area. ENG: (Former) Strategic Health Authority (SHA, abolished in 2013); WLS: Local Health Board (LHB); SCO: Health Board (HB); NIE: Health And Social Care Board (HSCB)
 - **SHAO**.UK (minus WLS): Old Health Area prior to the NHS reorganisation on 01/07/06. ENG: (Previous) Strategic Health Authority (SHA); SCO: Health Board (HB); NIE: Health and Social Services Board (HSSB) 
 - **SCN**. EW: NHS Strategic Clinical Network
 - **CNR**. EW: Cancer Registry


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



