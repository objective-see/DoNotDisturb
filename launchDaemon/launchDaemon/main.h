//
//  main.h
//  launchDaemon
//
//  Created by Patrick Wardle on 2/15/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#ifndef main_h
#define main_h

/* CONSTS */

//sentry crash reporting URL
#define CRASH_REPORTING_URL @"https://b6e82fd3037642edbc63b1ded9be53d3:87738f112d454de5a89a9864aae73b23@sentry.io/289135"

/* FUNCTIONS */

//uninstall
// remove DND identity
BOOL uninstall(void);

//TODO:
//init sentry
// crash/error reporting
BOOL initCrashReporting(void);

//init a handler for SIGTERM
// can perform actions such as closing logging
void register4Shutdown(void);

#endif /* main_h */
