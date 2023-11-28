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
