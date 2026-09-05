# Berlin School Siting Project — SQL/Query Snippets

SQL queries and Definition Queries used in the Berlin Grundschule site-suitability
analysis project. Each one corresponds to a specific stage of the project.

GitHub repo: https://github.com/Asadbek-GIS-Analyst/berlin-school-siting-analysis

## File overview and usage

### 01_road_network_extraction.sql
**Stage:** 1.8 — Street Network Extraction from PostGIS
**Where it was run:** QGIS → Data Source Manager → PostgreSQL → Execute SQL
**What it does:** Extracts the full road network from the Berlin-Brandenburg OSM
data (stored via osm2pgsql in hstore format in the `planet_osm_line` table) and
creates a new table, `berlin_brandenburg_road_network`. Only features with a
`highway` tag are kept, excluding types irrelevant to the project (proposed,
construction, abandoned, platform). Geometry is reprojected to EPSG:25833, and
length is computed in meters.

### 02_pedestrian_network_filter.sql
**Stage:** 2.6 — Building the Pedestrian Network Dataset
**Where it was used:** ArcGIS Pro — as a Definition Query / SQL filter on the
road network layer produced in file 01
**What it does:** Excludes road types not accessible to pedestrians (motor-vehicle-
only infrastructure), keeping only highway types walkable by pedestrians (footway,
path, pedestrian, residential, etc.). Prepares the pedestrian network for the
Network Analyst Service Area analysis.

### 03_facilities_grundschule_filter.sql
**Stage:** 4.3 — Facilities Preparation
**Where it was used:** ArcGIS Pro — Definition Query on the schools layer
**What it does:** Restricts the "Facilities" (target points) used in the Network
Analyst analysis to public (öffentlich) Grundschule schools only, excluding other
school types (Gymnasium, ISS, etc.).

### 04_occupied_use_categories_erase.sql
**Stage:** Stage 7 — Candidate Site Filtering (erasing occupied areas)
**Where it was used:** ArcGIS Pro — Definition Query / Select by Attributes on
the official Berlin FNP/ALKIS layer (`bezeich` field), followed by an Erase
**What it does:** Removes all occupied land-use categories from the candidate
site set — most importantly `AX_FlaecheBesondererFunktionalerPraegung`, the
generic category that was silently absorbing institutions such as schools,
colleges, and hospitals. This fix ensures only genuinely vacant land remains
for potential school construction.

## Execution order (workflow)
1. `01_road_network_extraction.sql` — build the full road network in PostGIS
2. `02_pedestrian_network_filter.sql` — filter that network down to a pedestrian network
3. `03_facilities_grundschule_filter.sql` — prepare the schools layer as Facilities
4. `04_occupied_use_categories_erase.sql` — remove occupied areas from candidate sites