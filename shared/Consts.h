//
//  file: consts.h
//  project: DoNotDisturb (shared)
//  description: #defines and what not
//
//  created by Patrick Wardle
//  copyright (c) 2026 Objective-See. All rights reserved.
//

#ifndef consts_h
#define consts_h

//cs consts
// from: cs_blobs.h
#define CS_VALID 0x00000001
#define CS_ADHOC 0x0000002
#define CS_RUNTIME 0x00010000

//patreon url
#define PATREON_URL @"https://www.patreon.com/join/objective_see"

//bundle ID
#define BUNDLE_ID "com.objective-see.donotdisturb"

//main app bundle id
#define MAIN_APP_ID @"com.objective-see.donotdisturb"

//helper (login item) ID
#define HELPER_ID @"com.objective-see.donotdisturb.helper"

//installer (app) ID
#define INSTALLER_ID @"com.objective-see.donotdisturb.installer"

//installer (helper) ID
#define CONFIG_HELPER_ID @"com.objective-see.donotdisturb.installerHelper"

//signing auth
#define SIGNING_AUTH @"Developer ID Application: Objective-See, LLC (VBG97UB4TA)"

//install directory
#define INSTALL_DIRECTORY @"/Library/Objective-See/DoNotDisturb"

//preferences file
#define PREFS_FILE @"preferences.plist"

//client no status
#define STATUS_CLIENT_UNKNOWN -1

//client disabled
#define STATUS_CLIENT_DISABLED 0

//client enabled
#define STATUS_CLIENT_ENABLED 1

//daemon mach name
#define DAEMON_MACH_SERVICE @"com.objective-see.donotdisturb"

//product version url
#define PRODUCT_VERSIONS_URL @"https://objective-see.org/products.json"

//product url
#define PRODUCT_URL @"https://objective-see.org/products/dnd.html"

//error(s) url
#define ERRORS_URL @"https://objective-see.org/errors.html"

//support us button tag
#define BUTTON_SUPPORT_US 100

//more info button tag
#define BUTTON_MORE_INFO 101

//install cmd
#define CMD_INSTALL @"-install"

//uninstall cmd
#define CMD_UNINSTALL @"-uninstall"

//uninstall via UI
#define CMD_UNINSTALL_VIA_UI @"-uninstallViaUI"

//flag to uninstall
#define ACTION_UNINSTALL_FLAG 0

//flag to install
#define ACTION_INSTALL_FLAG 1

//flag for partial uninstall
// leave preferences file, etc.
#define UNINSTALL_PARTIAL 0

//flag for full uninstall
#define UNINSTALL_FULL 1

//add rule, block
#define BUTTON_BLOCK 0

//add rule, allow
#define BUTTON_ALLOW 1

//prefs
#define PREF_IS_DISABLED @"disabled"
#define PREF_GOT_FDA @"gotFullDiskAccess"

#define PREF_NO_ICON_MODE @"noIconMode"
#define PREF_PASSIVE_MODE @"passiveMode"
#define PREF_APPLE_WATCH_MODE @"appleWatchMode"
#define PREF_TOUCH_ID_MODE @"touchIDMode"

#define PREF_CHAT_ID @"telegramChatID"
#define PREF_BOT_TOKEN @"telegramBotID"
#define PREF_BOT_USERNAME @"telegramBotName"

#define PREF_ALERT_IMAGE_MODE @"includeImage"
#define PREF_NO_REMOTE_ALERTS_MODE @"disableRemoteAlerts"

#define PREF_EXECUTE_PATH @"executePath"
#define PREF_EXECUTE_ACTION @"executeAction"

#define PREF_NO_UPDATE_MODE @"noUpdatesMode"

//general error URL
#define FATAL_ERROR_URL @"https://objective-see.org/errors.html"

//new user/client notification
#define USER_NOTIFICATION @"com.objective-see.donotdisturb.userNotification"

//first time flag
#define INITIAL_LAUNCH @"-initialLaunch"

/* INSTALLER */

//menu: 'about'
#define MENU_ITEM_ABOUT 0

//menu: 'quit'
#define MENU_ITEM_QUIT 1

//menu: 'settings'
#define MENU_ITEM_SETTINGS 2

//product name
#define PRODUCT_NAME @"DoNotDisturb"

//app name
#define APP_NAME @"DoNotDisturb Helper.app"

//launch daemon
#define LAUNCH_DAEMON @"DoNotDisturb.app"

//launch daemon plist
#define LAUNCH_DAEMON_PLIST @"com.objective-see.donotdisturb.plist"

//frame shift
// for status msg to avoid activity indicator
#define FRAME_SHIFT 45

//flag to close
#define ACTION_CLOSE_FLAG -1

//cmdline flag to uninstall
#define ACTION_UNINSTALL @"-uninstall"

//cmdline flag to uninstall
#define ACTION_INSTALL @"-install"

//button title: upgrade
#define ACTION_UPGRADE @"Upgrade"

//button title: close
#define ACTION_CLOSE @"Close"

//button title: next
#define ACTION_NEXT @"Next »"

#define ACTION_SHOW_INFO 3
#define ACTION_SHOW_FDA 4
#define ACTION_SHOW_CONFIGURATION 5
#define ACTION_SHOW_SUPPORT 6

//support us
#define ACTION_SUPPORT 7

//register
#define LSREGISTER @"/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"

/* (HELPER) APP */

//path to open
#define OPEN @"/usr/bin/open"

//keys for rule dictionary
#define RULE_PROCESS_PATH @"processPath"
#define RULE_ACTION @"action"

//keys for alert dictionary
#define ALERT_UUID @"uuid"
#define ALERT_MESSAGE @"message"
#define ALERT_TIMESTAMP @"timestamp"
#define ALERT_ENCRYPTED_FILES @"encryptedFiles"

#define ALERT_AUDIT_TOKEN @"auditToken"
#define ALERT_PROCESS_PID_VERSION @"pidVersion"
#define ALERT_PROCESS_ID @"pid"
#define ALERT_PROCESS_PATH @"path"
#define ALERT_PROCESS_ARGS @"args"
#define ALERT_PROCESS_SCRIPT @"script"
#define ALERT_PROCESS_NAME @"name"
#define ALERT_PROCESS_ANCESTORS @"ancestors"
#define ALERT_PROCESS_SIGNING_INFO @"signingInfo"

//signing info (from ESF)
#define CS_FLAGS @"csFlags"
#define PLATFORM_BINARY @"platformBinary"
#define TEAM_ID @"teamID"
#define SIGNING_ID @"signingID"

#define ALERT_USER @"user"
#define ALERT_ACTION @"action"
#define ALERT_CREATE_RULE @"createRule"

//keys for rules
#define KEY_RULES @"rules"
#define KEY_CS_FLAGS @"csFlags"


//preferences window
#define WINDOW_PREFERENCES 1

//key for stdout output
#define STDOUT @"stdOutput"

//key for stderr output
#define STDERR @"stdError"

//key for exit code
#define EXIT_CODE @"exitCode"

//path to launchctl
#define LAUNCHCTL @"/bin/launchctl"

//path to killall
#define KILL_ALL @"/usr/bin/killall"

enum {
    RULE_NOT_FOUND = -1,
    RULE_BLOCK     =  0,
    RULE_ALLOW     =  1,
};

#endif
