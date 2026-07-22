#!/bin/bash

BLACK=`tput setaf 8`
RED=`tput setaf 203`
GREEN=`tput setaf 82`
YELLOW=`tput setaf 226`
BLUE=`tput setaf 75`
MAGENTA=`tput setaf 141`
CYAN=`tput setaf 51`
WHITE=`tput setaf 15`

BG_BLACK=`tput setab 0`
BG_RED=`tput setab 1`
BG_GREEN=`tput setab 2`
BG_YELLOW=`tput setab 3`
BG_BLUE=`tput setab 4`
BG_MAGENTA=`tput setab 5`
BG_CYAN=`tput setab 6`
BG_WHITE=`tput setab 7`

BOLD=`tput bold`
RESET=`tput sgr0`

clear

echo "${MAGENTA}${BOLD}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "            BIGQUERY COVID DATA AUTOMATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "${RESET}"

export DATASET_NAME_1=covid
export DATASET_NAME_2=covid_data

echo "${CYAN}${BOLD}▶ Creating dataset and partitioned table${RESET}"
bq mk --dataset $DEVSHELL_PROJECT_ID:covid
sleep 10

echo "${YELLOW}${BOLD}➜ Creating partitioned oxford_policy_tracker table...${RESET}"
bq query --use_legacy_sql=false \
"
CREATE OR REPLACE TABLE $DATASET_NAME_1.oxford_policy_tracker
PARTITION BY date
OPTIONS(
partition_expiration_days=2175,
description='oxford_policy_tracker table in the COVID 19 Government Response public dataset with expiry time set to 2175 days.'
) AS
SELECT
   *
FROM
   \`bigquery-public-data.covid19_govt_response.oxford_policy_tracker\`
WHERE
   alpha_3_code NOT IN ('GBR', 'BRA', 'CAN','USA')
"

echo "${GREEN}${BOLD}✔ Task completed${RESET}"
echo

echo "${CYAN}${BOLD}▶ Updating global_mobility_tracker_data schema${RESET}"
echo "${YELLOW}${BOLD}➜ Adding required columns...${RESET}"

bq query --use_legacy_sql=false \
"
ALTER TABLE $DATASET_NAME_2.global_mobility_tracker_data
ADD COLUMN population INT64,
ADD COLUMN country_area FLOAT64,
ADD COLUMN mobility STRUCT<
   avg_retail FLOAT64,
   avg_grocery FLOAT64,
   avg_parks FLOAT64,
   avg_transit FLOAT64,
   avg_workplace FLOAT64,
   avg_residential FLOAT64
>
"

echo "${GREEN}${BOLD}✔ Task completed${RESET}"
echo

echo "${CYAN}${BOLD}▶ Building population tables${RESET}"

echo "${YELLOW}${BOLD}➜ Creating pop_data_2019...${RESET}"

bq query --use_legacy_sql=false \
"
CREATE OR REPLACE TABLE $DATASET_NAME_2.pop_data_2019 AS
SELECT *
FROM
\`bigquery-public-data.covid19_ecdc.covid_19_geographic_distribution_worldwide\`
"

echo "${YELLOW}${BOLD}➜ Creating pop_data_2019_small...${RESET}"

bq query --use_legacy_sql=false \
"
CREATE OR REPLACE TABLE $DATASET_NAME_2.pop_data_2019_small AS
SELECT
country_territory_code,
pop_data_2019
FROM
\`$DEVSHELL_PROJECT_ID.$DATASET_NAME_2.pop_data_2019\`
GROUP BY
country_territory_code,
pop_data_2019
ORDER BY
country_territory_code
"

echo "${YELLOW}${BOLD}➜ Updating population values...${RESET}"

bq query --use_legacy_sql=false \
"
UPDATE
\`$DATASET_NAME_2.consolidate_covid_tracker_data\` t0
SET
population=t1.pop_data_2019
FROM
\`$DATASET_NAME_2.pop_data_2019_small\` t1
WHERE
TRIM(t0.alpha_3_code)=TRIM(t1.country_territory_code);
"

echo "${GREEN}${BOLD}✔ Task completed${RESET}"
echo

echo "${CYAN}${BOLD}▶ Updating country area information${RESET}"

bq query --use_legacy_sql=false \
"
UPDATE
\`$DATASET_NAME_2.consolidate_covid_tracker_data\` t0
SET
t0.country_area=t1.country_area
FROM
\`bigquery-public-data.census_bureau_international.country_names_area\` t1
WHERE
t0.country_name=t1.country_name
"

echo "${GREEN}${BOLD}✔ Task completed${RESET}"
echo

echo "${CYAN}${BOLD}▶ Updating mobility statistics${RESET}"

bq query --use_legacy_sql=false \
"
UPDATE
\`$DATASET_NAME_2.consolidate_covid_tracker_data\` t0
SET
t0.mobility.avg_retail=t1.avg_retail,
t0.mobility.avg_grocery=t1.avg_grocery,
t0.mobility.avg_parks=t1.avg_parks,
t0.mobility.avg_transit=t1.avg_transit,
t0.mobility.avg_workplace=t1.avg_workplace,
t0.mobility.avg_residential=t1.avg_residential
FROM
(
SELECT
country_region,
date,
AVG(retail_and_recreation_percent_change_from_baseline) as avg_retail,
AVG(grocery_and_pharmacy_percent_change_from_baseline) as avg_grocery,
AVG(parks_percent_change_from_baseline) as avg_parks,
AVG(transit_stations_percent_change_from_baseline) as avg_transit,
AVG(workplaces_percent_change_from_baseline) as avg_workplace,
AVG(residential_percent_change_from_baseline) as avg_residential
FROM \`bigquery-public-data.covid19_google_mobility.mobility_report\`
GROUP BY country_region,date
) AS t1
WHERE
CONCAT(t0.country_name,t0.date)=CONCAT(t1.country_region,t1.date)
"

echo "${GREEN}${BOLD}✔ Bonus task completed${RESET}"
echo

echo "${CYAN}${BOLD}▶ Running validation queries${RESET}"

bq query --use_legacy_sql=false \
"
SELECT DISTINCT country_name
FROM \`$DATASET_NAME_2.oxford_policy_tracker_worldwide\`
WHERE population IS NULL
UNION ALL
SELECT DISTINCT country_name
FROM \`$DATASET_NAME_2.oxford_policy_tracker_worldwide\`
WHERE country_area IS NULL
ORDER BY country_name ASC
"

echo "${YELLOW}${BOLD}➜ Creating country_area_data...${RESET}"

bq query --use_legacy_sql=false \
"
CREATE TABLE $DATASET_NAME_2.country_area_data AS
SELECT *
FROM \`bigquery-public-data.census_bureau_international.country_names_area\`;
"

echo "${YELLOW}${BOLD}➜ Creating mobility_data...${RESET}"

bq query --use_legacy_sql=false \
"
CREATE TABLE $DATASET_NAME_2.mobility_data AS
SELECT *
FROM \`bigquery-public-data.covid19_google_mobility.mobility_report\`
"

echo "${YELLOW}${BOLD}➜ Removing incomplete records...${RESET}"

bq query --use_legacy_sql=false \
"
DELETE FROM covid_data.oxford_policy_tracker_by_countries
WHERE population IS NULL OR country_area IS NULL
"

echo
echo "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo "${GREEN}${BOLD}                 LAB COMPLETED SUCCESSFULLY                 ${RESET}"
echo "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo