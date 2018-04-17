//
//  file: main.h
//  project: DND (launch daemon)
//  description: main interface/entry point for launch daemon (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

/* FUNCTIONS */

//uninstall
// remove DND identity
BOOL uninstall(void);

//init a handler for SIGTERM
// can perform actions such as closing logging
void register4Shutdown(void);

