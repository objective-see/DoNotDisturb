#!/bin/bash

#
#  file: configure.sh
#  project: DND (configure)
#  description: install/uninstall
#
#  created by Patrick Wardle
#  copyright (c) 2017 Objective-See. All rights reserved.
#

INSTALL_DIRECTORY="/Library/Objective-See/DND"

#install
if [ "${1}" == "-install" ]; then

    echo "installing"

    #create DND directory
    mkdir -p $INSTALL_DIRECTORY

    #set permissions
    chown -R root:wheel "Do Not Disturb.bundle"
    chown -R root:wheel "com.objective-see.dnd.plist"

    #install & load launch daemon
    mv "Do Not Disturb.bundle" $INSTALL_DIRECTORY
    mv "com.objective-see.dnd.plist" /Library/LaunchDaemons/
    launchctl load "/Library/LaunchDaemons/com.objective-see.dnd.plist"

    #give launch daemon a second
    # time to initialize, get XPC interface up, etc...
    sleep 1.0

    echo "launch daemon installed and loaded"

    #install main app/helper app
    mv "Do Not Disturb.app" /Applications

    #remove xattrz
    xattr -rc "/Applications/Do Not Disturb.app"

    #first time
    # kick of main app w/ -install & -welcome flag
    if [ ! -f "$INSTALL_DIRECTORY/preferences.plist" ]; then
        open "/Applications/Do Not Disturb.app/" "--args" "-install" "-welcome"

    #otherwise
    # just install (no welcome)
    else
        open -g -j "/Applications/Do Not Disturb.app/" "--args" "-install"
    fi

    #start login item
    open -g -j "/Applications/Do Not Disturb.app/Contents/Library/LoginItems/Do Not Disturb Helper.app"

    echo "install complete"
    exit 0

#uninstall
elif [ "${1}" == "-uninstall" ]; then

    echo "uninstalling"

    #kill main app
    # ...it might be open
    killall "Do Not Disturb" 2> /dev/null

    #full uninstall?
    # tell daemon to perform uninstall logic (delete IDs, etc)
    if [[ "${2}" -eq "1" ]]; then
        "$INSTALL_DIRECTORY/Do Not Disturb.bundle/Contents/MacOS/Do Not Disturb" "-uninstall"
    fi

    #unload launch daemon & remove plist
    launchctl unload /Library/LaunchDaemons/com.objective-see.dnd.plist
    rm /Library/LaunchDaemons/com.objective-see.dnd.plist

    echo "unloaded launch daemon"

    #kick off main app w/ uninstall flag
    open "/Applications/Do Not Disturb.app" "--args" "-uninstall"

    #give it a second
    # time to remove login item, etc
    sleep 1.0

    #uninstall & remove main app/helper app
    rm -rf "/Applications/Do Not Disturb.app"

    #full uninstall?
    # delete DND's folder w/ everything
    if [[ "${2}" -eq "1" ]]; then
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
echo "\nERROR: run w/ '-install' || '-uninstall'"
exit -1
