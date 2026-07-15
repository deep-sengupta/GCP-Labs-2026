#!/bin/bash

HEADER_COLOR=$'\033[38;5;39m'       # Neon Blue
TITLE_COLOR=$'\033[38;5;51m'        # Bright Cyan
PROMPT_COLOR=$'\033[38;5;220m'      # Amber
ACTION_COLOR=$'\033[38;5;87m'       # Aqua
SUCCESS_COLOR=$'\033[38;5;82m'      # Neon Green
WARNING_COLOR=$'\033[38;5;197m'     # Hot Pink
LINK_COLOR=$'\033[38;5;45m'         # Sky Blue
TEXT_COLOR=$'\033[38;5;255m'        # White

NO_COLOR=$'\033[0m'
RESET_FORMAT=$'\033[0m'
BOLD_TEXT=$'\033[1m'
UNDERLINE_TEXT=$'\033[4m'

clear

# Function to display messages with formatting
print_message() {
    local color=$1
    local emoji=$2
    local message=$3
    echo -e "${color}${BOLD_TEXT}${emoji} ${message}${RESET_FORMAT}"
}

# Function to display error messages
print_error() {
    local message=$1
    print_message "$WARNING_COLOR" "❌" "ERROR: ${message}"
}

# Function to display success messages
print_success() {
    local message=$1
    print_message "$SUCCESS_COLOR" "✔" "${message}"
}

# Function to handle errors and exit
handle_error() {
    local exit_code=$1
    local error_message=$2

    if [ $exit_code -ne 0 ]; then
        print_error "$error_message"
        exit $exit_code
    fi
}

# Function to check command existence
check_command() {
    local command=$1
    if ! command -v "$command" &> /dev/null; then
        print_error "$command could not be found. Please install it before continuing."
        exit 1
    fi
}

echo
echo "${HEADER_COLOR}${BOLD_TEXT}☁️  CLOUD STORAGE API LAB${RESET_FORMAT}"
echo "${TEXT_COLOR}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"
echo

# Check for required commands
print_message "$ACTION_COLOR" "🔍" "Checking system requirements..."
check_command "gcloud"
check_command "gsutil"
check_command "curl"
check_command "nano"
print_success "All required commands are available"
echo

# Step 1: Set the region for the project
set_region() {
    print_message "$ACTION_COLOR" "🌍" "Step 1 • Setting the compute region..."

    read -p "${PROMPT_COLOR}${BOLD_TEXT}Enter REGION [us-central1]: ${RESET_FORMAT}" REGION
    REGION=${REGION:-us-central1}

    gcloud config set compute/region $REGION
    handle_error $? "Failed to set compute region"

    print_success "Region set to: $REGION"
    echo
}

# Step 2: Creating JSON File
create_json_file() {
    print_message "$ACTION_COLOR" "📄" "Step 2 • Creating values.json..."

    PROJECT_ID=$(gcloud config get-value project)
    handle_error $? "Failed to get project ID"

    cat > values.json << EOL
{
  "name": "${PROJECT_ID}-bucket",
  "location": "us",
  "storageClass": "multi_regional"
}
EOL
    handle_error $? "Failed to create values.json file"

    print_success "Configuration file created with Project ID: $PROJECT_ID"
    echo

    export PROJECT_ID
}

# Step 3: Ensure API is enabled
enable_api() {
    print_message "$ACTION_COLOR" "⚙️" "Step 3 • Enabling Cloud Storage API..."

    gcloud services enable storage-api.googleapis.com
    handle_error $? "Failed to enable Cloud Storage API"

    print_success "Cloud Storage API is now enabled"
    echo
}

# Step 4: Manual OAuth token generation instructions
oauth_token_instructions() {
    print_message "$ACTION_COLOR" "🔑" "Step 4 • OAuth Token Generation"

    echo
    echo "${TEXT_COLOR}Generate an OAuth access token by following these steps:${RESET_FORMAT}"
    echo
    echo "${PROMPT_COLOR}① Open:${RESET_FORMAT} ${LINK_COLOR}https://developers.google.com/oauthplayground/${RESET_FORMAT}"
    echo "${PROMPT_COLOR}② Select:${RESET_FORMAT} ${BOLD_TEXT}Cloud Storage API V1${RESET_FORMAT}"
    echo "${PROMPT_COLOR}③ Choose scope:${RESET_FORMAT} ${BOLD_TEXT}https://www.googleapis.com/auth/devstorage.full_control${RESET_FORMAT}"
    echo "${PROMPT_COLOR}④ Click ${BOLD_TEXT}Authorize APIs${RESET_FORMAT}"
    echo "${PROMPT_COLOR}⑤ Exchange authorization code for tokens"
    echo "${PROMPT_COLOR}⑥ Copy the ${BOLD_TEXT}Access Token${RESET_FORMAT}"
    echo

    read -p "${PROMPT_COLOR}${BOLD_TEXT}Paste OAuth2 Token: ${RESET_FORMAT}" OAUTH2_TOKEN

    if [ -z "$OAUTH2_TOKEN" ]; then
        print_error "OAuth2 token is required to proceed"
        exit 1
    fi

    export OAUTH2_TOKEN
    print_success "OAuth2 token configured"
    echo
}

# Step 5: Create a bucket using the API
create_bucket() {
    print_message "$ACTION_COLOR" "🪣" "Step 5 • Creating Cloud Storage bucket..."

    if [ -z "$PROJECT_ID" ] || [ -z "$OAUTH2_TOKEN" ]; then
        print_error "Missing required configuration."
        exit 1
    fi

    print_message "$TEXT_COLOR" "🚀" "Sending API request..."

    RESPONSE=$(curl -s -X POST --data-binary @values.json \
        -H "Authorization: Bearer $OAUTH2_TOKEN" \
        -H "Content-Type: application/json" \
        "https://www.googleapis.com/storage/v1/b?project=$PROJECT_ID")

    if echo "$RESPONSE" | grep -q "error"; then
        print_error "Bucket creation failed."
        echo "$RESPONSE"

        if echo "$RESPONSE" | grep -q "bucket name is restricted"; then
            print_message "$PROMPT_COLOR" "🔄" "Bucket name already exists. Generating a new one..."

            RANDOM_SUFFIX=$(date +%s | cut -c 6-10)
            BUCKET_NAME="${PROJECT_ID}-bucket-${RANDOM_SUFFIX}"

            sed -i "s/\"name\": \".*\"/\"name\": \"$BUCKET_NAME\"/" values.json

            RESPONSE=$(curl -s -X POST --data-binary @values.json \
                -H "Authorization: Bearer $OAUTH2_TOKEN" \
                -H "Content-Type: application/json" \
                "https://www.googleapis.com/storage/v1/b?project=$PROJECT_ID")

            if echo "$RESPONSE" | grep -q "error"; then
                print_error "Retry failed."
                echo "$RESPONSE"
                exit 1
            fi
        else
            exit 1
        fi
    fi

    BUCKET_NAME=$(echo "$RESPONSE" | grep -o '"name": *"[^"]*"' | cut -d'"' -f4)
    export BUCKET_NAME

    print_success "Bucket created: $BUCKET_NAME"
    echo
}

# Step 6: Upload a file to the bucket
upload_file() {
    print_message "$ACTION_COLOR" "📤" "Step 6 • Uploading sample image..."

    print_message "$TEXT_COLOR" "🖼️" "Generating demo image..."

    BASE64_IMG="iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVQI12P4//8/AAX+Av7czFnnAAAAAElFTkSuQmCC"

    echo "$BASE64_IMG" | base64 -d > demo-image.png
    handle_error $? "Failed to create sample image"

    OBJECT=$(realpath demo-image.png)
    handle_error $? "Failed to resolve file path"

    if [ -z "$BUCKET_NAME" ] || [ -z "$OAUTH2_TOKEN" ] || [ -z "$OBJECT" ]; then
        print_error "Missing required configuration."
        exit 1
    fi

    print_message "$TEXT_COLOR" "⬆️" "Uploading..."

    RESPONSE=$(curl -s -X POST --data-binary @$OBJECT \
        -H "Authorization: Bearer $OAUTH2_TOKEN" \
        -H "Content-Type: image/png" \
        "https://www.googleapis.com/upload/storage/v1/b/$BUCKET_NAME/o?uploadType=media&name=demo-image")

    if echo "$RESPONSE" | grep -q "error"; then
        print_error "Upload failed."
        echo "$RESPONSE"
        exit 1
    fi

    print_success "Uploaded to gs://$BUCKET_NAME/demo-image"
    echo

    gsutil ls "gs://$BUCKET_NAME/demo-image" &>/dev/null

    if [ $? -eq 0 ]; then
        print_success "Verification successful"
    else
        print_error "Unable to verify uploaded object"
    fi
}

# Main execution function
main() {
    echo "${HEADER_COLOR}${BOLD_TEXT}🚀 Starting Cloud Storage API Lab${RESET_FORMAT}"
    echo "${TEXT_COLOR}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"
    echo

    set_region
    create_json_file
    enable_api
    oauth_token_instructions
    create_bucket
    upload_file

    echo
    echo "${TEXT_COLOR}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_FORMAT}"
    echo "${SUCCESS_COLOR}${BOLD_TEXT}🎉 Lab completed successfully!${RESET_FORMAT}"
    echo
}

main