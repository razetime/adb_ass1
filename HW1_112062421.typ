#set text(
  font: "Linux Libertine",
  size: 14pt,
)
#show link: underline
#set enum(numbering: "A.")

#align(center, text(17pt)[
  *PostGIS Lab Assignment*
])

+ (30%) Answer the following questions with spatial SQL queries (Using multiple
  queries is allowed). You need to explain your solutions and show the results of
  the queries. Please make sure you load the data that is the same as data used in
  the lab. #set enum(numbering: "a.")
  + The subway routes are categorized by different colors, and each subway
    station can be passed through by one or several color routes. For each color
    route r, calculate the total number of populations living in the census blocks
    that lie within 200 meters of all subway stations that r pass through. (Note
    that one station may be passed through by many color routes, you need to
    treat them separately.  
    / Target Tables: `nyc_subway_stations`, `nyc_census_blocks`
    We assume that `gid` is a primary key here.
  
    The `color` attribute containing the colour routes of `nyc_subway_stations` is a compound attribute, so we split and unnest each color to get duplicate rows:
    ```sql
  select gid,name,unnest(string_to_array(color,'-')) as clr
    from nyc_subway_stations limit 5;
    ```
    ```
   gid |     name     |  clr
  -----+--------------+--------
     1 | Cortlandt St | YELLOW
     2 | Rector St    | RED
     3 | South Ferry  | RED
     4 | 138th St     | GREEN
     5 | 149th St     | GREEN
  (5 rows)
    ```
    A normalized table is constucted from this data.
    ```sql
  create table station_colors as
    select gid,
    unnest(string_to_array(color,'-')) as clr,
    geom
    from nyc_subway_stations;
  SELECT 627
    ```
    Since we have associated each unique station with all its color routes, the total population per route can be calculated with `ST_Dwithin`:
    ```sql
select clr,sum(popn_total) from nyc_census_blocks,station_colors
where ST_Dwithin(station_colors.geom,nyc_census_blocks.geom,200)
group by clr;
    ```
    ```
    clr   |  sum
  --------+--------
   AIR    |   2658
   BLUE   | 385289
   BROWN  | 245185
   CLOSED |   4823
   GREEN  | 620844
   GREY   | 128085
   LIME   |  72730
   MULTI  |  65547
   ORANGE | 534834
   PURPLE | 102401
   RED    | 636236
   SI     |  27098
   YELLOW | 304559
  (13 rows)
    ```
    It is of note that even though `AIR` and `CLOSED` are not real color routes, they are still part of some colors and hence are included. They can be filtered out when constructing `station_colors` if required.
  + Show the name of the top 3 neighborhoods with the most population
    density. You also need to show the number of total population, the size (in
    km2), and the population density (in people/km2) of the neighborhood.
    / Target Tables: `nyc_neighborhoods`, `nyc_census_blocks`
    We need to group census blocks by neightborhood, so the first query lets us associate each census block with the neighborhood it is within:
    ```sql
create table cens_block_nbrs as 
select c.blkid, c.popn_total, n.gid as nid, n.name as nbname, ST_Area(n.geom)/1000000 as area
from nyc_census_blocks as c, nyc_neighborhoods as n
where ST_Within(c.geom, n.geom);
SELECT 28793
    ```
    from `nyc_census_blocks.prj` we can tell that the measurement unit is in metres:
    ```p
    UNIT["metre",1,AUTHORITY["EPSG","9001"]]
    ```
    the area hence is divided by 1,000,000 to convert to km#super("2").
    
    In order to get the final result, we group by neighborhood and aggregate each set of grouped values:
    ```sql
select nbname,(sum(popn_total)) as pop, area, (sum(popn_total)/area) as density
from cens_block_nbrs
group by nid,area,nbname
order by density desc
limit 3;
    ```
    ```
      nbname       |  pop   |       area        |     density      
-------------------+--------+-------------------+------------------
 North Sutton Area |  15462 | 0.328194000196611 | 47112.3786258652
 Upper East Side   | 191051 |  4.19872541579295 | 45502.1419789413
 East Village      |  59734 |  1.63211671718575 | 36599.0981962363
(3 rows)
    ```
  + Following the previous question, you may notice that the system spent much
    time executing your queries. Find a way to speed up the query executions
    and explain your solutions. You need to show the difference of the execution
    time. (Hint: Use command EXPLAIN ANALYZE can show the query plan and
    the execution time.)

    I used a query explaining tool to make sense of the text data that Postgres provides: https://explain.depesz.com
    
    From section a. we have the following query plan (truncated, full version in `.sql` file):
    ```sql
                           QUERY PLAN
.
.
.
 Planning Time: 1.204 ms
 Execution Time: 16550.142 ms
(18 rows)
    ```
    Since it appears that nested loop cost was high, and the inner loop was taking a lot of time, I tried to switch the arguments of `ST_Dwithin` to check if it would reduce the query overhead.
    ```sql
select clr,sum(popn_total) from nyc_census_blocks,station_colors
where ST_Dwithin(nyc_census_blocks.geom,station_colors.geom,200)
group by clr;
    ```
    ```sql
                         QUERY PLAN

.
.
.
 Planning Time: 0.221 ms
 Execution Time: 10337.808 ms
(18 rows)
    ```
    A significant improvement, 6 seconds of time difference.
+ (70%) Find at least two spatial data sets online and show at least two different
  spatial relationships between the data sets.
  You need to explain how you prepare the data, and the queries you use to find
  the relationships. Finally, show your query results on google map using .kml
  format.

  *Google Maps Link:* https://www.google.com/maps/d/u/0/edit?mid=18XVn1RKnA1ir_OmNPkSUjEiDNXw4nOc&usp=sharing
  
  My environment for `gdal` was configured as follows. Inside the miniconda command prompt:
  ```bash
  conda create -n env python=3.6 gdal
  activate env
  ```

  We use `esriprj2standards.py` from the PostGIS lab class to get the EPSG id, which is then used to import the `.shp` files:
  ```bash
  shp2pgsql -s 4326 gadm41_TWN_2.shp | psql -d plb postgres
  ```

  For the `.gpkg` files, importing is done in one step:
  ```sh
  ogr2ogr -f PostgreSQL "PG:user=postgres password=<PASSWD> dbname=plb" kontur_population_TW_20231101.gpkg
  ```

  

  #set enum(numbering: "a.")
  + *Health Facility Analysis*

    *Data Used*
    #table(columns: (auto,auto,auto, auto),
    [*Topic*], [*Link*], [*File Type*], [*Table Name*],
    [Health Facilities], [#link("https://data.humdata.org/dataset/hotosm_twn_health_facilities")[The Humanitarian Data Exchange]], `.gpkg`, [health_facilities],
    [Populated Places], [#link("https://data.humdata.org/dataset/hotosm_twn_populated_places")[The Humanitarian Data Exchange]], [`.shp`, `.prj`], [pop_places],
    [County and Municipality boundaries], [#link("https://gadm.org/")[Database of Global Administrative Areas]], `.shp`, [gadm41_TWN_2]
    )

    *Map of Populated Places*
    #image("qBa_init.png")

    *Map of Health Facilities*
    #image("qBa_init1.png")
    
    We are looking at two main factors:
    - *Diversity:* The count of different varieties of general health facilities present in a county.
    - *Coverage:* How many people from populated places can reach the facility?
    Using these metrics we can gauge the availabilty of diverse medical services, and find out which counties with a low diversity metric require more average coverage.
    
    *Preprocessing*
    
    We have to convert the population data from varying character to int, trimming out non-required columns, and removing null populations.
    ```sql
create table pop_corr as
select gid,cast(population as integer),geom
from pop_places
where population is not null;
    ```
    *Population Coverage*
    
    To get the population coverage, we use a `DWithin` call, and then we group the medical facilities by county, aggregating diversity and coverage in the grouping section.
    ```sql
create table health_pop as
select fid, amenity, h.geom, sum(population)
from pop_corr p, health_facilities h
where ST_DWithin(p.geom, h.geom, 0.1)
group by fid;

create table health_metrics as
select name_2 as name, count(distinct amenity) as diversity, avg(sum) as avg_cov, g.geom
from health_pop h, gadm41_twn_2 g
where ST_Within(h.geom, g.geom)
group by gid
order by avg_cov desc, diversity desc;
    ```
    *Exporting*
    
    We get the data required for the kml file into two separate tables, so we can see how the medical facility data can be related to each county.

    The KML `name` attribute is what is displayed in the map legend, hence it is added in both queries.
    ```sql
create table lowest_per_diversity as
select h.name, diversity, avg_cov, geom from health_metrics h
where avg_cov =
(select min(k.avg_cov) from health_metrics k where k.diversity = h.diversity);

create table lowest_diversity_towns as
select p.name, p.geom
from pop_places p, lowest_per_diversity l
where ST_Within(p.geom, l.geom);
    ```

    The tables are then exported with `ogr2ogr`, like so:
    ```sh
    ogr2ogr -f "KML" B1.kml PG:"host=localhost user=postgres dbname=plb password=<pass>" "lowest_per_diversity"
    ```

    *Results*

    The `name` column and `description` column of the KML file is automatically used by Google Maps for labeling the geometry data given to it.

    Further customizations have been done with the map to give the outlines and markers appropriate coloring and labels.

    #image("qBa_res.png")
    
  + *Road and Railway Analysis*

    *Data Used*
    #table(columns: (auto,auto,auto, auto),
    [*Topic*], [*Link*], [*File Types*], [*Table Name*],
    [County and Municipality boundaries], [#link("https://gadm.org/")[Database of Global Administrative Areas]], [`.shp`, `.prj`], [gadm41_TWN_2],
    [Major Roads in Taiwan],[#link("https://www.diva-gis.org/gdata")[DIVA-GIS]],[`.shp`, `.prj`],[twn_roads],
    [Major Railroads in Taiwan],[#link("https://www.diva-gis.org/gdata")[DIVA-GIS]],[`.shp`, `.prj`],[twn_rails]
    )
    
    In this part, we are looking at the railway-major road ratio of every major county. The ideal ratio for a county would be near 0.5, equally accessible by rail as it is by road.

    *Map of Roads*
    #image("qBb_init1.png")

    #linebreak() #linebreak() #linebreak() #linebreak() #linebreak() #linebreak() #linebreak() #linebreak() #linebreak() #linebreak() #linebreak() #linebreak() #linebreak() 
    *Map of Railroads*
    #image("qBb_init2.png")
    
    *Preprocessing*
    
    First, we find all roads and railways which must be checked. We do not want non-operational transport methods.
    ```sql
create table op_rails as
select geom from twn_rails where exs_descri = 'Operational';

create table op_roads as
select geom from twn_roads
where
  rtt_descri = 'Primary Route' or rtt_descri = 'Secondary Route';
    ```

    We prune columns from the counties table for the final result.
    ```sql
create table areas as
select gid, name_2 as name, geom from gadm41_twn_2;
    ```
    
    *Intersection Calculation*

    The roads and rails are intersected with the counties, and grouped by gid to make sure that the count is correct.

    ```sql
create table road_count as
select gid, count(r.geom) 
from areas a, op_roads r
where ST_Intersects(r.geom,a.geom)
group by a.gid;

create table rail_count as
select gid, count(r.geom) 
from areas a, op_rails r
where ST_Intersects(r.geom,a.geom)
group by a.gid;
    ```

    *Results*

    The final touch is a three-way join on `gid`, which unifies the results together and provides a proper ratio we can analyze.

    ```sql
create table roads_rails_per_area as
select a.gid, a.name,
  r.count as road_count, l.count as rail_count,
  cast(l.count as float)/cast(r.count as float) as ratio, a.geom
from areas a,road_count r,rail_count l
where a.gid = r.gid and a.gid = l.gid
order by ratio;
    ```

    Since some of the ratios are common, this lets us color code the counties to show which regions have abnormal ratios.

    #image("image.png")

    