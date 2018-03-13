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


/* FUNCTIONS */

//uninstall
// remove DND identity
BOOL uninstall(void);

//init a handler for SIGTERM
// can perform actions such as closing logging
void register4Shutdown(void);

#endif /* main_h */
