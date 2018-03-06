#!/bin/bash

#
#  file: configure.sh
#  project: DnD (configure)
#  description: install/uninstall
#
#  created by Patrick Wardle
#  copyright (c) 2017 Objective-See. All rights reserved.
#

INSTALL_DIRECTORY="/Library/Objective-See/DnD"

#install
if [ "${1}" == "-install" ] && ! [ -z "${2}" ]; then
    echo "installing"

    #main DnD directory
    mkdir -p $INSTALL_DIRECTORY

    #set permissions
    chown -R root:wheel "Do Not Disturb"
    chown -R root:wheel "com.objective-see.dnd.plist"

    #install & load launch daemon
    mv "Do Not Disturb.bundle" $INSTALL_DIRECTORY
    mv com.objective-see.dnd.plist /Library/LaunchDaemons/
    launchctl load /Library/LaunchDaemons/com.objective-see.dnd.plist

    echo "launch daemon installed and loaded"

    #install main app/helper app
    mv "Do Not Disturb.app" /Applications

    #kick off main app w/ install flag as user
    launchctl asuser "${2}" "/Applications/Do Not Disturb.app/Contents/MacOS/Do Not Disturb" "-install"

    echo "install complete"
    exit 0

#uninstall
elif [ "${1}" == "-uninstall" ] && ! [ -z "${2}" ]; then

    echo "uninstalling"

    #tell daemon to perform uninstall logic
    "$INSTALL_DIRECTORY/Do Not Disturb.bundle/Contents/MacOS/Do Not Disturb" "-uninstall"

    #unload launch daemon & remove plist
    launchctl unload /Library/LaunchDaemons/com.objective-see.dnd.plist
    rm /Library/LaunchDaemons/com.objective-see.dnd.plist

    echo "unloaded launch daemon"

    #kick off main app w/ uninstall flag as user
    launchctl asuser "${2}" "/Applications/Do Not Disturb.app/Contents/MacOS/Do Not Disturb" "-uninstall"

    #uninstall & remove main app/helper app
    rm -rf "/Applications/Do Not Disturb.app"

    #full?
    # delete DnD's folder w/ everything
    if [[ "${3}" -eq "1" ]]; then
        rm -rf $INSTALL_DIRECTORY

    #partial
    # just delete daemon
    else
        rm -rf "$INSTALL_DIRECTORY/Do Not Disturb.bundle"
    fi

    #kill
    killall "Do Not Disturb" 2> /dev/null
    killall "com.objective-see.dnd.helper" 2> /dev/null
    killall "Do Not Disturb Helper" 2> /dev/null

    echo "uninstall complete"
    exit 0
fi

#invalid args
echo "\nERROR: run w/ '-install' || '-uninstall' || '-upgrade' + [uid]\n"
exit -1
