#!/bin/zsh

# Script stored at /Library/Application Support/Systima/new_ticket.bash
# This script is called by the SupportApp.app to create a new ticket in Autotask
# Embed the command "sudo bash "/Library/Application Support/Systima/scripts/new_ticket.bash"" in the SupportApp.app config file

Username=$(stat -f%Su /dev/console)
autotaskURL="https://webservices6.autotask.net/atservicesrest/v1.0"
progressDialogCommand="/var/tmp/dialog.log"

progessDialog () {
    /usr/local/bin/dialog \
        --title none \
        --icon "/Library/Application Support/Systima/systima_logo.png" --iconsize 100 -s \
        --message "$1" \
        --messagefont size=20 \
        --messagealignment center \
        --messageposition center \
        --mini \
        --progress 100 \
        --position center/centre \
        --movable \
        --commandfile "$progressDialogCommand"
}

errorDialog() {
    /usr/local/bin/dialog \
        --title "Error loading Ticket system" \
        --message "$1" \
        --messagefont size=20 \
        --messagealignment center \
        --messageposition center \
        --bannerimage "/Library/Application Support/Systima/support_request_banner.png" \
        --button1text "OK" \
        --buttonstyle center \
        --position center/centre \
        --ontop
}

dialogUpdate() {
    # $1: dialog command
    local dcommand="$1"
    [[ -n $progressDialogCommand ]] && {
        echo "$dcommand" >> "$progressDialogCommand"
    }
}

getWorkstationStats() {
    # Workstation information
    workstation=$(hostname) #; echo "$workstation"
    modelName=$(system_profiler SPHardwareDataType | grep -E "Model Name:" | awk '{$1=""; $2=""; print}' | sed 's/^[[:space:]]*//') #; echo "$modelName"
    modeID=$(system_profiler SPHardwareDataType | grep -E "Model Identifier:" | awk '{$1=""; $2=""; print}' | sed 's/^[[:space:]]*//') #; echo "$modelID"
    serialNumber=$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}') #; echo "$serialNumber"
    macOSVersion=$(sw_vers -productVersion) #; echo "$macOSVersion"

    # User information
    userRealName=$(dscl . -read /Users/$Username RealName | grep -v "RealName" | sed 's/^[[:space:]]*//') #; echo "$userRealName"
    contactEmail=$(defaults read "/Users/$Username/Library/Group Containers/UBF8T346G9.Office/Outlook/Outlook 15 Profiles/Main Profile/ProfilePreferences.plist" DefaultAccountIdentifier | sed 's/_ActiveSyncExchange_HxS//') > /dev/null 2>&1 #; echo "$userEmailaddress"
    
    # RAM
    RAMtotal="$(system_profiler SPHardwareDataType| grep "Memory:" | awk '{print $2}' | sed 's/GB//')" #; echo "$RAMtotal"
    RAMused="$(top -l 1 | grep -E "^Phys" | awk '{print $2}'| sed 's/M//' | awk '{printf "%.2f", $1/1024}')" #; echo "$RAMused"

    # CPU
    CPU="$(sysctl -n machdep.cpu.brand_string)" #; echo "$CPU"
    [[ $CPU == *"Intel"* ]] && CPU="$(echo "$CPU" | sed 's/(R) Core(TM)//g' | sed 's/-[^@]*@//g')" #; echo "$CPU"

    # SSD information
    SSDdevice=$(diskutil info / | grep "Device Identifier:" | awk -F': ' '{print $2}' | sed 's/ //g') #; echo "$SSDdevice"
    SSDtotal=$(diskutil info "$SSDdevice" | grep "Disk Size:" | awk '{print $3, $4}' | sed 's/ //g') #; echo "$SSDtotal"
    [[ $SSDtotal == *TB ]] && SSDtotal=${SSDtotal//TB/} && SSDtotal=$(echo "$SSDtotal * 1024" | bc) || SSDtotal=${SSDtotal//GB/}; SSDtotal=$(echo "$SSDtotal" | awk '{printf "%.0f", $1}') #; echo "$SSDtotal"
    SSDused=$(df -gl | grep -E "/System/Volumes/Update/mnt1|/System/Volumes/Data" | awk '{sum += $3} END {print sum}') #; echo "$SSDused"
    #SSDfree=$(echo "scale=1; $SSDtotal - $SSDused" | bc) #; echo "$SSDfree"

    # Uptime
    uptime=$(uptime | awk -F' up ' '{if ($2 ~ /days/) {split($2, a, " "); print a[1]} else if ($2 ~ /mins/ || $2 == "") print "0"; else {split($1, a, ":"); if (length(a) == 2 && a[1] < 24) print "0"; else print int(a[1] / 24)}}') #; echo "$uptime"
    # Battery
    batteryCondition=$(system_profiler SPPowerDataType | grep -i "condition" | sed -e 's/^[[:space:]]*//' -e 's/Condition: //') #; echo "$batteryCondition"
}

cacheATCreds() {
    # Autotask API credentials
    progessDialog "Retrieving ticket data..." &
    credsFile='/var/root/.creds.plist' > /dev/null 2>&1
    autotaskURL="https://webservices6.autotask.net/atservicesrest/v1.0"
    ATAPIIntCode=$(defaults read "$credsFile" ATAPIIntCode) > /dev/null 2>&1
    ATAPIUsername=$(defaults read "$credsFile" ATAPIUsername) > /dev/null 2>&1
    ATAPISecretKey=$(defaults read "$credsFile" ATAPISecretKey) > /dev/null 2>&1
    ATAPIQuery() { curl -sSL --globoff "$autotaskURL/$1/query?search=$2" -H "ApiIntegrationCode: $ATAPIIntCode" -H "UserName: $ATAPIUsername" -H "Secret: $ATAPISecretKey" -H "Content-Type: application/json"; }
    
    # Cache the Autotask configurationID against device serial number
    ATConfigItemQuery=$(ATAPIQuery "ConfigurationItems" "{\"filter\":[{\"op\":\"eq\",\"field\":\"serialNumber\",\"value\":\"$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')\"}]}") > /dev/null 2>&1
    ATConfigItem=$(echo "${ATConfigItemQuery//,/\n}" | tr -d '{}[]()' | sed 's/"items"://') ; #echo "$ATConfigItem"
    ATConfigItemID=$(echo "$ATConfigItem" | grep '"id":' | awk -F':' '{print $2}') ; #echo "ATConfigItemID:$ATConfigItemID"
    ATCompanyID=$(echo "$ATConfigItem" | grep '"companyID":' | awk -F':' '{print $2}') ; #echo "ATCompanyID:$ATCompanyID"

    [[ -z "$ATCompanyID" ]] &&  { dialogUpdate "quit:" ; errorDialog "There was an issue loading the ticket submission API, please call Systima on 03 8353 0530 or email support@systima.com.au"; echo -e "companyID not detected. Logs:\n$ATConfigItem" && exit 1; }

    # Get the Client name and web address based off the companyID
    ATClientQuery=$(ATAPIQuery "Companies" "{\"filter\":[{\"op\":\"eq\",\"field\":\"id\",\"value\":\"$ATCompanyID\"}]}") > /dev/null 2>&1
    ATClient=$(echo "${ATClientQuery//,/\n}" | tr -d '{}[]()' | sed 's/"items"://') ; #echo "$ATClient"
    ATCompanyName=$(echo "$ATClient" | grep '"companyName":' | awk -F':' '{print $2}' | tr -d '"') ; #echo "ATCompanyName:$ATCompanyName"

    # Cache the Autotask contact for the client
    ATContractQuery=$(ATAPIQuery "Contracts" "{\"filter\":[{\"op\":\"eq\",\"field\":\"isDefaultContract\",\"value\":true},{\"op\":\"eq\",\"field\":\"status\",\"value\":1},{\"op\":\"eq\",\"field\":\"companyID\",\"value\":$ATCompanyID}]}") > /dev/null 2>&1
    ATContract=$(echo "${ATContractQuery//,/\n}" | tr -d '{}[]()' | sed 's/"items"://') ; #echo "$ATContract"
    ATContractID=$(echo "$ATContract" | grep '"id":' | awk -F':' '{print $2}') ; #echo "ATContractID:$ATContractID"

    # Cache the Autotask user contactID against requesting users email address
    ATContactQuery=$(ATAPIQuery "Contacts" "{\"filter\":[{\"op\":\"like\",\"field\":\"emailAddress\",\"value\":\"$contactEmail\"},{\"op\":\"eq\",\"field\":\"CompanyID\",\"value\":$ATCompanyID}]}") > /dev/null 2>&1
    ATContact=$(echo "${ATContactQuery//,/\n}" | tr -d '{}[]()' | sed 's/"items"://') ; #echo "$ATContact"
    ATContactID=$(echo "$ATContact" | grep '"id":' | awk -F':' '{print $2}') ; #echo "ATContactID:$ATContactID"
    ATContactMobile=$(echo "$ATContact" | grep '"mobilePhone":' | awk -F':' '{print $2}' | tr -d '"') ; #echo "ATContactMobile:$ATContactMobile"
    ATContactEmail=$(echo "$ATContact" | grep '"emailAddress":' | awk -F':' '{print $2}' | tr -d '"') ; #echo "ATContactEmail:$ATContactEmail"
    dialogUpdate "quit:"
}

swiftDialogTicket() {
    # Start swiftDialog
    ticketDialog="$(/usr/local/bin/dialog \
        --title none \
        --message "If urgent assistance is required, please call Systima at 03 8353 0530" \
        --messagefont size=15 \
        --bannerimage "/Library/Application Support/Systima/support_request_banner.png" \
        --button1text "Submit" \
        --button2text "Cancel" \
        --buttonstyle center \
        --position center/centre \
        --ontop \
        --height 600 \
        --dialog \
        --textfield "Contact Name",required,value="$userRealName" \
        --textfield "Contact Email Address",required,value="$ATContactEmail" \
        --textfield "Contact Phone Number",required,value="$ATContactMobile" \
        --textfield "Computer Name",value="$workstation" \
        --textfield "Ticket Title",required \
        --textfield "Detailed description",required,editor \
        --textfield "When did the issue start",value="$(date +"%d/%m/%y %H:%M")"
    )"

    returncode=$?

    [[ $returncode -eq 2 ]] && { echo "Ticket creation cancelled" && exit 0; }
    
    # Split the output into an array
    #IFS=':' read -r -a textfield_values <<< "$ticketDialog"

    # Assign each array element to a separate variable
    contactName="$(echo "${ticketDialog}" | grep "Contact Name" | sed 's/Contact Name : //' )" ; #echo "$contactName"
    contactEmail="$(echo "${ticketDialog}" | grep "Contact Email Address" | sed 's/Contact Email Address : //' )" ; echo "Contact email: $contactEmail"
    contactNum="$(echo "${ticketDialog}" | grep "Contact Phone Number" | sed 's/Contact Phone Number : //' )" ; echo "Contact number: $contactNum"
    ticketTitle="$(echo "${ticketDialog}" | grep "Ticket Title" | sed 's/Ticket Title : //' )" ; echo "Ticket Title: $ticketTitle"
    longDesc="$(echo "${ticketDialog}" | grep "Detailed description" | sed 's/Detailed description : //' )" ; echo "Description: $longDesc"
    issueStart="$(echo "${ticketDialog}" | grep "When did the issue start" | sed 's/When did the issue start : //' )" ; echo "Issue start: $issueStart"
}

reverifyUserID() {
progessDialog "Verifing contact information..." &
ATContactQuery=$(ATAPIQuery "Contacts" "{\"filter\":[{\"op\":\"like\",\"field\":\"emailAddress\",\"value\":\"$contactEmail\"},{\"op\":\"eq\",\"field\":\"CompanyID\",\"value\":$ATCompanyID}]}") > /dev/null 2>&1
ATContact=$(echo "${ATContactQuery//,/\n}" | tr -d ',{}[]()' | sed 's/"items"://') ; #echo "$ATContact"
ATContactID=$(echo "$ATContact" | grep '"id":' | awk -F':' '{print $2}') ; echo "ATContactID:$ATContactID"
dialogUpdate "quit:"
}

generateTicketFields() {
# Create Ticket title
ticketTitle="$workstation - $ticketTitle"

# Create Ticket Description
ticketDescription="Client: $ATCompanyName
Ticket Contact: $contactName
Username: $Username
Email: $contactEmail
Contact Number: $contactNum

Issue description:
$longDesc



When did the issue start:
$issueStart

Workstation information:
$workstation
$serialNumber
$modelName
macOS Version: $macOSVersion
CPU: $CPU
Ram Pressure: $RAMused / $RAMtotal Gb, $(echo "scale=1; $RAMused * 100 / $RAMtotal" | bc)%
Storage used: $SSDused / $SSDtotal Gb, $(echo "scale=1; $SSDused * 100 / $SSDtotal" | bc)%
Uptime: $uptime days
Battery Condition: $batteryCondition"
#echo "Ticket Description: $ticketDescription"
}

postATTicket() {
    progessDialog "Submitting ticket..." &
    # Post the ticket
    ATAPIPost() { curl -sL --globoff "$autotaskURL/$1" -H "ATAPIIntCode: $ATAPIIntCode" -H "UserName: $ATAPIUsername" -H "Secret: $ATAPISecretKey" -H "Content-Type: application/json" --data "$2";}
    ticketResponse=$(ATAPIPost "Tickets" "{
        \"companyID\": \"$ATCompanyID\",
        \"configurationItemID\": \"$ATConfigItemID\",
        \"contractID\": \"$ATContractID\",
        \"contactID\": \"$ATContactID\",
        \"description\": \"$ticketDescription\",
        \"priority\": 1,
        \"QueueID\": 29684341,
        \"source\": -1,
        \"status\": 1,
        \"title\": \"$ticketTitle\"
    }")
ATTicket=$(echo -e "${ticketResponse//,/\n}" | tr -d ',{}[]()' | sed 's/"items"://')
ATTicketID=$(echo "$ATTicket" | grep '"itemId":' | awk -F':' '{print $2}') ; #echo "ATTicketID:$ATTicketID"
dialogUpdate "quit:"
[[ -z "$ATTicketID" ]] && { errorDialog "Could not process required support information\nPlease call Systima on 03 8353 0530\nor email support@systima.com.au"; echo "Could not post to Autotask:\n$ticketResponse" && exit 1; }  
}

getATTicket() {
# Retrieve ticketNumber from ticketID
    ATTicketIDQuery=$(ATAPIQuery "Tickets" "{\"filter\":[{\"op\":\"eq\",\"field\":\"id\",\"value\":\"$ATTicketID\"}]}") > /dev/null 2>&1
    ATTicketID=$(echo "${ATTicketIDQuery//,/\n}" | tr -d ',{}[]()') ; #echo "$ATTicketNumber"
    ATTicketNumber=$(echo "$ATTicketID" | grep '"ticketNumber":' | awk -F':' '{print $2}' | tr -d '"') ; echo "ATTicketNumber:$ATTicketNumber"
}

responseDialog() {
# Start responseDialog
/usr/local/bin/dialog \
    --title "Your ticket has been submitted" \
    --message "Your ticket number is:\n**\n\n$ATTicketNumber\n\n**\n\nIf urgent assistance is required, please call Systima at 03 8353 0530" \
    --messagefont size=15 \
    --messagealignment center \
    --bannerimage "/Library/Application Support/Systima/support_request_banner.png" \
    --button1text "OK" \
    --buttonstyle center \
    --position center/centre \
    --ontop
}

# Run the script
#curlSystimaAssets
getWorkstationStats
cacheATCreds
swiftDialogTicket
reverifyUserID
generateTicketFields
postATTicket
getATTicket
[[ -n "$ATTicketNumber" ]] && responseDialog || { errorDialog "Apologies, there was an error when submitting your ticket\nPlease call Systima on 03 8353 0530\nor email support@systima.com.au"; echo -e "Autotask Ticket Number not returned. Logs:\n$ATTicketID" ; }
