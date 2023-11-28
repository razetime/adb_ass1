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