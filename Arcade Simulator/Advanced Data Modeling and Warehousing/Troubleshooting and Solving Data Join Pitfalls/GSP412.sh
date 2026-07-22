#!/bin/bash

BLACK_TEXT=$'\033[38;5;240m'
RED_TEXT=$'\033[38;5;203m'
GREEN_TEXT=$'\033[38;5;84m'
YELLOW_TEXT=$'\033[38;5;227m'
BLUE_TEXT=$'\033[38;5;75m'
MAGENTA_TEXT=$'\033[38;5;141m'
CYAN_TEXT=$'\033[38;5;51m'
WHITE_TEXT=$'\033[38;5;255m'

NO_COLOR=$'\033[0m'
RESET_FORMAT=$'\033[0m'

BOLD_TEXT=$'\033[1m'
UNDERLINE_TEXT=$'\033[4m'

clear

echo "${MAGENTA_TEXT}${BOLD_TEXT}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "               BIGQUERY DATA ANALYSIS LAB"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "${RESET_FORMAT}"

echo "${CYAN_TEXT}${BOLD_TEXT}Creating dataset...${RESET_FORMAT}"
bq mk ecommerce

echo "${YELLOW_TEXT}${BOLD_TEXT}Executing SQL workload...${RESET_FORMAT}"

bq query \
--use_legacy_sql=false \
"
SELECT DISTINCT
productSKU,
v2ProductName
FROM \`data-to-insights.ecommerce.all_sessions_raw\`;

SELECT
DISTINCT
productSKU
FROM \`data-to-insights.ecommerce.all_sessions_raw\`;

SELECT
  v2ProductName,
  COUNT(DISTINCT productSKU) AS SKU_count,
  STRING_AGG(DISTINCT productSKU LIMIT 5) AS SKU
FROM \`data-to-insights.ecommerce.all_sessions_raw\`
  WHERE productSKU IS NOT NULL
  GROUP BY v2ProductName
  HAVING SKU_count > 1
  ORDER BY SKU_count DESC;

SELECT
  productSKU,
  COUNT(DISTINCT v2ProductName) AS product_count,
  STRING_AGG(DISTINCT v2ProductName LIMIT 5) AS product_name
FROM \`data-to-insights.ecommerce.all_sessions_raw\`
  WHERE v2ProductName IS NOT NULL
  GROUP BY productSKU
  HAVING product_count > 1
  ORDER BY product_count DESC;

SELECT DISTINCT
  v2ProductName,
  productSKU
FROM \`data-to-insights.ecommerce.all_sessions_raw\`
WHERE productSKU = 'GGOEGPJC019099';

SELECT
  SKU,
  name,
  stockLevel
FROM \`data-to-insights.ecommerce.products\`
WHERE SKU = 'GGOEGPJC019099';

SELECT DISTINCT
  website.v2ProductName,
  website.productSKU,
  inventory.stockLevel
FROM \`data-to-insights.ecommerce.all_sessions_raw\` AS website
JOIN \`data-to-insights.ecommerce.products\` AS inventory
  ON website.productSKU = inventory.SKU
WHERE productSKU = 'GGOEGPJC019099';

WITH inventory_per_sku AS (
  SELECT DISTINCT
    website.v2ProductName,
    website.productSKU,
    inventory.stockLevel
  FROM \`data-to-insights.ecommerce.all_sessions_raw\` AS website
  JOIN \`data-to-insights.ecommerce.products\` AS inventory
    ON website.productSKU = inventory.SKU
  WHERE productSKU = 'GGOEGPJC019099'
)

SELECT
  productSKU,
  SUM(stockLevel) AS total_inventory
FROM inventory_per_sku
GROUP BY productSKU;

SELECT
  productSKU,
  ARRAY_AGG(DISTINCT v2ProductName) AS push_all_names_into_array
FROM \`data-to-insights.ecommerce.all_sessions_raw\`
WHERE productSKU = 'GGOEGAAX0098'
GROUP BY productSKU;

SELECT
  productSKU,
  ARRAY_AGG(DISTINCT v2ProductName LIMIT 1) AS push_all_names_into_array
FROM \`data-to-insights.ecommerce.all_sessions_raw\`
WHERE productSKU = 'GGOEGAAX0098'
GROUP BY productSKU;

SELECT DISTINCT
website.productSKU
FROM \`data-to-insights.ecommerce.all_sessions_raw\` AS website
JOIN \`data-to-insights.ecommerce.products\` AS inventory
ON website.productSKU = inventory.SKU;

SELECT DISTINCT
website.productSKU AS website_SKU,
inventory.SKU AS inventory_SKU
FROM \`data-to-insights.ecommerce.all_sessions_raw\` AS website
JOIN \`data-to-insights.ecommerce.products\` AS inventory
ON website.productSKU = inventory.SKU;

SELECT DISTINCT
website.productSKU AS website_SKU,
inventory.SKU AS inventory_SKU
FROM \`data-to-insights.ecommerce.all_sessions_raw\` AS website
LEFT JOIN \`data-to-insights.ecommerce.products\` AS inventory
ON website.productSKU = inventory.SKU;

SELECT DISTINCT
website.productSKU AS website_SKU,
inventory.SKU AS inventory_SKU
FROM \`data-to-insights.ecommerce.all_sessions_raw\` AS website
LEFT JOIN \`data-to-insights.ecommerce.products\` AS inventory
ON website.productSKU = inventory.SKU
WHERE inventory.SKU IS NULL;

SELECT *
FROM \`data-to-insights.ecommerce.products\`
WHERE SKU = 'GGOEGATJ060517';

SELECT DISTINCT
website.productSKU AS website_SKU,
inventory.SKU AS inventory_SKU
FROM \`data-to-insights.ecommerce.all_sessions_raw\` AS website
RIGHT JOIN \`data-to-insights.ecommerce.products\` AS inventory
ON website.productSKU = inventory.SKU
WHERE website.productSKU IS NULL;

SELECT DISTINCT
website.productSKU AS website_SKU,
inventory.*
FROM \`data-to-insights.ecommerce.all_sessions_raw\` AS website
RIGHT JOIN \`data-to-insights.ecommerce.products\` AS inventory
ON website.productSKU = inventory.SKU
WHERE website.productSKU IS NULL;

SELECT DISTINCT
website.productSKU AS website_SKU,
inventory.SKU AS inventory_SKU
FROM \`data-to-insights.ecommerce.all_sessions_raw\` AS website
FULL JOIN \`data-to-insights.ecommerce.products\` AS inventory
ON website.productSKU = inventory.SKU
WHERE website.productSKU IS NULL
OR inventory.SKU IS NULL;

CREATE OR REPLACE TABLE ecommerce.site_wide_promotion AS
SELECT .05 AS discount;

SELECT DISTINCT
productSKU,
v2ProductCategory,
discount
FROM \`data-to-insights.ecommerce.all_sessions_raw\` AS website
CROSS JOIN ecommerce.site_wide_promotion
WHERE v2ProductCategory LIKE '%Clearance%';

SELECT DISTINCT
productSKU,
v2ProductCategory,
discount
FROM \`data-to-insights.ecommerce.all_sessions_raw\` AS website
CROSS JOIN ecommerce.site_wide_promotion
WHERE v2ProductCategory LIKE '%Clearance%'
AND productSKU = 'GGOEGOLC013299';
"

echo
echo "${GREEN_TEXT}${BOLD_TEXT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}              BIGQUERY LAB COMPLETED SUCCESSFULLY             ${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"