# NSW Fuel Analytics

A dbt-based analytics pipeline for transforming NSW FuelCheck station and fuel-price data into analytics-ready dimensional models and business-facing reporting datasets.

The project demonstrates a layered data architecture using **Snowflake + dbt**, including source management, staging, intermediate transformations, dimensional modeling, SCD Type 2 snapshots, reusable macros, governed seed mappings, data quality tests, and reporting models.

---

## 1. Project Objective

The objective of this project is to transform NSW FuelCheck data into a reliable analytical data model that can answer questions such as:

* What is the average fuel price by brand and fuel type?
* How are fuel prices changing day over day?
* Which brands have the greatest station and fuel-type coverage?
* Where is the cheapest fuel currently available?
* How have station attributes such as brand or station name changed over time?

The solution deliberately separates ingestion, transformation, business logic, dimensional modeling, and reporting responsibilities.

---

## 2. Architecture

```text
                 NSW FuelCheck
                      │
                      ▼
              Python Data Ingestion
                      │
                      ▼
              ┌─────────────────┐
              │     BRONZE      │
              │                 │
              │ nsw_stations_raw│
              │ nsw_prices_raw  │
              └────────┬────────┘
                       │
                       ▼
              ┌─────────────────┐
              │    STAGING      │
              │                 │
              │ nsw_stations_stg│
              │ nsw_prices_stg  │
              │                 │
              │ Rename / Cast   │
              │ Basic Cleaning  │
              └────────┬────────┘
                       │
                       ▼
              ┌────────────────────┐
              │    INTERMEDIATE    │
              │                    │
              │ nsw_fuel_data_int  │
              │ station_abr_int    │
              │                    │
              │ Join / Dedup /     │
              │ Business Logic     │
              └─────────┬──────────┘
                        │
                        ▼
              ┌────────────────────┐
              │    GOLD / MARTS    │
              │                    │
              │ dim_date           │
              │ dim_station        │
              │ dim_fuel_type      │
              │ fct_fuel_price     │
              └─────────┬──────────┘
                        │
                        ▼
              ┌────────────────────┐
              │     REPORTING      │
              │                    │
              │ daily_price_       │
              │ summary_rpt        │
              │ price_movement_rpt │
              │ station_coverage_  │
              │ rpt                │
              │ cheapest_station_  │
              │ rpt                │
              └────────────────────┘
```

---

## 3. Layered Data Model

### Bronze

The Bronze layer preserves the raw NSW FuelCheck data with minimal transformation.

Sources:

* `nsw_stations_raw`
* `nsw_prices_raw`

The raw tables are loaded into Snowflake from the NSW FuelCheck data using a Python ingestion process.

For this time-boxed assessment, the raw files are manually loaded into Snowflake. This is an ingestion constraint of the assessment environment rather than a recommended production ingestion pattern.

The downstream dbt architecture is independent of the ingestion mechanism.

---

### Staging

Staging models provide lightweight source standardization.

Models:

* `nsw_stations_stg`
* `nsw_prices_stg`

Responsibilities include:

* Column renaming
* Trimming and standardization
* Data type conversion
* Timestamp parsing
* Basic source-level cleansing

Staging models are materialized as **views** because they contain lightweight transformations and do not need to create another persisted copy of the data.

---

### Intermediate

The Intermediate layer contains reusable business transformations.

#### `nsw_fuel_data_int`

This model:

* Joins fuel prices to station reference data.
* Standardizes station and fuel-type identifiers.
* Validates prices and timestamps.
* Converts fuel prices from cents per litre to dollars per litre.
* Converts the intraday feed into a daily analytical grain.
* Selects the latest observation when multiple price observations exist during a day.

#### Grain

```text
station_code × fuel_type × price_date
```

For example, if a station reports multiple prices during a day:

```text
Station  Fuel   Time
1001     U91    08:00
1001     U91    12:00
1001     U91    18:00
```

the intermediate model retains the latest observation:

```text
Station  Fuel   Date        Price
1001     U91    2026-08-09  Latest observation
```

This establishes a consistent daily grain for downstream analytics.

Intermediate models are materialized as **tables** because they contain reusable business logic and are consumed by multiple downstream models.

---

### `station_abr_int`

Provides simulated ABR enrichment using a governed seed mapping.

The assessment does not use a live ABR API lookup. Instead, the implementation demonstrates the matching design using a controlled brand-level reference dataset.

The model exposes:

* ABN
* Entity name
* Entity type
* Match confidence
* Match method
* Live API verification indicator

The limitation is explicitly documented: a brand-level match identifies the national brand/franchisor and does not necessarily identify the legal entity operating an individual station.

A production implementation could replace this seed-based enrichment with a station-level ABR API integration.

---

## 4. Gold / Marts

The Gold layer follows a **Kimball-style star schema**.

```text
                     dim_date
                        │
                        │
                        ▼
dim_station ──────► fct_fuel_price ◄────── dim_fuel_type
```

### `dim_station`

Contains station attributes including:

* Station code
* Station name
* Brand
* Address
* Latitude
* Longitude
* ABR enrichment attributes

`station_code` is the source natural/business key.

A warehouse surrogate `station_key` is generated for use by the fact table.

---

### `dim_fuel_type`

A governed fuel-type dimension sourced from the `seed_fuel_type` reference dataset.

Contains:

* `fueltype_code`
* `fueltype_name`
* `product_category`

This avoids deriving fuel-type descriptions independently from transactional data and provides a consistent mapping across reporting models.

---

### `dim_date`

Provides calendar attributes for time-based analysis, including:

* Date key
* Date
* Year
* Month
* Month name
* Year-month
* Day of month
* Day name
* Weekend indicator

The date key uses a `YYYYMMDD` representation.

---

### `fct_fuel_price`

The central fact table for NSW fuel-price analytics.

#### Fact grain

> **One row per station × fuel type × day.**

Measures include:

* `price_cents`
* `price_per_litre_aud`

Foreign keys include:

* `date_key`
* `station_key`
* `fueltype_key`

A deterministic `price_key` is generated using:

```text
station_code + fueltype_code + price_date
```

This provides a stable identifier for the fact grain.

---

## 5. SCD Type 2 Snapshot

A dbt snapshot is implemented for station attributes.

Snapshot:

```text
snap_station
```

The snapshot uses:

* Natural key: `station_code`
* Strategy: `check`
* Tracked attributes:

  * `station_name`
  * `brand`
  * `address`
  * `latitude`
  * `longitude`

The snapshot demonstrates how historical changes can be retained.

For example:

```text
station_code | brand         | valid_from | valid_to
-------------|---------------|------------|---------
12345        | Shell         | 2026-08-09 | 2026-08-12
12345        | Reddy Express | 2026-08-12 | NULL
```

The current assessment dataset contains only one load, so the initial snapshot contains one version per station. A subsequent load with changed station attributes would create the next SCD2 version.

The `check` strategy is intentional because the current ingestion process does not provide a reliable business-level `updated_at` timestamp.

---

## 6. Reporting Layer

The reporting layer provides business-facing, consumption-ready datasets on top of the dimensional marts.

### `daily_price_summary_rpt`

Provides:

* Average price
* Lowest price
* Highest price
* Station count

grouped by:

* Date
* Fuel type
* Product category
* Brand

This supports fuel-price trend analysis.

---

### `price_movement_rpt`

Calculates day-over-day movement in average fuel price by fuel type.

Outputs include:

* Current average price
* Previous average price
* Absolute price movement
* Percentage price movement

This avoids requiring downstream analysts to repeatedly implement window-function logic.

---

### `station_coverage_rpt`

Provides brand-level coverage metrics including:

* Station count
* Fuel types offered
* Average price

The coverage is based on available fuel-price observations.

---

### `cheapest_station_rpt`

Answers the business question:

> **Where is the cheapest fuel currently available?**

The model identifies the latest loaded price date and returns the cheapest station for each fuel type.

Tied stations are retained so that equal lowest prices are not arbitrarily discarded.

---

## 7. dbt Macros

The project includes reusable macros to avoid duplicated transformation logic.

### `cents_to_dollars`

Converts cents per litre to dollars per litre.

```sql
{{ cents_to_dollars('price_cents') }}
```

### `generate_surrogate_key`

Generates deterministic MD5-based surrogate keys from one or more columns.

Example:

```sql
{{ generate_surrogate_key([
    'station_code',
    'fueltype_code',
    'price_date'
]) }}
```

Null and empty values are handled consistently.

### `generate_schema_name`

Overrides dbt's default custom-schema naming behavior so that models can be placed directly into:

```text
BRONZE
SILVER
GOLD
```

rather than automatically prefixing the target schema.

---

## 8. Data Quality

dbt tests are used to validate the analytical model.

Tests include:

* `not_null`
* `unique`
* `relationships`

Relationship tests validate referential integrity between the fact and dimensions:

```text
fct_fuel_price.station_key
        ↓
dim_station.station_key

fct_fuel_price.fueltype_key
        ↓
dim_fuel_type.fueltype_key

fct_fuel_price.date_key
        ↓
dim_date.date_key
```

During development, a station-key relationship test identified inconsistent station-code formatting between source datasets. The station code was standardized before surrogate-key generation, and the relationship test subsequently passed.

This ensures that warehouse keys are generated from consistently standardized natural keys.

---

## 9. Materialization Strategy

The project uses materialization based on the purpose and expected behavior of each layer.

| Layer        | Materialization |
| ------------ | --------------- |
| Raw / Bronze | Table           |
| Staging      | View            |
| Intermediate | Table           |
| Snapshot     | dbt Snapshot    |
| Marts / Gold | Table           |
| Reporting    | Table           |

Incremental processing can be introduced for the fuel-price fact at production scale.

For the current assessment, correctness and simplicity are prioritized because the dataset is small and the source ingestion is manually controlled.

A production incremental implementation would use an appropriate lookback window and `MERGE`/unique-key strategy to account for late-arriving or corrected fuel-price observations.

---

## 10. Seeds

The project uses seeds for governed reference mappings:

### `seed_fuel_type`

Provides the standardized fuel-type code, name, and product category mapping.

### `seed_brand_abr`

Provides the simulated ABR brand-level enrichment mapping used by `station_abr_int`.

Seeds are version-controlled with the dbt project and provide deterministic reference data for the transformation layer.

---

## 11. Project Structure

```text
fuel_analytics/
│
├── models/
│   │
│   ├── staging/
│   │   └── nsw/
│   │       ├── _sources.yml
│   │       ├── _stg_nsw__models.yml
│   │       ├── nsw_stations_stg.sql
│   │       └── nsw_prices_stg.sql
│   │
│   ├── intermediate/
│   │   └── nsw/
│   │       ├── nsw_fuel_data_int.sql
│   │       └── station_abr_int.sql
│   │
│   ├── marts/
│   │   └── nsw/
│   │       ├── dim_date.sql
│   │       ├── dim_station.sql
│   │       ├── dim_fuel_type.sql
│   │       ├── fct_fuel_price.sql
│   │       └── _marts.yaml
│   │
│   └── reporting/
│       └── nsw/
│           ├── daily_price_summary_rpt.sql
│           ├── price_movement_rpt.sql
│           ├── station_coverage_rpt.sql
│           ├── cheapest_station_rpt.sql
│           └── _reporting.yaml
│
├── snapshots/
│   └── stations_snapshot.sql
│
├── seeds/
│   ├── seed_fuel_type.csv
│   └── seed_brand_abr.csv
│
├── macros/
│   ├── cents_to_dollars.sql
│   ├── generate_schema_name.sql
│   └── generate_surrogate_key.sql
│
├── tests/
├── dbt_project.yml
└── README.md
```

---

## 12. Running the Project

Install dependencies if applicable and configure the Snowflake profile.

### Parse the project

```bash
dbt parse
```

### Compile SQL

```bash
dbt compile
```

### Load seeds

```bash
dbt seed
```

### Run models

```bash
dbt run
```

### Run tests

```bash
dbt test
```

### Build models and tests together

```bash
dbt build
```

### Full refresh

Useful after changing incremental model logic or during development:

```bash
dbt build --full-refresh
```

---

## 13. Production Considerations

The current implementation is designed for the assessment timebox while keeping the downstream architecture production-oriented.

A production implementation could extend the solution with:

* Automated API-to-cloud-object-storage ingestion.
* Snowflake external stages and automated loading.
* Snowpipe or event-driven ingestion.
* Incremental processing for large historical price datasets.
* Robust late-arriving-data handling.
* Live ABR API integration for station-level entity matching.
* Source freshness monitoring.
* Additional data-quality and anomaly detection tests.
* CI/CD checks requiring successful dbt builds and tests before merge.
* Environment-specific Snowflake roles and schemas.
* Observability and pipeline failure alerting.

The key design principle is that the **ingestion mechanism is decoupled from the dbt transformation layers**, allowing the raw ingestion process to evolve without requiring a redesign of the downstream analytical models.

---

## 14. Key Design Decisions

### Daily grain for NSW fuel prices

The NSW source provides intraday price observations. The model intentionally reduces these to:

```text
station × fuel type × day
```

using the latest observation for each day.

This provides a consistent daily grain for trend reporting.

### Natural keys vs surrogate keys

Source identifiers such as `station_code` and `fueltype_code` remain available as natural/business keys.

Surrogate keys are generated for dimensional warehouse relationships.

### SCD Type 2

Station attributes are snapshot-enabled so that changes such as rebranding or address updates can be historically tracked.

### Governed reference data

Fuel-type and simulated ABR mappings are maintained as dbt seeds rather than being derived independently in downstream models.

### Business-oriented reporting

The reporting layer exposes commonly requested analytical outputs so that consumers do not need to repeatedly reconstruct joins and business logic from the underlying fact and dimensions.

---

## 15. Summary

This project demonstrates an end-to-end dbt analytics architecture:

```text
Raw Data
   ↓
Bronze
   ↓
Staging
   ↓
Intermediate
   ↓
Gold / Dimensional Marts
   ↓
Business Reporting
```

The design prioritizes:

* Clear separation of responsibilities
* Reusable transformation logic
* Explicit data grain
* Dimensional modeling
* Historical tracking
* Data quality
* Governed reference data
* Business-oriented reporting
* Production extensibility
