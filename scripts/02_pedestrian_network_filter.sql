-- 2.6 Building the Pedestrian Network Dataset
-- Filters the road network (from 01_road_network_extraction.sql) to pedestrian-accessible
-- road types only, excluding motor-vehicle-only infrastructure.

highway IN (
    'footway', 'path', 'pedestrian', 'living_street',
    'residential', 'unclassified', 'service', 'steps',
    'tertiary', 'tertiary_link', 'secondary', 'secondary_link',
    'primary', 'primary_link'
)
