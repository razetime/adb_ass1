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


-- From A. b.

--                                                            QUERY PLAN

-- ---------------------------------------------------------------------------------------------------------------------------------
--  Nested Loop  (cost=0.00..202218.76 rows=1668 width=48) (actual time=0.188..4520.257 rows=28793 loops=1)
--    Join Filter: ((n.geom ~ c.geom) AND _st_contains(n.geom, c.geom))
--    Rows Removed by Join Filter: 4975633
--    ->  Seq Scan on nyc_census_blocks c  (cost=0.00..2020.94 rows=38794 width=268) (actual time=0.018..13.520 rows=38794 loops=1)
--    ->  Materialize  (cost=0.00..16.93 rows=129 width=863) (actual time=0.000..0.009 rows=129 loops=38794)
--          ->  Seq Scan on nyc_neighborhoods n  (cost=0.00..16.29 rows=129 width=863) (actual time=0.009..0.051 rows=129 loops=1)
--  Planning Time: 0.194 ms
--  Execution Time: 4524.065 ms
-- (8 rows)

select ST_Area(n.geom) as area, c.blkid, c.popn_total, n.gid as nid, n.name as nbname
from nyc_census_blocks as c, nyc_neighborhoods as n
where ST_Within(c.geom, n.geom);

-- 300ms saved moving geometry to the beginning of the query.

--                                                            QUERY PLAN

-- ---------------------------------------------------------------------------------------------------------------------------------
--  Nested Loop  (cost=0.00..202218.76 rows=1668 width=48) (actual time=0.252..4198.997 rows=28793 loops=1)
--    Join Filter: ((n.geom ~ c.geom) AND _st_contains(n.geom, c.geom))
--    Rows Removed by Join Filter: 4975633
--    ->  Seq Scan on nyc_census_blocks c  (cost=0.00..2020.94 rows=38794 width=268) (actual time=0.029..12.542 rows=38794 loops=1)
--    ->  Materialize  (cost=0.00..16.93 rows=129 width=863) (actual time=0.000..0.009 rows=129 loops=38794)
--          ->  Seq Scan on nyc_neighborhoods n  (cost=0.00..16.29 rows=129 width=863) (actual time=0.015..0.059 rows=129 loops=1)
--  Planning Time: 0.213 ms
--  Execution Time: 4202.037 ms
-- (8 rows)

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

-- Road/railway analysis
create table op_rails as
select geom from twn_rails where exs_descri = 'Operational';

create table op_roads as
select geom from twn_roads
where
  rtt_descri = 'Primary Route' or rtt_descri = 'Secondary Route';

create table areas as
select gid, name_2 as name, geom from gadm41_twn_2;

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

create table roads_rails_per_area as
select a.gid, a.name,
  r.count as road_count, l.count as rail_count,
  cast(l.count as float)/cast(r.count as float) as ratio, a.geom
from areas a,road_count r,rail_count l
where a.gid = r.gid and a.gid = l.gid
order by ratio;