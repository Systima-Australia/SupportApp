#!/bin/bash

# Download or update Systima assets from GitHub
downloadAssets() {
    # App to update
    repo="$1"
    localDir="/Library/Application Support/Systima/$repo"
    # Set the GitHub repository URL and the local directory path
    github="https://github.com/Systima-Australia/$repo.git"

    # Install Xcode Command Line Tools if not installed
    installxcode() {
        progessDialog "Retrieving critical tools, please wait...\n\nThis may take a few minutes"
        touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
        softwareupdate -l | grep "Label: Command Line Tools" | sed -e 's/^.*Label: //' -e 's/^ *//' | tr -d '\n' | xargs echo | sudo -n -S softwareupdate -i -a
        rm /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
        dialogUpdate "quit:"
    }
    [[ ! $(xcode-select -p) ]] && installxcode

    [[ ! -d "$localDir" ]] && { # Download Assets
        mkdir -p "$localDir"
        git clone "$github" "$localDir"
    } || { # Update Assets
        cd "$localDir"
        git pull
    }
    # Set permissions
    sudo chown root:wheel "$localDir"
    sudo chmod 755 "$localDir"
    sudo chmod -R a+r "$localDir"
}
