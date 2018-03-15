//
//  file: Const.h
//  project: DnD (shared)
//  description: #defines and what not
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#ifndef Const_h
#define Const_h

//app name
#define APP_NAME @"Do Not Disturb.app"

//vendor id string
#define OBJECTIVE_SEE_VENDOR "com.objectiveSee"

//installer (helper) ID
#define INSTALLER_HELPER_ID @"com.objective-see.dnd.installer.helper"

//main app bundle id
#define MAIN_APP_ID @"com.objective-see.dnd"

//login helper ID
#define HELPER_ID @"com.objective-see.dnd.helper"

//launch daemon name
#define LAUNCH_DAEMON_BINARY @"Do Not Disturb"

//launch daemon plist
#define LAUNCH_DAEMON_PLIST @"com.objective-see.dnd.plist"

//installer (app) ID
#define INSTALLER_ID @"com.objective-see.dnd.installer"

//signing auth
#define SIGNING_AUTH @"Developer ID Application: Objective-See, LLC (VBG97UB4TA)"

//sentry crash reporting URL
#define CRASH_REPORTING_URL @"https://b6e82fd3037642edbc63b1ded9be53d3:87738f112d454de5a89a9864aae73b23@sentry.io/289135"

//print macros
#ifndef NDEBUG
# define DEBUG_PRINT(x) printf x
#else
# define DEBUG_PRINT(x) do {} while (0)
#endif


//action to install
// also button title
#define ACTION_INSTALL @"Install"

//action to uninstall
// also button title
#define ACTION_UNINSTALL @"Uninstall"

//button title
// close
#define ACTION_CLOSE @"Close"

//button title
// next
#define ACTION_NEXT @"Next »"

//button title
// no
#define ACTION_NO @"No"

//button title
// yes
#define ACTION_YES @"Yes!"

//frame shift
// for status msg to avoid activity indicator
#define FRAME_SHIFT 45

//flag to close
#define ACTION_CLOSE_FLAG -1

//flag to uninstall
#define ACTION_UNINSTALL_FLAG 0

//flag to install
#define ACTION_INSTALL_FLAG 1

//flag for partial uninstall
// leave preferences file, etc.
#define UNINSTALL_PARTIAL 0

//flag for full uninstall
#define UNINSTALL_FULL 1

//path to pkill
#define PKILL @"/usr/bin/pkill"

//path to xattr
#define XATTR @"/usr/bin/xattr"

//path to log
#define LOG @"/usr/bin/log"

//path to open
#define OPEN @"/usr/bin/open"

//apps folder
#define APPS_FOLDER @"/Applications"

//console
#define PATH_CONSOLE "/dev/console"

//install directory
#define INSTALL_DIRECTORY @"/Library/Objective-See/DND"

//preferences file
#define PREFS_FILE @"preferences.plist"

//client no status
#define STATUS_CLIENT_UNKNOWN -1

//client disabled
#define STATUS_CLIENT_DISABLED 0

//client enabled
#define STATUS_CLIENT_ENABLED 1

//daemon mach name
#define DAEMON_MACH_SERVICE @"com.objective-see.dndDaemon"

//product url
#define PRODUCT_URL @"https://objective-see.com/products/dnd.html"

//support us button tag
#define BUTTON_SUPPORT_US 100

//more info button tag
#define BUTTON_MORE_INFO 101

//cancel button
#define BUTTON_CANCEL 100

//config button
#define BUTTON_CONFIG 101

//patreon url
#define PATREON_URL @"https://www.patreon.com/bePatron?c=701171"

//product version url
#define PRODUCT_VERSIONS_URL @"https://objective-see.com/products.json"

//flag to uninstall
#define ACTION_UNINSTALL_FLAG 0

//flag to install
#define ACTION_INSTALL_FLAG 1

//login item name
#define LOGIN_ITEM_NAME @"Do Not Disturb Helper"

//client ID
#define PREF_CLIENT_ID @"clientID"

//registered device name
#define PREF_REGISTERED_DEVICES @"registeredDevices"

//prefs
// status
#define PREF_IS_DISABLED @"disabled"

//prefs
// passive mode
#define PREF_PASSIVE_MODE @"passiveMode"

//prefs
// icon mode
#define PREF_NO_ICON_MODE @"iconMode"

//prefs
// touchID mode
#define PREF_TOUCHID_MODE @"touchIDMode"

//pref
// execute action
#define PREF_EXECUTE_ACTION @"executeAction"

//pref
// execution path
#define PREF_EXECUTION_PATH @"executePath"

//pref
// monitor stuffz
#define PREF_MONITOR_ACTION @"monitorAction"

//prefs
// update mode
#define PREF_NO_UPDATES_MODE @"noupdatesMode"

//log file
#define LOG_FILE_NAME @"DND.log"

//alert key
// timestamp
#define ALERT_TIMESTAMP @"timestamp"

//key for device name
#define KEY_DEVICE_NAME @"deviceName"

//key for host name
#define KEY_HOST_NAME @"hostName"

/* LOGIN ITEM */

//command line install
#define CMDLINE_FLAG_INSTALL @"-install"

//welcome flag
#define CMDLINE_FLAG_WELCOME @"-welcome"

//command line uninstall
#define CMDLINE_FLAG_UNINSTALL @"-uninstall"

//signature status
#define KEY_SIGNATURE_STATUS @"signatureStatus"

//signing auths
#define KEY_SIGNING_AUTHORITIES @"signingAuthorities"

//file belongs to apple?
#define KEY_SIGNING_IS_APPLE @"signedByApple"

//file signed with apple dev id
#define KEY_SIGNING_IS_APPLE_DEV_ID @"signedWithDevID"

//from app store
#define KEY_SIGNING_IS_APP_STORE @"fromAppStore"

//error URL
#define KEY_ERROR_URL @"errorURL"

//flag for error popup
#define KEY_ERROR_SHOULD_EXIT @"shouldExit"

//general error URL
#define FATAL_ERROR_URL @"https://objective-see.com/errors.html"

//key for stdout output
#define STDOUT @"stdOutput"

//key for stderr output
#define STDERR @"stdError"

//key for exit code
#define EXIT_CODE @"exitCode"

//key for error msg
#define KEY_ERROR_MSG @"errorMsg"

//key for error sub msg
#define KEY_ERROR_SUB_MSG @"errorSubMsg"

//passphrase for CSR
// no, this isn't sensitive
#define CSR_PASSPHRASE @"csr"

//0st sync view
#define SYNC_VIEW_ZERO 0

//1st sync view
#define SYNC_VIEW_ONE 1

//2nd sync view
#define SYNC_VIEW_TWO 2

//3rd sync view
#define SYNC_VIEW_THREE 3

//key for QRC dictionary
#define KEY_PHONE_NUMBER @"phone#"

//auth event notification
#define AUTH_NOTIFICATION @"com.objective-see.dnd.authNotification"

//dismiss event notification
#define DISMISS_NOTIFICATION @"com.objective-see.dnd.dismissNotification"

//monitoring timeout
#define MONITORING_TIMEOUT 60

#endif

