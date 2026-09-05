-- Berlin-Brandenburg OSM road network extraction from PostGIS (osm2pgsql, hstore)
-- Executed via QGIS PostgreSQL connection (Data Source Manager -> Execute SQL)

CREATE TABLE berlin_brandenburg_road_network AS
SELECT
    osm_id,
    tags -> 'name' AS road_name,
    tags -> 'name:de' AS road_name_de,
    tags -> 'ref' AS road_ref,
    tags -> 'highway' AS highway,
    -- safe conversion of maxspeed
    CASE
        WHEN tags -> 'maxspeed' ~ '^\d+$' THEN (tags -> 'maxspeed')::integer
        ELSE NULL
    END AS maxspeed_kmh,
    CASE
        WHEN tags -> 'lanes' ~ '^\d+$' THEN (tags -> 'lanes')::integer
        ELSE NULL
    END AS lanes,
    tags -> 'oneway' AS oneway,
    tags -> 'access' AS access,
    tags -> 'motor_vehicle' AS motor_vehicle,
    tags -> 'vehicle' AS vehicle,
    tags -> 'foot' AS foot_access,
    tags -> 'bicycle' AS bicycle_access,
    tags -> 'junction' AS junction_type,
    tags -> 'bridge' AS bridge,
    tags -> 'tunnel' AS tunnel,
    CASE
        WHEN tags -> 'layer' ~ '^-?\d+$' THEN (tags -> 'layer')::integer
        ELSE NULL
    END AS layer_level,
    tags -> 'surface' AS surface,
    tags -> 'smoothness' AS smoothness,
    ST_Transform(way, 25833) AS geom,
    ST_Length(ST_Transform(way, 25833)) AS length_meters
FROM
    planet_osm_line
WHERE
    tags ? 'highway'
    AND tags -> 'highway' NOT IN ('proposed', 'construction', 'abandoned', 'platform')
    AND ST_GeometryType(way) = 'ST_LineString';
