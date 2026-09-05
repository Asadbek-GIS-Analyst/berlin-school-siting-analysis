# berlin-school-siting-analysis.
GIS suitability analysis for new Grundschule sites in Berlin

![QGIS](https://img.shields.io/badge/QGIS-589632?style=for-the-badge&logo=qgis&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)
![PostGIS](https://img.shields.io/badge/PostGIS-008080?style=for-the-badge)
![ArcGIS Pro](https://img.shields.io/badge/ArcGIS%20Pro-2C7AC3?style=for-the-badge)
# Site Suitability Analysis for New Primary Schools (Grundschulen) in Berlin

A GIS-based multi-criteria decision analysis (MCDA) project identifying priority locations for new public primary schools in Berlin, Germany. The analysis combines demand-capacity mismatch (population vs. current school enrollment), pedestrian network accessibility, and land-use suitability to rank and validate candidate sites.

> ⚠️ **Disclaimer:** This analysis was created for educational/portfolio purposes. Results must be carefully reviewed and validated against official planning data before any practical application.

## Table of Contents
- [Project Goal](#project-goal)
- [Methodology](#methodology)
  - [1. Data Collection](#1-data-collection)
- [Data Sources](#data)
- [Tools Used](#tools-used)

## Project Goal

Where should new public primary schools be built in Berlin? This project answers that question by identifying Einschulbereich (school catchment) areas where the projected number of school-age children (6–12 years) exceeds current school capacity, cross-referenced with walking-distance accessibility to existing schools and land-use suitability for construction.

## Methodology

### 1. Data Collection

Eight datasets were collected to support the analysis, spanning school infrastructure, demographics, administrative boundaries, transportation network, and land-use planning.

| # | Dataset | Purpose |
|---|---|---|
| 1 | School locations + Einschulbereich (catchment areas) | Primary point/polygon layer |
| 2 | Current student/teacher counts per school | Demand-side baseline (current enrollment) |
| 3 | Klassenfrequenz (average class size by school type) | Capacity coefficient reference |
| 4 | Bezirk / Ortsteil administrative boundaries | Aggregation units |
| 5 | Population by age group (LOR-Planungsraum level) | Future demand (school-age population) |
| 6 | Street network | Network Analyst input (pedestrian accessibility) |
| 7 | Land-use plan (Flächennutzungsplan, FNP) | Identifying buildable land |

#### 1.1 Schools and Einschulbereich (Catchment Areas)

Retrieved via WFS from the Berlin Geoportal.

- **Dataset page:** [Schulen — Berlin Open Data](https://daten.berlin.de/datensaetze/schulen-wfs-ebc64e18)
- **WFS endpoint:**https://gdi.berlin.de/services/wfs/schulen
- **Format:** WFS → exported to GeoPackage
- Contains two layers: school points (with `BSN` — Berliner Schulnummer) and Einschulbereich polygons (with `ESB Nummer`, `Bez`, `Bezname`)

#### 1.2 Student and Teacher Statistics per School

- **Dataset page:** [Schüler- und Lehrkräftestatistik — Berlin Open Data](https://daten.berlin.de/datensaetze/schulen-in-berlin-1096779)
- **Format:** CSV/XLSX
- Join key: `BSN` (Berliner Schulnummer) — must match as text (leading zeros)

#### 1.3 Klassenfrequenz (Average Class Size)

- **Source:** [Blickpunkt Schule 2025/26 — Berlin.de Bildungsstatistik](https://www.berlin.de/sen/bildung/schule/bildungsstatistik/blickpunkt_schule_2025_26_tabellen_as.pdf)
- **Format:** PDF (table extracted manually to CSV)
- Used as the coefficient for translating population figures into theoretical school capacity

#### 1.4 Bezirk and Ortsteil Boundaries

- **Source:** [Bezirksgrenzen — ODIS Berlin](https://daten.odis-berlin.de/de/dataset/bezirksgrenzen/) | [Ortsteile — ODIS Berlin](https://daten.odis-berlin.de/de/dataset/ortsteile/)
- **Format:** Direct download (Shapefile / GeoJSON / GML / KML) — no WFS connection needed

#### 1.5 Population by Age Group (LOR-Planungsraum Level)

- **Dataset page:** [Einwohnerinnen und Einwohner in Berlin in LOR-Planungsräumen — Amt für Statistik Berlin-Brandenburg](https://daten.berlin.de/datensaetze/einwohnerinnen-und-einwohner-in-berlin-in-lor-planungsraumen-am-31-12-2025)
- **Format:** CSV (semicolon-delimited), 542 rows — one per Planungsraum
- Join key: `RAUMID` (8-digit code — must be imported as text to preserve leading zeros)
- Grundschule-age (6–12) population was computed by summing the fine age-bracket columns:E_E06_07 + E_E07_08 + E_E08_10 + E_E10_12

#### 1.6 LOR Boundaries (Planungsraum / Bezirksregion / Prognoseraum)

- **Dataset page:** [Lebensweltlich orientierte Räume (LOR) 01.01.2021 — WFS — Berlin Open Data](https://daten.berlin.de/datensaetze/lebensweltlich-orientierte-raume-lor-01-01-2021-wfs-34c86848)
- **WFS endpoint:** https://gdi.berlin.de/services/wfs/lor_2021
- Contains three nested levels: Planungsraum (542, finest), Bezirksregion (143), Prognoseraum (58, coarsest). Only **Planungsraum** was used, matching the population dataset's spatial resolution.

#### 1.7 Street Network (OpenStreetMap)

Two approaches were tested; the project ultimately used a PostgreSQL/PostGIS database (see below) pre-loaded with OSM data via `osm2pgsql`, rather than a fresh Geofabrik download.

- **Alternative / reference source:** [Geofabrik Berlin extract](https://download.geofabrik.de/europe/germany/berlin.html)
- **Actual workflow used:** SQL extraction from an existing `osm2pgsql`-imported PostGIS database (`hstore` schema) — see [1.8](#18-street-network-extraction-from-postgis) below

#### 1.8 Street Network — Extraction from PostGIS

The Berlin-Brandenburg OSM dataset was already loaded into PostgreSQL/PostGIS using `osm2pgsql` (hstore tag storage). The road network was extracted and cleaned directly via SQL, executed through QGIS's PostgreSQL connection (Data Source Manager → PostgreSQL → Execute SQL):

```sql
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
```

The query filters out non-existent/planned road segments and reprojects geometry directly to **EPSG:25833** (ETRS89 / UTM zone 33N), matching the project's working CRS. The resulting table was connected to QGIS as a PostgreSQL layer and exported to GeoPackage for further processing (pedestrian-accessible road types only — see Methodology step 4, Network Analysis).

#### 1.9 Land-Use Plan (Flächennutzungsplan, FNP)

- **Source page:** [FNP (Flächennutzungsplan Berlin), aktuelle Arbeitskarte — Metadata](https://gdi.berlin.de/geonetwork/srv/api/records/54c0236f-8179-368a-8442-006e231459af)
- **WFS endpoint:** *https://gdi.berlin.de/services/wfs/fnp_ak*
- Provides the `nutzungsart` (land-use type) attribute used to score buildable land in the suitability model

## Connecting to WFS Services in QGIS

All Berlin Geoportal datasets above (1.1, 1.4, 1.6, 1.9) were connected the same way:

1. **Layer → Add Layer → Add WFS Layer...**
2. **New Connection** → paste the WFS endpoint URL → **Connect**
3. Select the relevant layer(s) from the list → **Add**
4. Right-click the loaded layer → **Export → Save Features As...** → GeoPackage, target CRS **EPSG:25833**

This makes all raw data available locally, in a consistent CRS, independent of the live WFS connection.

## Data Sources

| Dataset | Provider | Access Method |
|---|---|---|
| Schools + Einschulbereich | Senatsverwaltung für Bildung, Berlin | WFS |
| Student/Teacher statistics | Senatsverwaltung für Bildung, Berlin | CSV/XLSX |
| Klassenfrequenz | Senatsverwaltung für Bildung, Berlin | PDF |
| Bezirk/Ortsteil boundaries | Geoportal Berlin (ODIS) | Direct download |
| Population by age | Amt für Statistik Berlin-Brandenburg | CSV |
| LOR boundaries | Geoportal Berlin | WFS |
| Street network | OpenStreetMap contributors (via PostGIS) | SQL / PostGIS |
| Land-use plan (FNP) | Senatsverwaltung für Stadtentwicklung, Berlin | WFS |

## Tools Used

- **ArcGIS Pro** — primary GIS platform (spatial analysis, Network Analyst, Weighted Overlay, cartographic layout)
- **QGIS** — WFS/PostGIS connections, data export
- **PostgreSQL / PostGIS** — OSM data storage and SQL-based extraction
### 2. Preprocessing

This stage determines the accuracy of the entire analysis and was never skipped, even where it required more elaborate solutions than initially planned.

#### 2.1 Coordinate System Standardization

All layers were reprojected to **EPSG:25833 (ETRS89 / UTM zone 33N)** — the standard CRS for Berlin. This step was applied consistently across every dataset before any spatial operation (join, intersect, raster conversion), since several sources (OSM, WFS layers) arrived in EPSG:4326 or EPSG:3857 by default.

#### 2.2 Enriching the School Point Layer

The official student/teacher statistics table was joined to the school point layer using **`BSN` (Berliner Schulnummer)** as the join key — the only reliable identifier, since school names are not written consistently across datasets. Both join fields were cast to text to preserve leading zeros (e.g. `01G01`), which otherwise causes silent join failures.

Result: each school point carries a `joriy_oquvchilar_soni` (current enrollment) attribute.

#### 2.3 Population Apportionment: Planungsraum → Einschulbereich

Population data is published at **Planungsraum** level (542 units), while the demand-capacity analysis requires figures at **Einschulbereich (ESB)** level — a completely independent, non-matching set of boundaries. A simple attribute join is not possible here; the two zoning systems must be reconciled spatially.

This was solved using **areal interpolation** (area-weighted population apportionment), assuming population is evenly distributed within each Planungsraum:

1. Compute each Planungsraum's original area:plr_maydon = $area
2. Compute Grundschule-age (6–12) population per Planungsraum, summing the fine age-bracket columns (see [1.5](#15-population-by-age-group-lor-planungsraum-level)):
```javascript
   var yosh_aholi = Number($feature.E_E06_07) +
                     Number($feature.E_E07_08) +
                     Number($feature.E_E08_10) +
                     Number($feature.E_E10_12);
```
   *(`Number()` is required because the source CSV imports these fields as text.)*
3. **Intersect** the ESB polygon layer with the Planungsraum layer, producing one fragment per unique ESB × Planungsraum overlap.
4. Compute each fragment's intersected area:kesishgan_maydon = $area
5. Apportion population to each fragment proportionally to its share of the original Planungsraum:
```javascript
   var nisbat = $feature.kesishgan_maydon / $feature.plr_maydon;
   return yosh_aholi * nisbat;
```
6. **Dissolve** all fragments by `ESB_Nummer`, summing the apportioned population, to obtain one final population estimate per ESB.

**Validation:** total original Grundschule-age population (219,373) vs. total after apportionment (214,649.3) — a **2.15% discrepancy**, within the acceptable range for areal interpolation and attributable to minor boundary mismatches between the two zoning systems.

#### 2.4 Linking Current Enrollment to Einschulbereich

Each ESB was linked to its assigned school's current enrollment via **Spatial Join** (`esb_poligon` as target, school points as join features, `CONTAINS`, one-to-one, `Field Map` merge rule = `Sum` on `joriy_oquvchilar_soni`).

> ⚠️ **Important:** the school layer must be filtered to **public Grundschule only** before this join. Including other school types (Gymnasium, ISS, etc.) that happen to fall inside the same ESB polygon would incorrectly inflate the apparent capacity of that catchment area, since those institutions serve a different, older age group with no relation to the 6–12 demand pool.

Result: 394 ESB polygons received an aggregated enrollment figure — matching the expected number of public Grundschule catchment areas in Berlin. 6 ESBs had no school within their boundary (`Join_Count = 0`) and were set to `0`.

#### 2.5 Demand-Capacity Gap
Gap = esb_grundschule_aholi − joriy_oquvchilar_soni

Where `esb_grundschule_aholi` is the apportioned 6–12 population from step 2.3, and `joriy_oquvchilar_soni` is the current enrollment from step 2.4.

> **Note on Klassenfrequenz:** the average class-size data (see [1.3](#13-klassenfrequenz-average-class-size)) was collected to compute a theoretical capacity (`classrooms × average class size`), but classroom-count data per school is not publicly available in Berlin's open data catalog. Current enrollment was used as a direct, defensible capacity proxy instead — a limitation stated explicitly rather than approximated with an unverifiable assumption.

A positive Gap indicates a shortage (more children than current enrollment can account for); a negative or near-zero Gap indicates a balanced or over-served catchment area.

#### 2.6 Building the Pedestrian Network Dataset

The road network (extracted in [1.8](#18-street-network-extraction-from-postgis)) was filtered to pedestrian-accessible road types only, excluding motor-vehicle-only infrastructure:

```sql
highway IN (
    'footway', 'path', 'pedestrian', 'living_street',
    'residential', 'unclassified', 'service', 'steps',
    'tertiary', 'tertiary_link', 'secondary', 'secondary_link',
    'primary', 'primary_link'
)
```

`motorway`, `motorway_link`, `trunk`, and `trunk_link` were excluded, since they cannot be used by pedestrians.

**Network Dataset creation (ArcGIS Pro):**
1. A new File Geodatabase was created (Network Datasets cannot be built inside a GeoPackage)
2. A Feature Dataset was created inside it, with coordinate system **EPSG:25833**
3. The filtered road layer was copied into the Feature Dataset
4. `New → Network Dataset` wizard was run on the Feature Dataset, using default connectivity (Any Vertex) and the automatically generated `Length` (meters) cost attribute
5. **Build Network** was run to finalize the dataset

This Network Dataset was used in the following stage (Network Analyst — Service Area) to compute realistic, street-network-based walking distances rather than straight-line (Euclidean) buffers.
### 3. Demand-Capacity Analysis — Validation and Interpretation

The core Gap calculation itself was performed as part of Preprocessing (see [2.3–2.5](#23-population-apportionment-planungsraum--einschulbereich)), since it required the same area-weighted interpolation pipeline. This section covers how the result was validated and interpreted before being carried into the suitability model.

#### 3.1 Choice of Aggregation Unit

**Einschulbereich (ESB)** — the officially defined catchment area Berlin uses to assign children to their nearest public Grundschule — was chosen as the aggregation unit, rather than administrative units like Bezirk or Ortsteil. This is the unit Berlin itself uses operationally to route children into schools, making it the most policy-relevant level for a demand-capacity analysis.

#### 3.2 Data Quality Checks

Before trusting the Gap values, the resulting ESB layer was checked for:

- **No `NULL` values** in `esb_grundschule_aholi`, `joriy_oquvchilar_soni`, or `Gap` — any remaining `NULL` traced back to incomplete joins (e.g. two ESBs — *Pankower Tor* and *Landweg* — returned `NA` for all age brackets in the source population CSV, later confirmed to be a large, still-largely-unbuilt new development area with near-zero current registered residents; these were set to `0`, a defensible value given the area's actual state, and flagged separately as a future-demand growth area worth noting in the report)
- **No duplicate `ESB_Nummer`** entries (checked via Summary Statistics, `COUNT` grouped by `ESB_Nummer`)
- **Total row count** matching the expected number of ESB polygons (394)
- **Sanity bounds**: population and enrollment values non-negative; Gap values spanning both positive and negative ranges as expected

#### 3.3 Interpreting Negative Gap Values

Not all ESBs show a positive Gap. Several show enrollment exceeding the apportioned local population — this is expected, not an error, and reflects real dynamics of Berlin's school admission system:

- Berlin's ESB assignment is a **first-priority right**, not an exclusive constraint — parents may apply to non-assigned schools (`Zweitwunsch`), so popular schools draw children from beyond their own catchment
- Enrollment figures are a **cumulative, 6-year snapshot** (grades 1–6), while population figures are a **single point-in-time count** — areas with recent demographic shifts will show a mismatch between the two
- The apportionment method (2.3) is a **statistical estimate**, not an exact count, and carries a validated ~2% margin of error

#### 3.4 Result

The Gap layer directly answers the question the initial 2 km Euclidean buffer analysis could not: not "how much area is nominally covered," but **"which specific catchment areas have more school-age children than their assigned school currently enrolls."** This became one of the two core inputs (alongside network-based accessibility) driving the final suitability model.
### 4. Real Accessibility (Network Analyst — Service Area)

This stage replaces the flawed 2 km Euclidean buffer with a network-based measure of actual walking accessibility.

#### 4.1 Network Dataset

Built in [2.6](#26-building-the-pedestrian-network-dataset) from the pedestrian-filtered road network, inside a File Geodatabase Feature Dataset, CRS **EPSG:25833**.

#### 4.2 Cost / Impedance Configuration

Two design decisions were made deliberately, and are documented here since they affect how the 1 km cutoff should be interpreted:

- **Distance-based, not time-based.** The Service Area cutoff is defined in **meters (Length)**, not minutes. A time-based impedance would require assuming a walking speed for a 6–12-year-old child — a figure with no reliable standard and one that would introduce unverifiable assumptions into the model. Distance is also the unit used in the official planning benchmark this project is based on (≈1 km walking distance for Grundschule catchment), so keeping the same unit avoids an unnecessary conversion step.
- **No turn restrictions / complex Travel Mode.** ArcGIS Pro's Network Dataset wizard (current version) builds connectivity automatically (`Any Vertex`) and generates the `Length` cost attribute without requiring a separate Travel Mode object. No custom turn restrictions, one-way rules, or barrier layers were added — the network was already reduced to pedestrian-accessible road types at the source ([2.6](#26-building-the-pedestrian-network-dataset)), which is the restriction that matters most for this analysis. Vehicle-only rules (`oneway`, `motor_vehicle` access tags) were intentionally not enforced, since they do not apply to pedestrians.

#### 4.3 Facilities Preparation

The school layer used as **Facilities** was filtered to public Grundschule only, using a Definition Query:

```sql
Schulart = 'Grundschule' AND Traegerschaft = 'öffentlich'
```

This mirrors the filter applied in [2.4](#24-linking-current-enrollment-to-einschulbereich) — including other school types here would compute accessibility to schools irrelevant to the 6–12 target population.

#### 4.4 Running the Service Area Analysis

1. **Analysis → Network Analysis → Service Area**
2. **Facilities:** filtered Grundschule layer (385 of 385 features successfully located on the network — no unreachable facilities)
3. **Cutoff (Break Value):** `1000` meters
4. **Impedance:** `Length` (meters)
5. **Solve**

Output: one polygon per school, shaped by the actual street network rather than a geometric circle — visibly interrupted by rivers, rail corridors, and other barriers a Euclidean buffer would ignore.

#### 4.5 Coverage Validation

The output polygons were dissolved into a single feature and compared against total Berlin area:Coverage % = Dissolved Service Area area / Total Berlin area × 100

| Method | Coverage |
|---|---|
| 2 km Euclidean buffer (initial, flawed approach) | ~98% |
| 1 km Network Service Area (final method) | **~19%** |

> **Interpretation:** the 19% figure is calculated against Berlin's *total land area*, which includes large uninhabited zones (forests, lakes, former airport grounds, industrial areas) that structurally cannot and do not need school coverage. A *population-weighted* coverage figure (share of residents, not land, within 1 km of a school) would be substantially higher and is noted in the final report as a more policy-relevant — though not computed in this iteration — complementary metric.

This result is the direct, quantitative confirmation of the problem the original buffer analysis masked: replacing an oversized, straight-line radius with a correctly scoped, network-based one reveals real gaps in walking accessibility across Berlin.

#### 4.6 Preparing the Result for the Suitability Model

The dissolved Service Area polygon was converted to a binary raster (`1` = covered) and inverted via Raster Calculator so that **uncovered areas receive the highest suitability score**:
Con(IsNull("coverage_raster"), 10, 1)
This became the `accessibility_final_raster` input to the Weighted Overlay stage (see Methodology step 6).
### 5. Reclassifying Suitability Criteria into Raster Layers

Each criterion was converted into a 1–10 raster scale (10 = most suitable), so all three could later be combined in a single Weighted Overlay.

#### 5.1 Shared Raster Environment Settings

Before building any of the three rasters, a consistent processing environment was set (**Analysis → Environments**) and reused for every subsequent step:

- **Processing Extent:** set to the dissolved Bezirk (Berlin) boundary layer
- **Cell Size:** `25` meters

> ⚠️ **Lesson learned:** Failing to apply the same Environment settings to *every* Polygon-to-Raster and Raster Calculator operation caused a real bug during this project — the FNP-derived raster ended up with a smaller true extent than the other two layers, which silently left a "hole" of no-data along Berlin's edge in the final Weighted Overlay output. Once identified (visible as unfilled basemap showing through the result), the FNP raster was rebuilt with the extent explicitly set to match the other layers. **Always set the Environment tab explicitly on every raster operation in a multi-layer overlay — do not rely on defaults.**

#### 5.2 Criterion 1 — Demand-Capacity Gap

Source: the `Gap` attribute from [Preprocessing 2.5](#25-demand-capacity-gap), at Einschulbereich level.

1. **Polygon to Raster** — Value Field: `Gap`, Cell Assignment: `Maximum Area`, Cell Size `25`
2. **Reclassify** — `Natural Breaks (Jenks)`, 10 classes (lowest Gap → class 1, highest Gap → class 10)
3. **Raster Calculator** — fill no-data (areas with no ESB coverage) with the lowest score:Con(IsNull("gap_reclass"), 0, "gap_reclass")
   → `gap_final_raster`

#### 5.3 Criterion 2 — Accessibility

Already produced in [4.6](#46-preparing-the-result-for-the-suitability-model): `accessibility_final_raster`, a binary 1/10 raster where uncovered (>1 km from a school) areas score 10.

#### 5.4 Criterion 3 — Land-Use Suitability (FNP)

Rather than a generic "buildable vs. not" binary, each of the FNP's 18 official `nutzungsart` (land-use type) categories was individually scored based on its real-world buildability for a school, since a coarse binary split would have discarded meaningful distinctions between, e.g., a public-purpose reserve and a highway corridor:

| Nutzungsart | Score | Rationale |
|---|---|---|
| Gemeinbedarfsfläche / (mit hohem Grünanteil) | 10 | Reserved for public-purpose institutions |
| Wohnbaufläche W4 (low density) | 7 | Low density, easier to find vacant land |
| Sonderbaufläche mit hohem Grünanteil, Wohnbaufläche W3 | 6 | Moderate density |
| Gemischte Baufläche M1/M2, Sonderbaufläche (general) | 5 | Mixed use, viable but not prioritized |
| Wohnbaufläche W2 | 4 | Higher density |
| Wohnbaufläche W1 | 3 | Highest residential density |
| Gewerbliche Baufläche, Einzelhandelskonzentration, Sonderbaufläche (gewerblich) | 2 | Commercial/industrial character |
| Sonderbaufläche Hauptstadtfunktion | 1 | Reserved for federal government use |
| Autobahn, übergeordnete Hauptverkehrsstraße | 0 | Transport infrastructure — not buildable |

```javascript
var n = $feature.nutzungsart;

if (n == 'Gemeinbedarfsfläche' ||
    n == 'Gemeinbedarfsfläche mit hohem Grünanteil') {
    return 10;
} else if (n == 'Wohnbaufläche, W4 (GFZ bis 0,4)' ||
           n == 'Wohnbaufläche, W4 (GFZ bis 0,4) mit landschaftlicher Prägung') {
    return 7;
} else if (n == 'Sonderbaufläche mit hohem Grünanteil' ||
           n == 'Wohnbaufläche, W3 (GFZ bis 0,8)' ||
           n == 'Wohnbaufläche, W3 (GFZ bis 0,8) mit landschaftlicher Prägung') {
    return 6;
} else if (n == 'Gemischte Baufläche, M1' ||
           n == 'Gemischte Baufläche, M2' ||
           n == 'Sonderbaufläche (entspr. Zweckbestimmung)') {
    return 5;
} else if (n == 'Wohnbaufläche, W2 (GFZ bis 1,5)') {
    return 4;
} else if (n == 'Wohnbaufläche, W1 (GFZ über 1,5)') {
    return 3;
} else if (n == 'Gewerbliche Baufläche' ||
           n == 'Einzelhandelskonzentration' ||
           n == 'Sonderbaufläche mit gewerblichem Charakter') {
    return 2;
} else if (n == 'Sonderbaufläche Hauptstadtfunktion (H)') {
    return 1;
} else if (n == 'Autobahn' ||
           n == 'übergeordnete Hauptverkehrsstraße') {
    return 0;
} else {
    return 0;
}
```

Then converted to raster and no-data-filled the same way as Criterion 1:
Con(IsNull("fnp_raster"), 0, "fnp_raster")
→ `landuse_final_raster`

> **Note:** an OpenStreetMap `landuse` extraction was used as an interim substitute for this criterion earlier in the project, before the official FNP WFS was located. The final model uses the authoritative FNP data exclusively.

#### 5.5 Criteria Considered but Excluded from the Model

Two additional criteria from the original project plan — **flood/hazard risk** and **public transit (ÖPNV) proximity** — were deliberately excluded from the final Weighted Overlay:

- **ÖPNV proximity** is methodologically inconsistent with this project's core premise: 6–12-year-old Grundschule children are expected to walk to school, which is precisely why a 1 km pedestrian network radius (Section 4) was used instead of a transit-based measure in the first place. Adding public-transit accessibility as an equally weighted factor would contradict that framing.
- **Flood/hazard layers** were identified as available during data scoping but were not incorporated, to keep the model to a smaller number of well-justified, evenly weighted criteria rather than expanding scope indefinitely.

Both remain valid directions for a follow-up iteration and are noted as such in the Limitations section of this project.

#### 5.6 Final Rasters

| Raster | Value Range | Source |
|---|---|---|
| `gap_final_raster` | 0–10 | Demand-Capacity Gap (Section 2, 5.2) |
| `accessibility_final_raster` | 1, 10 | Network Analyst Service Area (Section 4) |
| `landuse_final_raster` | 0–10 | Official FNP land-use classification (5.4) |
### 6. Weighted Overlay

The three reclassified rasters from Section 5 were combined into a single suitability surface.

#### 6.1 Weight Assignment

| Criterion | Weight | Justification |
|---|---|---|
| Demand-Capacity Gap | 40% | The primary research question — real, quantified shortage pressure |
| Accessibility Gap | 35% | Near-equal importance — physical distance to the nearest existing school |
| Land-Use Suitability | 25% | A necessary constraint, but secondary to demonstrated need |

These weights are a defensible starting assumption, not derived from a formal method (e.g. AHP pairwise comparison) — stated explicitly as a methodological choice open to adjustment in the Limitations section.

#### 6.2 Running Weighted Overlay

**Analysis → Tools → Weighted Overlay** (Spatial Analyst)

1. Added all three rasters (`gap_final_raster`, `accessibility_final_raster`, `landuse_final_raster`) with the weights above (`% Influence`, summing to 100)
2. **Scale:** `1–10`, matching the common scale all three inputs already shared
3. Remap table: **each input value mapped to itself** (`1→1`, ..., `10→10`, `NODATA→NODATA`)

> ⚠️ **Bug encountered and fixed:** ArcGIS Pro's automatic scale-matching (when the input scale doesn't exactly match the selected output scale) silently remapped `10 → 1` on the first attempt — inverting the meaning of the highest-suitability class. This was only caught by manually inspecting every row of each input's Remap table before running the tool. **Always verify the full Remap table manually for every input layer, especially the highest and lowest values, before executing Weighted Overlay** — the tool does not warn when this happens.

#### 6.3 Extent Consistency Check

Following the extent bug described in [5.1](#51-shared-raster-environment-settings), the three input rasters were re-verified to share an identical extent and cell size before the final overlay run, and the output was re-run once after the FNP raster was corrected.

#### 6.4 Result

`suitability_final` — a single raster covering Berlin, scored 1–10, where each cell's value reflects the weighted combination of local demand pressure, walking-distance accessibility gap, and land-use buildability.

#### 6.5 Clipping to Berlin's Boundary

Because all three input rasters shared a rectangular bounding-box extent larger than Berlin's actual (non-rectangular) administrative shape, the raw Weighted Overlay output also extended slightly beyond Berlin into Brandenburg, with a mid-range score (~4) caused by the asymmetric no-data handling between the accessibility layer (no-data → 10) and the other two (no-data → 0). This was resolved with:Analysis → Tools → Extract by Mask
Input raster: suitability_final
Input mask feature: dissolved Bezirk (Berlin) boundary
Extraction Area: INSIDE

→ `suitability_final_clean`, used as the input to candidate site extraction (Section 7).
### 7. Candidate Site Identification and Validation

This stage proved significantly more iterative than initially planned. A naive "extract high-score cells → done" approach repeatedly surfaced false positives — occupied land that scored highly only because zoning classification alone cannot distinguish "reserved for public use" from "already built and in active use." Each round of manual verification against satellite imagery revealed a new source of contamination, which was then fixed systematically rather than by manual case-by-case correction.

#### 7.1 Initial Extraction

```
Analysis → Tools → Extract by Attributes
Input: suitability_final_clean
Expression: Value >= 8
```
Analysis → Tools → Raster to Polygon
(Simplify polygons: unchecked, to preserve true cell boundaries)

The raw polygon output contained many tiny, sub-2,000 m² fragments — a natural artifact of raster-to-vector conversion — which were removed before further analysis.

#### 7.2 Priority Zone Selection

Given the resulting polygons ranged up to several km² (clearly representing broad priority *zones*, not individual construction parcels), a **300,000 m²** minimum was applied to isolate the largest, most defensible zones, which were then intersected with the source FNP layer and re-filtered to `fnp_ball >= 8`:253 candidate parcels

#### 7.3 First Round of False Positives — Occupied Institutional Land

Manual satellite-imagery review of the 253 parcels showed many corresponded to existing schools, colleges, museums, and other active public institutions — all legitimately zoned `Gemeinbedarfsfläche` (score 10), but not actually vacant.

**Fix, attempted in two steps:**

1. Building footprints were erased from each candidate parcel. An initial attempt to extract buildings from the existing PostGIS OSM database failed silently (`building` tag column existed but was entirely `NULL` for this import), so the **official ALKIS building footprint WFS** (`Hausumringe`) was used instead:https://gdi.berlin.de/services/wfs/alkis_gebaeude
2. Erasing only the building footprint was insufficient — large campus grounds (sports fields, courtyards, gardens) surrounding an existing institution's building remained classified as "vacant." The fix was to identify and erase the **entire parcel**, not just the building footprint, wherever any building intersected it:Select By Location: Gemeinbedarf parcels (fnp_ball ≥ 8) that Intersect any building
→ occupied_institutional_parcels → erased in full from the candidate set
3. Local streets are not represented as separate polygons in the FNP (only major arterials are), so a **10 m buffer around the road network**, dissolved into a single feature, was also erased from the candidates.

Result: **137 candidate parcels** (at this stage the FNP suitability threshold was relaxed from `fnp_ball >= 8` to `>= 7`, in order to avoid discarding legitimate lower-density residential candidates too aggressively).

> **Lesson:** many of the remaining "137" were themselves artifacts of an earlier `Aggregate Polygons` step (distance-based merging), which had silently combined dozens of geographically distant fragments into a single multipart feature — inflating its apparent total area far beyond what any individual fragment offered. Running **Multipart To Singlepart** and recomputing area per true fragment (rather than per merged feature) was necessary before any area-based filtering could be trusted.

#### 7.4 Minimum Parcel Size — Correcting an Initial Assumption

An initial 5,000 m² minimum-size cutoff (chosen as a quick filter for raster-conversion noise) was replaced with Berlin's own official Grundschule site-size standard once identified:

| Site quality | Area range |
|---|---|
| Below minimum (discarded) | < 8,000 m² |
| Near minimum | 8,000 – 10,000 m² |
| Realistic | 10,000 – 15,000 m² |
| Good candidate | 15,000 – 20,000 m² |
| Very good candidate | > 20,000 m² |

A hard filter at **8,000 m²** (Berlin's official minimum site size, ≈0.8 ha) was adopted, with the remaining tiers retained as a `maydon_toifa` classification field for prioritizing among the survivors — rather than an arbitrary round-number cutoff.

#### 7.5 Second Round of False Positives — FNP Zoning ≠ Actual Occupancy

Even after the building/institutional-parcel erase, many parcels still corresponded to visibly active colleges, schools, and service centers. The root cause: **FNP zoning describes legally intended land use, not current physical occupancy** — a large campus can be zoned `Gemeinbedarfsfläche` in full while genuinely vacant land exists only in small pockets that the building-erase step could not isolate.

**Fix:** switched to Berlin's ALKIS **"Tatsächliche Nutzung"** (actual/real current land use) dataset, which classifies every parcel by its real, present-day use — not planning intent:
https://gdi.berlin.de/services/wfs/alkis
(feature type: `tatsaechlichenutzung`, attribute `bezeich`, 24 standardized categories)

All occupied-use categories were erased from the candidate set, most importantly `AX_FlaecheBesondererFunktionalerPraegung` — the category that had been silently absorbing schools, colleges, hospitals, and similar institutions under one generic label:

```sql
bezeich IN (
    'AX_Wohnbauflaeche', 'AX_IndustrieUndGewerbeflaeche',
    'AX_FlaecheBesondererFunktionalerPraegung', 'AX_Friedhof',
    'AX_Bahnverkehr', 'AX_Strassenverkehr', 'AX_Flugverkehr',
    'AX_Hafenbecken', 'AX_Schiffsverkehr', 'AX_TagebauGrubeSteinbruch',
    'AX_StehendesGewaesser', 'AX_Fliessgewaesser', 'AX_Wald',
    'AX_Moor', 'AX_Sumpf', 'AX_Halde', 'AX_Weg'
)
```

Result: **91 candidate parcels.**

#### 7.6 Third Round — Legally Protected Land

A final check against Berlin's designated protection-status layers (a legal designation independent of zoning or current use) removed parcels falling inside nature/landscape protection areas:
https://gdi.berlin.de/services/wfs/schutzgebiete
Layers erased: `Naturschutzgebiet`, `Landschaftsschutzgebiet`, `Naturpark`, `FFH-Gebiete`, `SPA-Gebiete`, `Geschützter Landschaftsbestandteil`, `Flächen mit spezieller Regelung`, `Naturdenkmal` (polygon variant only — the point-based tree/boulder layer was excluded as irrelevant at this scale).

Result: **58 candidate parcels.**

#### 7.7 Scope Decision — Keeping the Model at Three Criteria

At this point, expanding the Weighted Overlay to include ÖPNV (public transit) accessibility, noise pollution (Lärmbelastung), and green-space quality (Grünflächenqualität) was considered, but rejected as a change to the *core model* — see [5.5](#55-criteria-considered-but-excluded-from-the-model) for the reasoning. These factors instead appear only as supporting context maps in the final layout (Section 8), not as inputs re-weighting the candidate ranking.

#### 7.8 Final Manual Verification

The 58 remaining candidates were individually reviewed against satellite imagery — checking for visible construction, informal/undocumented use, and general site viability that no dataset could fully capture. This step reduced the list to **15 validated final candidate sites**, of which the **top 10** (ranked by suitability score and parcel quality tier) were carried into the final map and summary table, each annotated with a short justification (e.g. access, shape regularity, nearby conflicts) based on the same visual review.

#### 7.9 Candidate Refinement Funnel

| Step | Candidates remaining |
|---|---|
| Extract by Attributes (Value ≥ 8) + priority-zone filter (≥300,000 m²) + FNP intersect | 253 |
| Erase buildings + occupied institutional parcels + road buffer | 137 |
| Minimum parcel size correction (8,000 m² official standard) | *(tier classification applied)* |
| Erase occupied "Tatsächliche Nutzung" categories | 91 |
| Erase legally protected nature/landscape areas | 58 |
| Manual satellite-imagery verification | 15 |
| Final report selection | **10** |
### 8. Final Cartographic Layout

The final deliverable is a single A2 (594 × 420 mm, landscape) composition combining the main suitability surface, three supporting context maps, a ranked candidate table, and standard cartographic elements.

#### 8.1 Layout Structure 

Outer margin: 2 cm from page edge to outer border; 1–1.5 cm from the border to inner content. Title sits inside the outer border, spanning the full page width.

#### 8.2 Title
Wo sollten neue Grundschulen in Berlin gebaut werden?
Standortanalyse für neue Grundschulen in Berlin
Eignungsbewertung auf Basis von Bedarf, Erreichbarkeit und Flächennutzung

The primary title uses "sollten" (should) rather than "können" (can/could) — deliberately framing the map as a recommendation, matching the suitability-ranking nature of the analysis rather than a simple feasibility check.

#### 8.3 Main Map

- **Basemap removed entirely** — a standard reference/street basemap under a 10-class choropleth suitability surface made the result unreadable; a plain white background with only Bezirk boundaries (thin grey outline, no fill) was used instead
- **Candidate markers:** the final top-10 candidate polygons were converted to centroid points (`Feature to Point`, "Inside" option enabled to guarantee the point falls within the polygon) and symbolized as a bold star marker, layered over a semi-transparent outline of the original polygon shape
- **District (Bezirk) labels** given a white halo (1–1.5 pt) to remain legible over any background color

#### 8.4 Legend

The raw 10-class `Eignungswert` (suitability value) symbology was grouped into three semantic tiers for faster reading, without altering the underlying 1–10 raster values — done via `Symbology → Classify → Manual Interval` (breaks at 3 and 6) rather than editing the data itself:

| Group | Range | Label |
|---|---|---|
| Low suitability | 1–3 | Niedrige Eignung |
| Medium suitability | 4–6 | Mittlere Eignung |
| High suitability | 7–10 | Hohe Eignung |

#### 8.5 Context Maps

Three small supporting maps surround the main map, each with its own title, distinct from the main map's color scheme to avoid visual confusion between "this is the same data" and "this is a different metric":

1. **Locator (Übersichtskarte):** Germany outline with Berlin highlighted. Berlin's true geographic size (~0.25% of Germany's area) is imperceptible at this scale, so it is represented by a deliberately oversized marker rather than true-to-scale shading — standard locator-map convention, not a factual inaccuracy.
2. **Accessibility ("Erreichbarkeit bestehender Grundschulen (1 km Fußweg)" / subtitle: "Netzwerkbasierte Erreichbarkeitsanalyse im 1-km-Fußwegradius"):** the Service Area output from Section 4, with existing Grundschule locations marked, explicitly demonstrating the network-based (not Euclidean) methodology.
3. **Demand ("Bedarfsdeckung nach Einschulbereich"):** the Gap layer from Section 2–3, at ESB level, using a **diverging color scheme** (blue = capacity surplus, white ≈ balanced, red = high shortage) — deliberately different from the main map's sequential red-yellow-green palette. Class breaks were set with **Natural Breaks (Jenks)**, not manual round numbers, after an initial manual-interval attempt put ~80% of Berlin in a single class (the data is strongly right-skewed — most ESBs cluster near zero/negative, with a long tail of high-shortage outliers).

#### 8.6 Top Candidate Table

Columns: `Rang`, `Kandidat`, `Bezirk`, `FNP-Nutzungsart`, `Koordinaten (WGS84)`, `Bemerkung`. The `Bemerkung` (remark) column captures the manual satellite-review findings from [7.8](#78-final-manual-verification) — e.g. site shape, access quality, or specific conflicts (flood-zone proximity, informal use to be cleared) — turning the visual QA step into part of the documented deliverable rather than a discarded intermediate check.

> **Note:** the `FNP-Nutzungsart` shown per candidate reflects a manually verified, majority land-use type per site — the automatically computed centroid-based label was found to occasionally misrepresent irregularly shaped or multi-zone parcels, and was corrected against direct visual/attribute inspection of each final candidate before publication.

#### 8.7 Supporting Elements

- **Coordinate grid:** measured grid (not graticule — this is a projected, straight-line metric grid based on EPSG:25833, not a lat/lon curved grid), 5 km interval, light grey, ~50% transparency, 0.3–0.5 pt line weight
- **North arrow, scale bar:** standard placement near the main map's legend
- **Scale bar formatting:** ArcGIS Pro's dynamic scale text (`formatted="true"`) uses the OS locale's thousands separator, which does not reliably produce the German period separator (`1:250.000`) on a non-German-locale system — resolved with a static text element for the final export rather than relying on live dynamic text
- **Footer:** three-column layout — disclaimer (left, italic, stating the analysis is for educational purposes and requires validation against official data before practical use), data sources (center), author/date/projection metadata (right) — all at a consistently smaller point size than any other text on the page

#### 8.8 Export

Exported at 300 DPI with embedded fonts, as both PDF (print/archival) and PNG (web/portfolio use).
## Results

- **394** Einschulbereich (Grundschule catchment areas) analyzed across Berlin
- **19%** of Berlin's total land area falls within a 1 km network-based walking distance of an existing public Grundschule — compared to the **~98%** an initial, methodologically flawed 2 km Euclidean buffer suggested, demonstrating why straight-line buffers overstate real accessibility in a city shaped by rivers, rail corridors, and other physical barriers
- Population apportionment from Planungsraum to Einschulbereich level was validated at a **2.15%** margin of error (219,373 vs. 214,649.3 estimated 6–12-year-old residents)
- The Weighted Overlay (40% demand-capacity gap / 35% accessibility / 25% land-use suitability) produced a continuous 1–10 suitability surface across Berlin
- An iterative, multi-stage exclusion process (buildings → occupied institutional parcels → road buffers → actual land-use occupancy → legally protected areas → manual satellite verification) narrowed an initial set of 253 nominally high-scoring parcels down to **15 validated candidate sites**, of which the top **10** are presented with district, land-use classification, coordinates, and site-specific remarks
- Candidate sites cluster primarily in **Marzahn-Hellersdorf, Lichtenberg, Treptow-Köpenick, and Spandau** — outer districts where population growth and/or lower existing school density outweigh the generally lower land-use pressure compared to central Berlin

## Limitations

This analysis was built for portfolio/educational purposes and has several known limitations that should be addressed before any practical planning use:

- **Capacity proxy, not theoretical capacity.** Classroom-count data per school is not available in Berlin's open data catalog, so current enrollment was used as a capacity proxy instead of a `classrooms × Klassenfrequenz` theoretical capacity. This may understate shortage in schools operating below their physical capacity, or overstate it in overcrowded ones.
- **Demand and enrollment are not perfectly comparable in time.** Population figures are a single-date snapshot; enrollment figures are cumulative across six grade levels and reflect admission decisions made in prior years, including cross-catchment enrollment (`Zweitwunsch`) that this model cannot separate out.
- **New development areas are undercounted.** Two Einschulbereiche (Pankower Tor, Landweg) returned zero/near-zero current population because they are large, still-largely-unbuilt development zones — a snapshot-based model cannot anticipate the school demand these areas will generate once construction completes, even though the city has already earmarked space for a Grundschule in at least one of them.
- **Three-criterion model, deliberately scoped.** Public transit accessibility, noise exposure, and green-space quality were identified as relevant factors but excluded from the weighted formula — ÖPNV for methodological inconsistency with a walking-distance-based child population, the others to keep the model to a small number of well-justified, evenly weighted criteria. All three would be reasonable additions in a follow-up iteration, either as new weighted inputs or as constraint layers on the final candidate list.
- **Weights are a stated assumption, not a derived result.** The 40/35/25 weighting was chosen and justified narratively, not calculated via a formal method such as AHP pairwise comparison. Different, equally defensible weightings would shift the ranking, particularly among mid-tier candidates.
- **Zoning describes intent, not occupancy — and this required real correction mid-project.** FNP land-use classification alone repeatedly misclassified actively used institutional campuses as vacant; this was corrected using Berlin's separate "Tatsächliche Nutzung" (actual current use) dataset, but the underlying gap between planning and reality means any newer construction not yet reflected in either dataset could still be missed.
- **Final candidate validation was manual.** The last stage of candidate selection depended on visual satellite-imagery review rather than a fully automated, reproducible spatial rule — a necessary step given the limits of available occupancy data, but one that introduces some reviewer judgment into the final ranking.
- **Coverage is reported by land area, not population.** The 19% accessibility figure is calculated against Berlin's total land area, which includes large uninhabited zones. A population-weighted coverage metric (share of residents within 1 km of a school) would be more policy-relevant and was not computed in this iteration.

### Possible Future Work

- Population-weighted (rather than area-weighted) accessibility coverage
- Formal AHP-based weight derivation, with sensitivity analysis on the final ranking
- Integration of ÖPNV accessibility, noise exposure, and green-space quality as either additional weighted criteria or post-hoc constraint filters
- Automated occupancy verification (e.g. building recency via satellite change-detection) to reduce dependency on manual review
