#!/bin/bash

localDir="/Library/Application Support/Systima/SupportApp"
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
        --title none \
        --bannerimage "$localDir/images/banner.png" \
        --bannertitle "$1                                " \
        --titlefont "name=Helvetica,colour=#f8f8f2,weight=light,size=40,align=left" \
        --message "$2" \
        --messagefont size=20 \
        --messageposition center \
        --button1text "Submit as Email" \
        --button1action "mailto:support@systima.com.au?subject=$3&body=$4" \
        --button2text "Cancel request" \
        --buttonstyle center \
        --position center \
        --width 800 \
        --height 300 \
        --ontop
}

responseDialog() {
    /usr/local/bin/dialog \
        --title none \
        --bannerimage "$localDir/images/banner.png" \
        --bannertitle "$1                                " \
        --titlefont "name=Helvetica,colour=#f8f8f2,weight=light,size=40,align=left" \
        --message "Ticket Number:<br>### $2<br><br>If urgent assistance is required, please call Systima:<br>### [03 8353 0530](tel:0383530530)" \
        --messagefont "name=Helvetica,weight=light,size=18" \
        --messagealignment center \
        --messageposition top \
        --button1text "OK" \
        --buttonstyle center \
        --ontop
}

getEmailDialog() {
    Username=$(stat -f%Su /dev/console)
    localDir="/Library/Application Support/Systima/SupportApp"
    progressDialogCommand="/var/tmp/dialog.log"
    source "$localDir/.cacheCreds.bash"
    contactEmail=$(defaults read "/Users/$(stat -f%Su /dev/console)/Library/Group Containers/UBF8T346G9.Office/Outlook/Outlook 15 Profiles/Main Profile/ProfilePreferences.plist" DefaultAccountIdentifier | sed 's/_ActiveSyncExchange_HxS//') >/dev/null 2>&1 #; echo "$userEmailaddress"
    emailResponse="$(/usr/local/bin/dialog \
        --title none \
        --bannerimage "$localDir/images/banner.png" \
        --bannertitle "Ticket lookup                                     " \
        --titlefont "name=Helvetica,colour=#f8f8f2,weight=light,size=40,align=left" \
        --infobox "If urgent assistance<br>is required, please<br>call Systima:<br><br>**[&#128222;: 03 8353 0530](tel:0383530530)**" \
        --button1text "Submit" \
        --button2text "Cancel" \
        --buttonstyle center \
        --message "Please enter your email address:" \
        --messagefont size=15 \
        --moveable \
        --height 250 \
        --textfield "Email:",required,value="$contactEmail"
    )"
    returncode=$?
    [[ $returncode -eq 2 ]] && { echo "Email search cancelled by user" && exit 0; }

    contactEmail="$(echo "${emailResponse}" | grep "Email:" | sed 's/Email: : //' )" 
    progessDialog "Verifing contact information..." &
    ATContactQuery=$(ATAPIQuery "Contacts" "{\"filter\":[{\"op\":\"like\",\"field\":\"emailAddress\",\"value\":\"$contactEmail\"},{\"op\":\"eq\",\"field\":\"isActive\",\"value\":1}]}") #; echo "$ATContactQuery"
    ATContact=$(echo "${ATContactQuery//,/\n}" | tr -d ',{}[]()' | sed 's/"items"://') #; echo "$ATContact"
    ATContactID=$(echo "$ATContact" | grep '"id":' | awk -F':' '{print $2}') #; echo "ATContactID:$ATContactID"
    sudo -u $Username defaults write "/Users/$Username/Library/Preferences/profileconfig.plist" ATContactID "$ATContactID"
    dialogUpdate "quit:" # Close the progress dialog
}
