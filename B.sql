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

-- Road/railway analysis
-- create table major_roads as
-- select fid,name,geom,ST_Length(geom) as len
-- from roads 
-- where 
--   highway='motorway' or highway='trunk' or highway='primary'
--   and oneway is distinct from 'yes';

-- create table overworked_roads as
-- select sum(population) as pop, ST_Length(r.geom) as span, 
--   sum(population)/ST_Length(r.geom) as density, r.geom
-- from pop_corr p, major_roads r
-- where ST_DWithin(r.geom, p.geom,0.05)
-- group by r.fid,r.geom
-- order by span,density desc;

-- create table road_cities as
-- select p.name, p.population, p.geom 
-- from pop_corr p, major_roads r
-- where ST_DWithin(r.geom, p.geom,0.05)
-- order by p.population desc
-- limit 2000;