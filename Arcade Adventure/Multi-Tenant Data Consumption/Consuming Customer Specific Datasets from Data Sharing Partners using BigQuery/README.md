# Consuming Customer Specific Datasets from Data Sharing Partners using BigQuery

<h2>📋 Steps</h2>

<ol>
  <li>
    Open the <b>Data Sharing Partner</b> project console.
  </li>

  <li>
    Open <b>Cloud Shell</b> and paste the following command:
    <pre><code>#!/bin/bash

CLR_RED=$(tput setaf 1)
CLR_GREEN=$(tput setaf 2)
CLR_YELLOW=$(tput setaf 3)
CLR_BLUE=$(tput setaf 4)
CLR_MAGENTA=$(tput setaf 5)
CLR_CYAN=$(tput setaf 6)

STYLE_BOLD=$(tput bold)
STYLE_RESET=$(tput sgr0)

COLORS=("$CLR_RED" "$CLR_GREEN" "$CLR_YELLOW" "$CLR_BLUE" "$CLR_MAGENTA" "$CLR_CYAN")
RANDOM_COLOR=${COLORS[$((RANDOM % ${#COLORS[@]}))]}

echo "${STYLE_BOLD}${RANDOM_COLOR}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${STYLE_RESET}"
echo "${STYLE_BOLD}${RANDOM_COLOR}               STARTING EXECUTION             ${STYLE_RESET}"
echo "${STYLE_BOLD}${RANDOM_COLOR}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${STYLE_RESET}"
echo

get_users_ids() {
    echo "${STYLE_BOLD}${CLR_CYAN}[*] Enter User Information${STYLE_RESET}"
    echo
    read -p "Publisher User  : " PUB_USER
    echo
    read -p "Twin User       : " TWIN_USER
    export PUB_USER
    export TWIN_USER
}

get_users_ids

echo
echo "${STYLE_BOLD}${CLR_BLUE}[1/7] Creating BigQuery Table${STYLE_RESET}"

export PROJECT_ID=$DEVSHELL_PROJECT_ID
export DATASET=demo_dataset
export TABLE=authorized_table

bq query \
--location=US \
--use_legacy_sql=false \
--destination_table=${PROJECT_ID}:${DATASET}.${TABLE} \
--replace \
--nouse_cache \
'SELECT * FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY state_code ORDER BY area_land_meters DESC) AS cities_by_area
  FROM `bigquery-public-data.geo_us_boundaries.zip_codes`
) cities
WHERE cities_by_area <= 10
ORDER BY cities.state_code
LIMIT 1000;' >/dev/null

echo "${STYLE_BOLD}${CLR_CYAN}[2/7] Exporting Dataset Information${STYLE_RESET}"
bq show --format=prettyjson ${PROJECT_ID}:${DATASET} > temp_dataset.json

echo "${STYLE_BOLD}${CLR_YELLOW}[3/7] Updating Dataset Access${STYLE_RESET}"
jq ".access += [
  {
    \"role\": \"READER\",
    \"userByEmail\": \"${PUB_USER}\"
  },
  {
    \"role\": \"READER\",
    \"userByEmail\": \"${TWIN_USER}\"
  }
]" temp_dataset.json > updated_dataset.json

echo "${STYLE_BOLD}${CLR_MAGENTA}[4/7] Applying Dataset Permissions${STYLE_RESET}"
bq update --source=updated_dataset.json ${PROJECT_ID}:${DATASET}

echo "${STYLE_BOLD}${CLR_GREEN}[5/7] Generating IAM Policy${STYLE_RESET}"
cat > policy.json <<EOF
{
  "bindings": [
    {
      "members": [
        "user:${PUB_USER}",
        "user:${TWIN_USER}"
      ],
      "role": "roles/bigquery.dataViewer"
    }
  ]
}
EOF

echo "${STYLE_BOLD}${CLR_RED}[6/7] Applying Table IAM Policy${STYLE_RESET}"
bq set-iam-policy ${PROJECT_ID}:${DATASET}.${TABLE} policy.json

echo
echo "${STYLE_BOLD}${CLR_BLUE}[7/7] Login with the Data Publisher Account${STYLE_RESET}"
echo

cd

remove_files() {
    for file in gsp* arc* shell*; do
        [[ -f "$file" ]] || continue
        rm -f "$file"
        echo "Removed: $file"
    done
}

remove_files</code></pre>
  </li>

  <li>
    When prompted, enter the <b>Publisher Username</b> and the <b>Data Twin Username</b>.
  </li>

  <li>
    Open the <b>Data Publisher</b> project console.
  </li>

  <li>
    Open <b>Cloud Shell</b> and paste the following command:
    <pre><code>#!/bin/bash

CLR_RED=$(tput setaf 1)
CLR_GREEN=$(tput setaf 2)
CLR_YELLOW=$(tput setaf 3)
CLR_BLUE=$(tput setaf 4)
CLR_MAGENTA=$(tput setaf 5)
CLR_CYAN=$(tput setaf 6)

STYLE_BOLD=$(tput bold)
STYLE_RESET=$(tput sgr0)

COLORS=("$CLR_RED" "$CLR_GREEN" "$CLR_YELLOW" "$CLR_BLUE" "$CLR_MAGENTA" "$CLR_CYAN")
RANDOM_COLOR=${COLORS[$((RANDOM % ${#COLORS[@]}))]}

echo "${STYLE_BOLD}${RANDOM_COLOR}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${STYLE_RESET}"
echo "${STYLE_BOLD}${RANDOM_COLOR}              STARTING EXECUTION              ${STYLE_RESET}"
echo "${STYLE_BOLD}${RANDOM_COLOR}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${STYLE_RESET}"
echo

get_value() {
    echo "${STYLE_BOLD}${CLR_CYAN}[*] Enter Required Information${STYLE_RESET}"
    echo
    read -p "Project ID      : " PROJECT_ID
    echo
    read -p "Twin User       : " TWIN_USER
    export PROJECT_ID
    export TWIN_USER
}

get_value

echo
echo "${STYLE_BOLD}${CLR_BLUE}[1/7] Creating Authorized View${STYLE_RESET}"

bq mk \
--use_legacy_sql=false \
--view "SELECT * FROM \`${PROJECT_ID}.demo_dataset.authorized_table\` WHERE state_code = 'NY' LIMIT 1000" \
${DEVSHELL_PROJECT_ID}:data_publisher_dataset.authorized_view

echo "${STYLE_BOLD}${CLR_RED}[2/7] Exporting Dataset Information${STYLE_RESET}"
bq show --format=prettyjson ${DEVSHELL_PROJECT_ID}:data_publisher_dataset > temp_dataset.json

echo "${STYLE_BOLD}${CLR_GREEN}[3/7] Updating Dataset Access${STYLE_RESET}"
jq ".access += [{
  \"view\": {
    \"datasetId\": \"data_publisher_dataset\",
    \"projectId\": \"${DEVSHELL_PROJECT_ID}\",
    \"tableId\": \"authorized_view\"
  }
}]" temp_dataset.json > updated_dataset.json

echo "${STYLE_BOLD}${CLR_CYAN}[4/7] Applying Dataset Permissions${STYLE_RESET}"
bq update --source=updated_dataset.json ${DEVSHELL_PROJECT_ID}:data_publisher_dataset

echo "${STYLE_BOLD}${CLR_YELLOW}[5/7] Generating IAM Policy${STYLE_RESET}"
cat > policy.json <<EOF
{
  "bindings": [
    {
      "members": [
        "user:${TWIN_USER}"
      ],
      "role": "roles/bigquery.dataViewer"
    }
  ]
}
EOF

echo "${STYLE_BOLD}${CLR_MAGENTA}[6/7] Applying IAM Policy to View${STYLE_RESET}"
bq set-iam-policy ${DEVSHELL_PROJECT_ID}:data_publisher_dataset.authorized_view policy.json

echo
echo "${STYLE_BOLD}${CLR_BLUE}[7/7] Login with the Customer (Data Twin) Account${STYLE_RESET}"
echo

remove_files() {
    for file in gsp* arc* shell*; do
        [[ -f "$file" ]] || continue
        rm -f "$file"
        echo "Removed: $file"
    done
}

remove_files</code></pre>
  </li>

  <li>
    When prompted, enter the <b>Project ID</b> from <b>Task 2</b> as shown in <b>Image 1</b>.
  </li>

  <li>
    Enter the <b>Data Twin Username</b> when prompted.
  </li>

  <li>
    Open the <b>Data Twin</b> project console.
  </li>

  <li>
    Open <b>Cloud Shell</b> and paste the following command:
    <pre><code>#!/bin/bash

CLR_RED=$(tput setaf 1)
CLR_GREEN=$(tput setaf 2)
CLR_YELLOW=$(tput setaf 3)
CLR_BLUE=$(tput setaf 4)
CLR_MAGENTA=$(tput setaf 5)
CLR_CYAN=$(tput setaf 6)

STYLE_BOLD=$(tput bold)
STYLE_RESET=$(tput sgr0)

COLORS=("$CLR_RED" "$CLR_GREEN" "$CLR_YELLOW" "$CLR_BLUE" "$CLR_MAGENTA" "$CLR_CYAN")
RANDOM_COLOR=${COLORS[$((RANDOM % ${#COLORS[@]}))]}

echo "${STYLE_BOLD}${RANDOM_COLOR}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${STYLE_RESET}"
echo "${STYLE_BOLD}${RANDOM_COLOR}              STARTING EXECUTION              ${STYLE_RESET}"
echo "${STYLE_BOLD}${RANDOM_COLOR}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${STYLE_RESET}"
echo

get_project_id() {
    echo "${STYLE_BOLD}${CLR_CYAN}[*] Enter Required Information${STYLE_RESET}"
    echo
    read -p "Project ID      : " PROJECT_ID
    export PROJECT_ID
}

get_project_id

echo
echo "${STYLE_BOLD}${CLR_BLUE}[1/1] Creating View in customer_dataset${STYLE_RESET}"

bq mk \
--use_legacy_sql=false \
--view "SELECT cities.zip_code, cities.city, cities.state_code, customers.last_name, customers.first_name
FROM \`${DEVSHELL_PROJECT_ID}.customer_dataset.customer_info\` as customers
JOIN \`${PROJECT_ID}.data_publisher_dataset.authorized_view\` as cities
ON cities.state_code = customers.state" \
${DEVSHELL_PROJECT_ID}:customer_dataset.customer_table

echo

cd

remove_files() {
    for file in gsp* arc* shell*; do
        [[ -f "$file" ]] || continue
        rm -f "$file"
        echo "Removed: $file"
    done
}

remove_files</code></pre>
  </li>

  <li>
    When prompted, enter the <b>Project ID</b> from <b>Task 2</b> as shown in <b>Image 2</b>.
  </li>

</ol>
