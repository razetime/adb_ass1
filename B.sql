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