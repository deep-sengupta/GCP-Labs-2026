BLACK=`tput setaf 0`
RED=`tput setaf 203`
GREEN=`tput setaf 48`
YELLOW=`tput setaf 220`
BLUE=`tput setaf 39`
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

BOLD_TEXT=`tput bold`
RESET_FORMAT=`tput sgr0`

clear

echo
echo "${MAGENTA}${BOLD_TEXT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"
echo "${MAGENTA}${BOLD_TEXT}              BIGQUERY PARTITIONING LAB SETUP               ${RESET_FORMAT}"
echo "${MAGENTA}${BOLD_TEXT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"
echo

echo "${CYAN}${BOLD_TEXT}▶ Creating dataset...${RESET_FORMAT}"
bq mk ecommerce

echo "${YELLOW}${BOLD_TEXT}▶ Querying sample data (2017)...${RESET_FORMAT}"
bq query --use_legacy_sql=false '
#standardSQL
SELECT DISTINCT
  fullVisitorId,
  date,
  city,
  pageTitle
FROM `data-to-insights.ecommerce.all_sessions_raw`
WHERE date = "20170708"
LIMIT 5
'

echo "${YELLOW}${BOLD_TEXT}▶ Querying sample data (2018)...${RESET_FORMAT}"
bq query --use_legacy_sql=false '
#standardSQL
SELECT DISTINCT
  fullVisitorId,
  date,
  city,
  pageTitle
FROM `data-to-insights.ecommerce.all_sessions_raw`
WHERE date = "20180708"
LIMIT 5
'

echo "${BLUE}${BOLD_TEXT}▶ Creating partitioned table...${RESET_FORMAT}"
bq query --use_legacy_sql=false '
 CREATE OR REPLACE TABLE ecommerce.partition_by_day
 PARTITION BY date_formatted
 OPTIONS(
   description="a table partitioned by date"
 ) AS
 SELECT DISTINCT
 PARSE_DATE("%Y%m%d", date) AS date_formatted,
 fullvisitorId
 FROM `data-to-insights.ecommerce.all_sessions_raw`
'

echo "${GREEN}${BOLD_TEXT}▶ Reading partition (2016)...${RESET_FORMAT}"
bq query --use_legacy_sql=false '
#standardSQL
SELECT *
FROM `data-to-insights.ecommerce.partition_by_day`
WHERE date_formatted = "2016-08-01"
'

echo "${GREEN}${BOLD_TEXT}▶ Reading partition (2018)...${RESET_FORMAT}"
bq query --use_legacy_sql=false '
#standardSQL
SELECT *
FROM `data-to-insights.ecommerce.partition_by_day`
WHERE date_formatted = "2018-07-08"
'

echo "${CYAN}${BOLD_TEXT}▶ Running precipitation query...${RESET_FORMAT}"
bq query --use_legacy_sql=false '
#standardSQL
 SELECT
   DATE(CAST(year AS INT64), CAST(mo AS INT64), CAST(da AS INT64)) AS date,
   (SELECT ANY_VALUE(name) FROM `bigquery-public-data.noaa_gsod.stations` AS stations
    WHERE stations.usaf = stn) AS station_name,
   prcp
 FROM `bigquery-public-data.noaa_gsod.gsod*` AS weather
 WHERE prcp < 99.9
   AND prcp > 0
   AND _TABLE_SUFFIX >= "2018"
 ORDER BY date DESC
 LIMIT 10
'

echo "${BLUE}${BOLD_TEXT}▶ Creating weather partitioned table...${RESET_FORMAT}"
bq query --use_legacy_sql=false '
 CREATE OR REPLACE TABLE ecommerce.days_with_rain
 PARTITION BY date
 OPTIONS (
   partition_expiration_days=60,
   description="weather stations with precipitation, partitioned by day"
 ) AS
 SELECT
   DATE(CAST(year AS INT64), CAST(mo AS INT64), CAST(da AS INT64)) AS date,
   (SELECT ANY_VALUE(name) FROM `bigquery-public-data.noaa_gsod.stations` AS stations
    WHERE stations.usaf = stn) AS station_name,
   prcp
 FROM `bigquery-public-data.noaa_gsod.gsod*` AS weather
 WHERE prcp < 99.9
   AND prcp > 0
   AND _TABLE_SUFFIX >= "2018"
'

echo
echo "${GREEN}${BOLD_TEXT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"
echo "${GREEN}${BOLD_TEXT}                 LAB COMPLETED SUCCESSFULLY                  ${RESET_FORMAT}"
echo "${GREEN}${BOLD_TEXT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"