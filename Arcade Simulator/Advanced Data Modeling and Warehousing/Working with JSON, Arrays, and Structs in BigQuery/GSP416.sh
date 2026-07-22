#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="$(gcloud config get-value project 2>/dev/null | tr -d '\r')"

if [[ -z "${PROJECT_ID}" || "${PROJECT_ID}" == "(unset)" ]]; then
  echo "No active Google Cloud project found. Run: gcloud config set project PROJECT_ID" >&2
  exit 1
fi

BQ() {
  bq --project_id="${PROJECT_ID}" "$@"
}

ensure_dataset() {
  local dataset="$1"
  if ! BQ show "${PROJECT_ID}:${dataset}" >/dev/null 2>&1; then
    BQ mk --dataset --location=US "${PROJECT_ID}:${dataset}"
  fi
}

ensure_fruit_details() {
  if ! BQ show "${PROJECT_ID}:fruit_store.fruit_details" >/dev/null 2>&1; then
    BQ load \
      --source_format=NEWLINE_DELIMITED_JSON \
      --autodetect \
      "${PROJECT_ID}:fruit_store.fruit_details" \
      "gs://spls/gsp416/data-insights-course/labs/optimizing-for-performance/shopping_cart.json"
  fi
}

ensure_race_results() {
  if ! BQ show "${PROJECT_ID}:racing.race_results" >/dev/null 2>&1; then
    local schema_file
    schema_file="$(mktemp)"
    cat > "${schema_file}" <<'JSON'
[
  {
    "name": "race",
    "type": "STRING",
    "mode": "NULLABLE"
  },
  {
    "name": "participants",
    "type": "RECORD",
    "mode": "REPEATED",
    "fields": [
      {
        "name": "name",
        "type": "STRING",
        "mode": "NULLABLE"
      },
      {
        "name": "splits",
        "type": "FLOAT",
        "mode": "REPEATED"
      }
    ]
  }
]
JSON
    BQ load \
      --source_format=NEWLINE_DELIMITED_JSON \
      "${PROJECT_ID}:racing.race_results" \
      "gs://spls/gsp416/data-insights-course/labs/optimizing-for-performance/race_results.json" \
      "${schema_file}"
    rm -f "${schema_file}"
  fi
}

run_query() {
  local title="$1"
  shift
  echo
  echo "=============================="
  echo "${title}"
  echo "=============================="
  BQ query --use_legacy_sql=false --quiet "$@"
}

echo "Using project: ${PROJECT_ID}"

ensure_dataset "fruit_store"
ensure_fruit_details
ensure_dataset "racing"
ensure_race_results

run_query "Task 2 - simple array" <<'SQL'
SELECT
  ['raspberry', 'blackberry', 'strawberry', 'cherry'] AS fruit_array
SQL

run_query "Task 2 - public fruit table" <<'SQL'
SELECT person, fruit_array, total_cost
FROM `data-to-insights.advanced.fruit_store`
SQL

run_query "Task 3 - ARRAY_AGG" <<'SQL'
SELECT
  fullVisitorId,
  date,
  ARRAY_AGG(v2ProductName) AS products_viewed,
  ARRAY_AGG(pageTitle) AS pages_viewed
FROM `data-to-insights.ecommerce.all_sessions`
WHERE visitId = 1501570398
GROUP BY fullVisitorId, date
ORDER BY date
SQL

run_query "Task 3 - ARRAY_AGG with length" <<'SQL'
SELECT
  fullVisitorId,
  date,
  ARRAY_AGG(v2ProductName) AS products_viewed,
  ARRAY_LENGTH(ARRAY_AGG(v2ProductName)) AS num_products_viewed,
  ARRAY_AGG(pageTitle) AS pages_viewed,
  ARRAY_LENGTH(ARRAY_AGG(pageTitle)) AS num_pages_viewed
FROM `data-to-insights.ecommerce.all_sessions`
WHERE visitId = 1501570398
GROUP BY fullVisitorId, date
ORDER BY date
SQL

run_query "Task 3 - distinct arrays" <<'SQL'
SELECT
  fullVisitorId,
  date,
  ARRAY_AGG(DISTINCT v2ProductName) AS products_viewed,
  ARRAY_LENGTH(ARRAY_AGG(DISTINCT v2ProductName)) AS distinct_products_viewed,
  ARRAY_AGG(DISTINCT pageTitle) AS pages_viewed,
  ARRAY_LENGTH(ARRAY_AGG(DISTINCT pageTitle)) AS distinct_pages_viewed
FROM `data-to-insights.ecommerce.all_sessions`
WHERE visitId = 1501570398
GROUP BY fullVisitorId, date
ORDER BY date
SQL

run_query "Task 4 - array field inspection" <<'SQL'
SELECT *
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_20170801`
WHERE visitId = 1501570398
SQL

run_query "Task 4 - UNNEST hits" <<'SQL'
SELECT DISTINCT
  visitId,
  h.page.pageTitle
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_20170801`,
UNNEST(hits) AS h
WHERE visitId = 1501570398
LIMIT 10
SQL

run_query "Task 6/7 - count racers" <<'SQL'
SELECT COUNT(p.name) AS racer_count
FROM racing.race_results AS r, UNNEST(r.participants) AS p
SQL

run_query "Task 8 - total race time for R runners" <<'SQL'
SELECT
  p.name,
  SUM(split_times) AS total_race_time
FROM racing.race_results AS r
, UNNEST(r.participants) AS p
, UNNEST(p.splits) AS split_times
WHERE p.name LIKE 'R%'
GROUP BY p.name
ORDER BY total_race_time ASC
SQL

run_query "Task 9 - fastest lap" <<'SQL'
SELECT
  p.name,
  split_time
FROM racing.race_results AS r
, UNNEST(r.participants) AS p
, UNNEST(p.splits) AS split_time
WHERE split_time = 23.2
SQL

echo
echo "Done."