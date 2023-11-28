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

