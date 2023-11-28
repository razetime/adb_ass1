-- The subway routes are categorized by different colors, and each subway
-- station can be passed through by one or several color routes. For each color
-- route r, calculate the total number of populations living in the census 
-- blocks that lie within 200 meters of all subway stations that r pass through.
-- (Note that one station may be passed through by many color routes, you need
-- to treat them separately.)

select distinct unnest(string_to_array(color,'-')) 
  as colors from nyc_subway_stations;

select gid,name,unnest(string_to_array(color,'-')) as clr
  from nyc_subway_stations limit 5;

-- create table with station and color.
-- duplicates are ok here, as we are converting a compound attribute into a
-- simple attribute.
create table station_colors as
  select gid,
  unnest(string_to_array(color,'-')) as clr,
  geom
  from nyc_subway_stations;

-- the final step
select clr,sum(popn_total) from nyc_census_blocks,station_colors
where ST_Dwithin(station_colors.geom,nyc_census_blocks.geom,200)
group by clr;

-- Show the name of the top 3 neighborhoods with the most population
-- density. You also need to show the number of total population, the size (in
-- km2), and the population density (in people/km2) of the neighborhood

create table cens_block_nbrs as 
select c.blkid, c.popn_total, n.gid as nid, n.name as nbname, ST_Area(n.geom) as area
from nyc_census_blocks as c, nyc_neighborhoods as n
where ST_Within(c.geom, n.geom);

select nbname,(sum(popn_total)) as pop, area, (sum(popn_total)/area) as density
from cens_block_nbrs
group by nid,area,nbname
order by density desc
limit 3;

-- Optimizations

-- From A. a.

--                          QUERY PLAN

-- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--  Finalize GroupAggregate  (cost=926728.97..926729.72 rows=8 width=13) (actual time=16538.379..16549.969 rows=13 loops=1)   Group Key: station_colors.clr
--    ->  Gather Merge  (cost=926728.97..926729.62 rows=5 width=13) (actual time=16538.094..16549.942 rows=26 loops=1)
--          Workers Planned: 1
--          Workers Launched: 1
--          ->  Partial GroupAggregate  (cost=925728.96..925729.05 rows=5 width=13) (actual time=16464.691..16466.484 rows=13 loops=2)
--                Group Key: station_colors.clr
--                ->  Sort  (cost=925728.96..925728.97 rows=5 width=13) (actual time=16464.665..16465.157 rows=5387 loops=2)
--                      Sort Key: station_colors.clr
--                      Sort Method: quicksort  Memory: 395kB
--                      Worker 0:  Sort Method: quicksort  Memory: 495kB
--                      ->  Nested Loop  (cost=0.00..925728.90 rows=5 width=13) (actual time=2.094..16455.650 rows=5387 loops=2)
--                            Join Filter: ((station_colors.geom && st_expand(nyc_census_blocks.geom, '200'::double precision)) AND (nyc_census_blocks.geom && st_expand(station_colors.geom, '200'::double precision)) AND _st_dwithin(station_colors.geom, nyc_census_blocks.geom, '200'::double precision))
--                            Rows Removed by Join Filter: 12156532
--                            ->  Parallel Seq Scan on nyc_census_blocks  (cost=0.00..1861.20 rows=22820 width=252) (actual time=0.009..11.658 rows=19397 loops=2)
--                            ->  Seq Scan on station_colors  (cost=0.00..12.27 rows=627 width=37) (actual time=0.003..0.068 rows=627 loops=38794)
--  Planning Time: 1.204 ms
--  Execution Time: 16550.142 ms
-- (18 rows)

select clr,sum(popn_total) from nyc_census_blocks,station_colors
where ST_Dwithin(nyc_census_blocks.geom,station_colors.geom,200)
group by clr;

-- 6 second time difference, switching arguments of dwithin in query.

postgis_lab=# explain analyze select clr,sum(popn_total) from nyc_census_blocks,station_colors
postgis_lab-# where ST_Dwithin(nyc_census_blocks.geom,station_colors.geom,200)
postgis_lab-# group by clr;

--                          QUERY PLAN

-- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--  Finalize GroupAggregate  (cost=926728.97..926729.72 rows=8 width=13) (actual time=10329.792..10337.700 rows=13 loops=1)   Group Key: station_colors.clr
--    ->  Gather Merge  (cost=926728.97..926729.62 rows=5 width=13) (actual time=10328.734..10337.662 rows=26 loops=1)
--          Workers Planned: 1
--          Workers Launched: 1
--          ->  Partial GroupAggregate  (cost=925728.96..925729.05 rows=5 width=13) (actual time=10309.522..10310.825 rows=13 loops=2)
--                Group Key: station_colors.clr
--                ->  Sort  (cost=925728.96..925728.97 rows=5 width=13) (actual time=10309.496..10309.838 rows=5387 loops=2)
--                      Sort Key: station_colors.clr
--                      Sort Method: quicksort  Memory: 285kB
--                      Worker 0:  Sort Method: quicksort  Memory: 509kB
--                      ->  Nested Loop  (cost=0.00..925728.90 rows=5 width=13) (actual time=8.805..10300.162 rows=5387 loops=2)
--                            Join Filter: ((nyc_census_blocks.geom && st_expand(station_colors.geom, '200'::double precision)) AND (station_colors.geom && st_expand(nyc_census_blocks.geom, '200'::double precision)) AND _st_dwithin(nyc_census_blocks.geom, station_colors.geom, '200'::double precision))
--                            Rows Removed by Join Filter: 12156532
--                            ->  Parallel Seq Scan on nyc_census_blocks  (cost=0.00..1861.20 rows=22820 width=252) (actual time=0.009..9.484 rows=19397 loops=2)
--                            ->  Seq Scan on station_colors  (cost=0.00..12.27 rows=627 width=37) (actual time=0.002..0.058 rows=627 loops=38794)
--  Planning Time: 0.221 ms
--  Execution Time: 10337.808 ms
-- (18 rows)

-- B.
-- Area boundaries: https://gadm.org/
-- Population data: https://data.humdata.org/dataset/kontur-population-taiwan-province-of-china
-- Road data: https://data.humdata.org/dataset/hotosm_twn_roads
-- Health Facility data: https://data.humdata.org/dataset/hotosm_twn_health_facilities

-- Health facility analysis
create table pop_corr as
  select gid,cast(population as integer),geom
  from pop_places
  where population is not null;

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

create table lowest_per_diversity as
select h.name, diversity, avg_cov, geom from health_metrics h
where avg_cov =
  (select min(k.avg_cov) from health_metrics k where k.diversity = h.diversity);

create table lowest_diversity_towns as
select p.name, p.geom
from pop_places p, lowest_per_diversity l
where ST_Within(p.geom, l.geom);

-- Road analysis
create table major_roads as
select fid,name,geom,ST_Length(geom) as len
from roads 
where 
  highway='motorway' or highway='trunk' or highway='primary'
  and oneway is distinct from 'yes';

create table overworked_roads as
select sum(population) as pop, ST_Length(r.geom) as span, 
  sum(population)/ST_Length(r.geom) as density, r.geom
from pop_corr p, major_roads r
where ST_DWithin(r.geom, p.geom,0.05)
group by r.fid,r.geom
order by span,density desc;

create table road_cities as
select p.name, p.population, p.geom 
from pop_corr p, major_roads r
where ST_DWithin(r.geom, p.geom,0.05)
order by p.population desc
limit 2000;