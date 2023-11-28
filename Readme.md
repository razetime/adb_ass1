Tested on Windows

NTHU ADB course material specifies how to load data.

Python config (using miniconda): [Stack Overflow](https://stackoverflow.com/questions/71344780/importerror-dll-load-failed-while-importing-gdal-the-specified-module-could-n)
```bash
conda create -n env python=3.6 gdal
activate env
```

enable PostGIS on your database:
```sql
CREATE EXTENSION postgis;
```

`esriprj2standards.py` used on a `prj` file provides `EPSG` id for every given
`shp` file.
The load step for `shp` files is:
```bash
shp2pgsql -s <EPSG> nyc_streets.shp | psql -d <DB_NAME> postgres
```

shp2pgsql -s 4326 TWN_rrd\TWN_rails.shp | psql -d plb postgres

The load step for `gpkg` files is:
```bash
ogr2ogr -f PostgreSQL "PG:user=postgres password=<PASSWD> dbname=<DB_NAME>" kontur_population_TW_20231101.gpkg
```

Exporting a kml file from the generated table:
```
 ogr2ogr -f "KML" B1.kml PG:"host=localhost user=postgres dbname=plb password=<password>" "lowest_per_diversity"
```