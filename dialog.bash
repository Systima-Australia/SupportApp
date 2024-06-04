#!/bin/bash

progressDialogCommand="/var/tmp/dialog.log"
source "$localDir/.cacheCreds.bash"

dialogUpdate() {
    # $1: dialog command
    local dcommand="$1"
    [[ -n $progressDialogCommand ]] && {
        echo "$dcommand" >> "$progressDialogCommand"
    }
}

progessDialog () {
    /usr/local/bin/dialog \
        --title none \
        --icon "$localDir/images/systima_logo.png" --iconsize 100 -s \
        --dialog \
        --message "$1" \
        --messagefont size=20 \
        --messagealignment center \
        --messageposition center \
        --mini \
        --progress \
        --position centre \
        --movable \
        --commandfile "$progressDialogCommand" \
        --ontop
}

errorDialog() {
    /usr/local/bin/dialog \
        --title "$1" \
        --message "$2" \
        --messagefont size=20 \
        --messagealignment center \
        --messageposition center \
        --bannerimage "$localDir/images/request_failed.png" \
        --button1text "Submit as Email" \
        --button1action "mailto:support@systima.com.au?subject=$3&body=$4" \
        --button2text "Cancel request" \
        --buttonstyle center \
        --position center/centre \
        --ontop
}

responseDialog() {
    /usr/local/bin/dialog \
        --title "Your ticket has been submitted" \
        --textfield "Ticket Number:",value="$1" \
        --message "If urgent assistance is required, please call Systima at 03 8353 0530" \
        --messagefont size=25 \
        --messagealignment center \
        --bannerimage "/Library/Application Support/Systima/SupportApp/images/ticket_submitted.png" \
        --button1text "OK" \
        --buttonstyle center \
        --small \
        --ontop
}

getEmailDialog() {
    contactEmail=$(defaults read "/Users/$(stat -f%Su /dev/console)/Library/Group Containers/UBF8T346G9.Office/Outlook/Outlook 15 Profiles/Main Profile/ProfilePreferences.plist" DefaultAccountIdentifier | sed 's/_ActiveSyncExchange_HxS//') >/dev/null 2>&1 #; echo "$userEmailaddress"
    /usr/local/bin/dialog \
    --title none \
    --message "Please enter your email address:" \
    --messagefont size=15 \
    --infobox "If urgent assistance<br>is required, please<br>call Systima on:<br><br>03 8353 0530" \
    --bannerimage "/Library/Application Support/Systima/SupportApp/images/info_required.png" \
    --button1text "Submit" \
    --button2text "Cancel" \
    --buttonstyle center \
    --position center/centre \
    --ontop \
    --small \
    --height 350 \
    --dialog \
    --textfield "Email:",required,value="$contactEmail"

    contactEmail="$(echo "${emailResponse}" | grep "Email:" | sed 's/Contact Email Address : //')"

    ATContactQuery=$(ATAPIQuery "Contacts" "{\"filter\":[{\"op\":\"like\",\"field\":\"emailAddress\",\"value\":\"$contactEmail\"},{\"op\":\"eq\",\"field\":\"CompanyID\",\"value\":$ATCompanyID}]}") >/dev/null 2>&1
    ATContact=$(echo "${ATContactQuery//,/\n}" | tr -d '{}[]()' | sed 's/"items"://') #echo "$ATContact"
    ATContactID=$(echo "$ATContact" | grep '"id":' | awk -F':' '{print $2}')          #echo "ATContactID:$ATContactID"
    sudo -u $Username defaults write "/Users/$Username/Library/Preferences/profileconfig.plist" ATContactID "$ATContactID"
}
