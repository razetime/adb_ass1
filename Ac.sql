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
