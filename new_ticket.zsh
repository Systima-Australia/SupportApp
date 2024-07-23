#!/bin/zsh

# Prompt for user empowered New Ticket generation in AutoTask
# Interactive prompts for user input utilizing swiftDialog and AutoTask API

# Script written by Tully Jagoe for Systima 03/05/24
# Not approved for distribution or replication
# This script is only permitted to be deployed to and used by Systima, on Systima managed macOS endpoints

####################################################################################################

# Global variable definitions
export Username=$(stat -f%Su /dev/console)
export repo="SupportApp"
export localDir="/Library/Application Support/Systima/"

# Include subshells for functions
source "/Library/Application Support/Systima/download_assets.bash"
source "$localDir/SupportApp/dialog.bash"
source "$localDir/SupportApp/.cacheCreds.bash"

####################################################################################################

# Confirm all assets are up to date
downloadAssets SupportApp

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

getATFields() {
    # Autotask API credentials
    progessDialog "Retrieving ticket data..."
    
    # Cache the Autotask configurationID against device serial number
    ATConfigItemQuery=$(ATAPIQuery "ConfigurationItems" "{\"filter\":[{\"op\":\"eq\",\"field\":\"serialNumber\",\"value\":\"$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')\"}]}") > /dev/null 2>&1
    ATConfigItem=$(echo "${ATConfigItemQuery//,/\n}" | tr -d '{}[]()' | sed 's/"items"://') ; #echo "$ATConfigItem"
    ATConfigItemID=$(echo "$ATConfigItem" | grep '"id":' | awk -F':' '{print $2}') ; #echo "ATConfigItemID:$ATConfigItemID"
    ATCompanyID=$(echo "$ATConfigItem" | grep '"companyID":' | awk -F':' '{print $2}') ; #echo "ATCompanyID:$ATCompanyID"
    sudo -u $Username defaults write "/Users/$Username/Library/Preferences/profileconfig.plist" ATCompanyID "$ATCompanyID"

    # Check if the companyID is empty, if so, show error message and exit
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
    ATContactQuery=$(ATAPIQuery "Contacts" "{\"filter\":[{\"op\":\"like\",\"field\":\"emailAddress\",\"value\":\"$contactEmail\"},{\"op\":\"eq\",\"field\":\"CompanyID\",\"value\":$ATCompanyID},{\"op\":\"eq\",\"field\":\"isActive\",\"value\":1}]}") > /dev/null 2>&1
    ATContact=$(echo "${ATContactQuery//,/\n}" | tr -d '{}[]()' | sed 's/"items"://') ; #echo "$ATContact"
    ATContactID=$(echo "$ATContact" | grep '"id":' | awk -F':' '{print $2}') ; #echo "ATContactID:$ATContactID"
    sudo -u $Username defaults write "/Users/$Username/Library/Preferences/profileconfig.plist" ATContactID "$ATContactID"
    ATContactMobile=$(echo "$ATContact" | grep '"mobilePhone":' | awk -F':' '{print $2}' | tr -d '"') ; #echo "ATContactMobile:$ATContactMobile"
    ATContactEmail=$(echo "$ATContact" | grep '"emailAddress":' | awk -F':' '{print $2}' | tr -d '"') ; #echo "ATContactEmail:$ATContactEmail"
    dialogUpdate "quit:" # Close the progress dialog
}

ticketDialog() {
    ticketDialog="$(/usr/local/bin/dialog \
        --title none \
        --message none \
        --bannerimage "$localDir/images/banner.png" \
        --bannertitle "New Support Request                            " \
        --titlefont "name=Helvetica,colour=#f8f8f2,weight=light,size=40,align=left"\
        --messagefont size=15 \
        --button1text "Submit" \
        --button2text "Cancel" \
        --infobutton \
        --infobuttontext "How to take a screenshot" \
        --infobuttonaction "https://support.apple.com/en-au/102646" \
        --moveable \
        --height 600 \
        --infobox "If urgent assistance<br>is required, please<br>call Systima:<br><br>**[&#128222;: 03 8353 0530](tel:0383530530)**" \
        --textfield "Contact Name",required,value="$userRealName" \
        --textfield "Contact Email Address",required,value="$ATContactEmail" \
        --textfield "Contact Phone Number",required,value="$ATContactMobile" \
        --textfield "Computer Name",value="$workstation" \
        --textfield "Ticket Title",required,regex=".{1,70}",prompt="70 characters max",regexerror="Ticket Title has a maximum of 70 characters" \
        --textfield "Detailed description",required,value="Please do not include any passwords in your request",editor \
        --textfield "When did the issue start",value="$(date +"%d/%m/%y %H:%M")" \
        --textfield "Attach Screenshot,fileselect",filetype="jpeg jpg png"
        )"

    returncode=$?
    [[ $returncode -eq 2 ]] && { echo "Ticket creation cancelled by user" && exit 0; }

    # Assign each array element to a separate variable
    contactName="$(echo "${ticketDialog}" | grep "Contact Name" | sed 's/Contact Name : //' )" ; #echo "$contactName"
    contactEmail="$(echo "${ticketDialog}" | grep "Contact Email Address" | sed 's/Contact Email Address : //' )" ; echo "Contact email: $contactEmail"
    contactNum="$(echo "${ticketDialog}" | grep "Contact Phone Number" | sed 's/Contact Phone Number : //' )" ; echo "Contact number: $contactNum"
    ticketTitle="$(echo "${ticketDialog}" | grep "Ticket Title" | sed 's/Ticket Title : //' )" ; echo "Ticket Title: $ticketTitle"
    longDesc="$(echo "${ticketDialog}" | grep "Detailed description" | sed 's/Detailed description : //' )" ; echo "Description: $longDesc"
    issueStart="$(echo "${ticketDialog}" | grep "When did the issue start" | sed 's/When did the issue start : //' )" ; echo "Issue start: $issueStart"
}

verifyUserID() {
    progessDialog "Verifing contact information..."
    ATContactQuery=$(ATAPIQuery "Contacts" "{\"filter\":[{\"op\":\"like\",\"field\":\"emailAddress\",\"value\":\"$contactEmail\"},{\"op\":\"eq\",\"field\":\"CompanyID\",\"value\":$ATCompanyID},{\"op\":\"eq\",\"field\":\"isActive\",\"value\":1}]}") > /dev/null 2>&1
    ATContact=$(echo "${ATContactQuery//,/\n}" | tr -d ',{}[]()' | sed 's/"items"://') ; #echo "$ATContact"
    ATContactID=$(echo "$ATContact" | grep '"id":' | awk -F':' '{print $2}') ; echo "ATContactID:$ATContactID"
    dialogUpdate "quit:" # Close the progress dialog
}

generateTicketFields() {
# Create Ticket title
ticketTitle="$ATCompanyName - $workstation - $ticketTitle"

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
    progessDialog "Submitting ticket..."
    # Post the ticket
    ATPostResponse=$(ATAPIPost "{
        \"billingCodeID\": 29683681,
        \"companyID\": \"$ATCompanyID\",
        \"configurationItemID\": \"$ATConfigItemID\",
        \"contractID\": \"$ATContractID\",
        \"contactID\": \"$ATContactID\",
        \"description\": \"$ticketDescription\",
        \"priority\": 1,
        \"QueueID\": 29684341,
        \"source\": -1,
        \"status\": 1,
        \"title\": \"$ticketTitle\" }")

    ATTicket=$(echo -e "${ATPostResponse//,/\n}" | tr -d ',{}[]()' | sed 's/"items"://')
    ATTicketID=$(echo "$ATTicket" | grep '"itemId":' | awk -F':' '{print $2}') ; #echo "ATTicketID:$ATTicketID"
    dialogUpdate "quit:" # Close the progress dialog

    [[ -z "$ATTicketID" ]] && {
        errorDialog "Could not process required support information
Please call Systima on 03 8353 0530
or email support@systima.com.au"
    echo "Could not post to Autotask:\n$ATPostResponse"
    exit 1; }  
}

getATTicketNumber() {
    # Retrieve ticketNumber from ticketID
    ATTicketIDQuery=$(ATAPIQuery "Tickets" "{\"filter\":[{\"op\":\"eq\",\"field\":\"id\",\"value\":\"$ATTicketID\"}]}") > /dev/null 2>&1
    ATTicketID=$(echo "${ATTicketIDQuery//,/\n}" | tr -d ',{}[]()') ; #echo "$ATTicketNumber"
    ATTicketNumber=$(echo "$ATTicketID" | grep '"ticketNumber":' | awk -F':' '{print $2}' | tr -d '"') ; echo "ATTicketNumber:$ATTicketNumber"
}

# Run the script
getWorkstationStats
getATFields
ticketDialog
verifyUserID
generateTicketFields
postATTicket
getATTicketNumber

[[ -n "$ATTicketNumber" ]] &&
    responseDialog "Ticket Submitted" "$ATTicketNumber" || {
    errorDialog "Could not retrieve Ticket Number" \
"Your ticket may have been submitted,
however there was unfortunately no response
when retrieving the Ticket Number.

Please submit your ticket as an email,
or call Systima on 03 8353 0530." \
"$ticketTitle" \
"$ticketDescription"
echo -e "Autotask Ticket Number could not be retrieved. Logs:\n$ATTicketID"
}
