//
//  file: PrefsWindowController.h
//  project: DoNotDisturb (main app)
//  description: preferences window controller (header)
//
//  created by Patrick Wardle
//  copyright (c) 2026 Objective-See. All rights reserved.
//

@import CoreImage;

#import "consts.h"
#import "Update.h"
#import "utilities.h"
#import "AppDelegate.h"
#import "PrefsWindowController.h"
#import "UpdateWindowController.h"

typedef NS_ENUM(NSInteger, TelegramState) {
    TelegramStateUnconfigured,  // no token
    TelegramStateActivating,    // token valid, no chat ID yet
    TelegramStateConnected,     // fully connected
};

static const CGFloat kToolbarHeight = 50.0;
static const CGFloat kToolbarPadding = 10.0;


/* GLOBALS */

//log handle
extern os_log_t logHandle;

//xpc daemon
extern XPCDaemonClient* xpcDaemonClient;

@implementation PrefsWindowController

@synthesize toolbar;
@synthesize modesView;
@synthesize alertsView;
@synthesize updateView;
@synthesize updateWindowController;

//preferences' buttons
#define BUTTON_NO_ICON_MODE 1
#define BUTTON_PASSIVE_MODE 2
#define BUTTON_TOUCH_ID_MODE 3
#define BUTTON_ALERT_IMAGE_MODE 4
#define BUTTON_NO_REMOTE_ALERTS_MODE 5
#define BUTTON_EXECUTE_ACTION 6
#define BUTTON_NO_UPDATE_MODE 7
#define BUTTON_APPLE_WATCH_MODE 8

//init 'general' view
// add it, and make it selected
-(void)awakeFromNib
{
    //set title
    self.window.title = APP_NAME;
    if(@available(macOS 11.0, *)) {
        self.window.subtitle = @"Application Settings";
    }
    
    //get prefs
    self.preferences = [xpcDaemonClient getPreferences];
    
    //set modes prefs as default
    [self toolbarButtonHandler:nil];
    
    //set modes prefs as default
    [self.toolbar setSelectedItemIdentifier:TOOLBAR_MODES_ID];
    
    //init telegram object
    self.telegram = [[Telegram alloc] init];
    
    //set UI
    [self updateTelegramUI];
    
}

//toolbar view handler
// toggle view based on user selection
-(IBAction)toolbarButtonHandler:(id)sender
{
    //dbg msg
    os_log_debug(logHandle, "%s invoked with %{public}@", __PRETTY_FUNCTION__, sender);
    
    [self showToolbarView:((NSToolbarItem*)sender).tag];
    
    return;
}

//show toolbar view for specified tag
-(void)showToolbarView:(NSInteger)tag
{
    //view
    NSView* view = nil;
    
    //dbg msg
    os_log_debug(logHandle, "%s invoked with tag: %ld", __PRETTY_FUNCTION__, (long)tag);
    
    //when we've prev added a view
    // remove the prev view cuz adding a new one
    if(YES == self.viewWasAdded)
    {
        //dbg msg
        os_log_debug(logHandle, "removing previous view...");
        
        //remove
        [[[self.window.contentView subviews] lastObject] removeFromSuperview];
    }
    
    //assign view
    switch(tag)
    {
            //modes
        case TOOLBAR_MODES:
            
            view = self.modesView;
            
            ((NSButton*)[view viewWithTag:BUTTON_NO_ICON_MODE]).state = [self.preferences[PREF_NO_ICON_MODE] boolValue];
            ((NSButton*)[view viewWithTag:BUTTON_APPLE_WATCH_MODE]).state = [self.preferences[PREF_APPLE_WATCH_MODE] boolValue];
            ((NSButton*)[view viewWithTag:BUTTON_TOUCH_ID_MODE]).state = [self.preferences[PREF_TOUCH_ID_MODE] boolValue];
            
            break;
            
            //alerts
        case TOOLBAR_ALERTS:
            
            view = self.alertsView;
            
            //disabled?
            if([self.preferences[PREF_NO_REMOTE_ALERTS_MODE] boolValue]) {
                [self setTelegramState:TelegramStateUnconfigured];
                
                //disable
                self.telegramBotToken.enabled = NO;
                ((NSButton*)[view viewWithTag:BUTTON_ALERT_IMAGE_MODE]).enabled = NO;
                
                
            }
            //enabled
            else {
                
                //enable
                self.telegramBotToken.enabled = YES;
                ((NSButton*)[view viewWithTag:BUTTON_ALERT_IMAGE_MODE]).enabled = YES;
                
                [self updateTelegramUI];
            }
            
            //set buttons
            ((NSButton*)[view viewWithTag:BUTTON_ALERT_IMAGE_MODE]).state = [self.preferences[PREF_ALERT_IMAGE_MODE] boolValue];
            ((NSButton*)[view viewWithTag:BUTTON_NO_REMOTE_ALERTS_MODE]).state = [self.preferences[PREF_NO_REMOTE_ALERTS_MODE] boolValue];
            
            break;
            
            //actions
        case TOOLBAR_ACTIONS:
            
            view = self.actionsView;
            
            ((NSButton*)[view viewWithTag:BUTTON_EXECUTE_ACTION]).state = [self.preferences[PREF_EXECUTE_ACTION] boolValue];
            if(self.preferences[PREF_EXECUTE_PATH]) {
                self.executePath.stringValue = self.preferences[PREF_EXECUTE_PATH];
            }
            
            //set state of 'execute action' to match
            self.executePath.enabled = [self.preferences[PREF_EXECUTE_ACTION] boolValue];
            
            break;
            
            //updates
        case TOOLBAR_UPDATES:
            
            view = self.updateView;
            ((NSButton*)[view viewWithTag:BUTTON_NO_UPDATE_MODE]).state = [self.preferences[PREF_NO_UPDATE_MODE] boolValue];
            
            break;
            
        default:
            return;
    }
    
    //resize window to fit the view's height (keeping top edge fixed)
    NSRect windowFrame = self.window.frame;
    CGFloat newHeight = view.frame.size.height + kToolbarHeight + kToolbarPadding;
    CGFloat newWidth = view.frame.size.width;
    CGFloat deltaY = NSMaxY(windowFrame) - newHeight;
    [self.window setFrame:NSMakeRect(windowFrame.origin.x, deltaY, newWidth, newHeight) display:YES];
    
    //position view so its top aligns with the window's contentView top
    NSView* container = self.window.contentView;
    NSRect viewFrame = view.frame;
    viewFrame.origin.y = container.bounds.size.height - viewFrame.size.height;
    viewFrame.origin.x = 0;
    view.frame = viewFrame;
    
    //add to window
    [self.window.contentView addSubview:view];
    
    //set
    self.viewWasAdded = YES;
    
    //camera turned on?
    // request camera access
    if(tag == TOOLBAR_ALERTS) {
        if(((NSButton*)[view viewWithTag:BUTTON_ALERT_IMAGE_MODE]).state == NSControlStateValueOn) {
            requestCameraAccess();
        }
    }
    
    return;
}

//invoked when user toggles button
// update preferences for that button
-(IBAction)togglePreference:(id)sender
{
    //preferences
    NSMutableDictionary* updatedPreferences = nil;
    
    //button state
    NSNumber* state = nil;
    
    //init
    updatedPreferences = [NSMutableDictionary dictionary];
    
    //get button state
    state = @(((NSButton*)sender).state);
    
    //set appropriate preference
    switch(((NSButton*)sender).tag) {
            
        //no icon mode
        case BUTTON_NO_ICON_MODE:
            updatedPreferences[PREF_NO_ICON_MODE] = state;
            break;
            
        //touch id mode
        case BUTTON_TOUCH_ID_MODE:
            updatedPreferences[PREF_TOUCH_ID_MODE] = state;
            break;
        
        //apple watch mode
        case BUTTON_APPLE_WATCH_MODE:
            updatedPreferences[PREF_APPLE_WATCH_MODE] = state;
            break;
            
        //include image mode
        case BUTTON_ALERT_IMAGE_MODE:
            updatedPreferences[PREF_ALERT_IMAGE_MODE] = state;
            
            //turned on?
            // request camera access
            if(state.intValue == NSControlStateValueOn) {
                requestCameraAccess();
            }
            
            break;
            
        //disable remote alerts
        case BUTTON_NO_REMOTE_ALERTS_MODE:
            updatedPreferences[PREF_NO_REMOTE_ALERTS_MODE] = state;
            
            //turned on?
            // disconnect telegram
            if(state.intValue == NSControlStateValueOn) {
                
                //disable
                self.telegramBotToken.enabled = NO;
                self.telegramBotToken.stringValue = @"";
                
                ((NSButton*)[self.alertsView viewWithTag:BUTTON_ALERT_IMAGE_MODE]).enabled = NO;
                ((NSButton*)[self.alertsView viewWithTag:BUTTON_ALERT_IMAGE_MODE]).state = NSControlStateValueOff;
                
                os_log_debug(logHandle, "user toggled 'on' disable remote alerts, so will disable");
                
                //disconnect
                [self telegramDisconnect];
            }
            //turned off
            // enable items
            else {
                self.telegramBotToken.enabled = YES;
                ((NSButton*)[self.alertsView viewWithTag:BUTTON_ALERT_IMAGE_MODE]).enabled = YES;
            }
            
            break;
            
        //execute action
        // also toggle state of path
        case BUTTON_EXECUTE_ACTION:
            
            //set
            updatedPreferences[PREF_EXECUTE_ACTION] = state;
            
            //set path field state to match
            self.executePath.enabled = state.boolValue;
            if(state.intValue == NSControlStateValueOff) {
                self.executePath.stringValue = @"";
            }
            
            break;
            
            //no update mode
        case BUTTON_NO_UPDATE_MODE:
            updatedPreferences[PREF_NO_UPDATE_MODE] = state;
            break;
            
        default:
            break;
    }
    
    //send XPC msg to daemon to update prefs
    self.preferences = [xpcDaemonClient updatePreferences:updatedPreferences];
    
    //toggle (status menu) icon
    if(BUTTON_NO_ICON_MODE == ((NSButton*)sender).tag)
    {
        //toggle icon
        [((AppDelegate*)[[NSApplication sharedApplication] delegate]) toggleIcon:self.preferences];
    }
    
    return;
}

// configure Telegram UI based on current preferences
-(void)updateTelegramUI {
    
    NSString *botToken = self.preferences[PREF_BOT_TOKEN];
    NSString *chatID   = self.preferences[PREF_CHAT_ID];
    
    // no bot token — unconfigured state
    if(!botToken.length) {
        [self setTelegramState:TelegramStateUnconfigured];
        return;
    }
    
    // bot token but no chat ID — token valid, awaiting activation
    if(!chatID.length) {
        [self setTelegramState:TelegramStateActivating];
        return;
    }
    
    // both present — fully connected
    [self setTelegramState:TelegramStateConnected];
}

// apply UI for a given Telegram state
-(void)setTelegramState:(TelegramState)state {
    
    switch(state) {
            
        case TelegramStateUnconfigured:
            
            //blank QR code w/ border
            self.telegramQRCode.wantsLayer = YES;
            self.telegramQRCode.layer.cornerRadius = 8.0;
            self.telegramQRCode.layer.borderWidth  = 1.5;
            self.telegramQRCode.layer.borderColor  = [NSColor.separatorColor CGColor];
            self.telegramQRCode.layer.backgroundColor = [NSColor.windowBackgroundColor CGColor];
            
            self.telegramBotToken.stringValue  = @"";
            self.telegramStatus.stringValue    = @"📵 Telegram Alerts Disabled";
            self.stepTwo.alphaValue            = 0.3;
            self.stepTwoDetails.alphaValue     = 0.3;
            self.telegramQRCode.image          = nil;
            self.telegramActivityIndicator.hidden = YES;
            [self.telegramStackView layoutSubtreeIfNeeded];
            break;
            
        case TelegramStateActivating:
            self.telegramBotToken.stringValue  = self.preferences[PREF_BOT_TOKEN];
            self.telegramStatus.stringValue    = @"✅ Bot Token Valid — Scan QR Code to Activate";
            self.stepTwo.alphaValue            = 1.0;
            self.stepTwoDetails.alphaValue     = 1.0;
            
            [self showActivationQRCodeForBotUsername:self.preferences[PREF_BOT_USERNAME]];
            
            break;
            
        case TelegramStateConnected:
            
            //blank QR code w/ border
            self.telegramQRCode.wantsLayer = YES;
            self.telegramQRCode.layer.cornerRadius = 8.0;
            self.telegramQRCode.layer.borderWidth  = 1.5;
            self.telegramQRCode.layer.borderColor  = [NSColor.separatorColor CGColor];
            self.telegramQRCode.layer.backgroundColor = [NSColor.windowBackgroundColor CGColor];
            
            self.telegramBotToken.stringValue  = self.preferences[PREF_BOT_TOKEN];
            self.telegramStatus.stringValue    = @"✅ Telegram Alerts Enabled";
            self.stepTwo.alphaValue            = 0.3;
            self.stepTwoDetails.alphaValue     = 0.3;
            self.telegramQRCode.image          = nil;
            self.telegramActivityIndicator.hidden = YES;
            [self.telegramStackView layoutSubtreeIfNeeded];
            
            break;
    }
}


//validate bot token
- (IBAction)telegramDidEndEditing:(id)sender {
    
    //extract bot token from text field
    NSString* botToken = [((NSTextField*)sender).stringValue
                          stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    
    //reset QR code w/ border
    self.telegramQRCode.wantsLayer = YES;
    self.telegramQRCode.layer.cornerRadius = 8.0;
    self.telegramQRCode.layer.borderWidth  = 1.5;
    self.telegramQRCode.layer.borderColor  = [NSColor.separatorColor CGColor];
    self.telegramQRCode.layer.backgroundColor = [NSColor.windowBackgroundColor CGColor];
    
    //empty
    // disconnect
    if(!botToken.length) {
        [self telegramDisconnect];
        return;
    }
    
    //update UI
    self.telegramActivityIndicator.hidden = NO;
    [self.telegramActivityIndicator startAnimation:nil];
    
    self.telegramStatus.stringValue = @"Status: Validating Bot Token...";
    
    //1/2 second
    // now validate
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (NSEC_PER_SEC / 2)), dispatch_get_main_queue(), ^{
        
        //validate
        [self.telegram validateBotID:botToken completion:^(NSString* botName, NSString* botUserName, NSError* error) {
            
            if(error) {
                
                [self.telegramActivityIndicator stopAnimation:nil];
                self.telegramActivityIndicator.hidden = YES;
                
                self.telegramStatus.stringValue = [NSString stringWithFormat:@"ERROR: %@", error.localizedDescription];
                
                [self.telegramStackView layoutSubtreeIfNeeded];
                
                //reset
                self.telegramBotToken.stringValue = @"";
                
                self.preferences = [xpcDaemonClient updatePreferences:@{
                    PREF_BOT_TOKEN:  [NSNull null],
                    PREF_BOT_USERNAME:  [NSNull null],
                    PREF_CHAT_ID: [NSNull null]
                }];
                
                return;
            }
            
            //update prefs
            // bot id and bot user name
            self.preferences = [xpcDaemonClient updatePreferences:@{PREF_BOT_TOKEN:botToken, PREF_BOT_USERNAME:botUserName}];
            
            //is there a chat id already?
            [self.telegram getChatIDWithBotID:botToken
                                      timeout:0
                                   completion:^(NSString *chatID, NSError *error) {
                
                //have chat ID?
                if(chatID.length) {
                    
                    //save chat ID to prefs/keychain
                    self.preferences = [xpcDaemonClient updatePreferences:@{PREF_CHAT_ID: chatID}];
                    
                }
                
                [self.telegramActivityIndicator stopAnimation:nil];
                self.telegramActivityIndicator.hidden = YES;
                
                //update UI
                [self updateTelegramUI];
                
            }];
            
        }];
        
    });
}

// generate and show QR code for bot activation
- (void)showActivationQRCodeForBotUsername:(NSString *)botUsername {
    
    NSString *urlString = [NSString stringWithFormat:@"tg://resolve?domain=%@&start=connect", botUsername];
    
    // generate QR via CoreImage
    CIFilter *filter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    [filter setValue:[urlString dataUsingEncoding:NSUTF8StringEncoding] forKey:@"inputMessage"];
    [filter setValue:@"M" forKey:@"inputCorrectionLevel"];
    
    CIImage *ciImage = filter.outputImage;
    if(!ciImage) return;
    
    // scale up to fill the image view
    CGFloat scale = self.telegramQRCode.bounds.size.width / ciImage.extent.size.width;
    CIImage *scaled = [ciImage imageByApplyingTransform:CGAffineTransformMakeScale(scale, scale)];
    
    NSCIImageRep *rep = [NSCIImageRep imageRepWithCIImage:scaled];
    NSImage *image = [[NSImage alloc] initWithSize:rep.size];
    [image addRepresentation:rep];
    
    // white background so QR is always scannable in dark mode
    self.telegramQRCode.wantsLayer = YES;
    self.telegramQRCode.layer.backgroundColor = NSColor.whiteColor.CGColor;
    self.telegramQRCode.layer.cornerRadius = 8.0;
    
    self.telegramQRCode.image  = image;
    
    // start polling immediately — fires when user scans QR and taps Start
    self.telegramStatus.stringValue = @"Scan the QR code with your phone…";
    
    
    self.telegramActivityIndicator.hidden = NO;
    [self.telegramActivityIndicator startAnimation:nil];
    
    [self.telegram getChatIDWithBotID:self.preferences[PREF_BOT_TOKEN]
                              timeout:120
                           completion:^(NSString *chatID, NSError *error) {
        
        [self.telegramActivityIndicator stopAnimation:nil];
        self.telegramActivityIndicator.hidden = YES;
        [self.telegramStackView layoutSubtreeIfNeeded];
        
        
        if(error) {
            self.telegramStatus.stringValue = [NSString stringWithFormat:@"ERROR: %@", error.localizedDescription];
            return;
        }
        
        //no chat ID found ...time'd out?
        if(!chatID.length) {
            self.telegramStatus.stringValue = @"✅ Bot Token Valid — Scan to Activate";
            return;
        }
        
        self.telegramStatus.stringValue = @"✅ Telegram Alerts Enabled";
        
        //save chat ID
        self.preferences = [xpcDaemonClient updatePreferences:@{PREF_CHAT_ID: chatID}];
        
        //show success alert
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Telegram Connected!";
        alert.informativeText = @"You'll receive an alert when your MacBook lid is opened.";
        [alert addButtonWithTitle:@"Send Test"];
        [alert addButtonWithTitle:@"Close"];
        
        if([alert runModal] == NSAlertFirstButtonReturn) {
            [self telegramSendTest:nil];
        }
        
    }];
    
    return;
}

//send test
-(IBAction)telegramSendTest:(id)sender {
    NSString *botID  = self.preferences[PREF_BOT_TOKEN];
    NSString *chatID = self.preferences[PREF_CHAT_ID];
    if(!botID.length || !chatID.length) return;
    self.telegramActivityIndicator.hidden = NO;
    [self.telegramActivityIndicator startAnimation:nil];
    self.telegramStatus.stringValue = @"Sending test…";
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (NSEC_PER_SEC / 2)), dispatch_get_main_queue(), ^{
        
        [self.telegram sendTestAlertWithBotID:botID
                                       chatID:chatID
                                   completion:^(NSError *error) {
            
            [self.telegramActivityIndicator stopAnimation:nil];
            self.telegramActivityIndicator.hidden = YES;
            [self.telegramStackView layoutSubtreeIfNeeded];
            
            
            if(error) {
                self.telegramStatus.stringValue = [NSString stringWithFormat:@"ERROR:  %@", error.localizedDescription];
                return;
            }
            
            self.telegramStatus.stringValue = @"✅ Test Sent (Check Telegram)";
        }];
        
    });
}

//disconnect telegram button handler
-(void)telegramDisconnect {
    
    os_log_debug(logHandle, "disabling remote alerts...");
    
    self.telegramActivityIndicator.hidden = NO;
    [self.telegramActivityIndicator startAnimation:nil];
    self.telegramStatus.stringValue = @"Disabling…";
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (NSEC_PER_SEC / 2)), dispatch_get_main_queue(), ^{
        
        //remove telegram bot/chat id
        self.preferences = [xpcDaemonClient updatePreferences:@{
            PREF_BOT_TOKEN: [NSNull null],
            PREF_BOT_USERNAME: [NSNull null],
            PREF_CHAT_ID: [NSNull null]
        }];
        
        //reset UI
        [self.telegramActivityIndicator stopAnimation:nil];
        self.telegramActivityIndicator.hidden = YES;
        [self.telegramStackView layoutSubtreeIfNeeded];
        
        self.telegramBotToken.stringValue = @"";
        
        [self updateTelegramUI];
        
    });
    
}

//browse to select action
-(IBAction)browse:(id)sender {
    
    //'browse' panel
    NSOpenPanel *panel = nil;
    
    //response to 'browse' panel
    NSInteger response = 0;
    
    //init panel
    panel = [NSOpenPanel openPanel];
    
    //allow files
    panel.canChooseFiles = YES;
    
    //no directories
    panel.canChooseDirectories = NO;
    
    //can open app bundles
    panel.treatsFilePackagesAsDirectories = YES;
    
    //start in desktop
    panel.directoryURL = [[[NSFileManager defaultManager] URLsForDirectory:NSDesktopDirectory inDomains:NSUserDomainMask] firstObject];
    
    //disable multiple selections
    panel.allowsMultipleSelection = NO;
    
    //show it
    response = [panel runModal];
    
    //set path
    if(NSModalResponseCancel != response) {
        self.executePath.stringValue = panel.URL.path;
        
        //save
        self.preferences = [xpcDaemonClient updatePreferences:@{PREF_EXECUTE_PATH:self.executePath.stringValue}];
    }
    
    return;
}

//automatically called when 'enter' is hit
- (IBAction)actionDidEndEditing:(id)sender
{
    os_log_debug(logHandle, "actionDidEndEditing invoked...");
    
    NSString* path = self.executePath.stringValue;
    NSButton* button = [self.actionsView viewWithTag:BUTTON_EXECUTE_ACTION];

    //empty
    if(!path.length) {
        
        //disable button
        button.state = NSControlStateValueOff;
        
    }
    
    //send to daemon
    // will update preferences
    self.preferences = [xpcDaemonClient updatePreferences:@{PREF_EXECUTE_ACTION:@(button.state), PREF_EXECUTE_PATH:path}];
    
    return;
}


//'check for update' button handler
-(IBAction)check4Update:(id)sender
{
    //update obj
    Update* update = nil;
    
    //disable button
    self.updateButton.enabled = NO;
    
    //reset
    self.updateLabel.stringValue = @"";
    
    //show/start spinner
    [self.updateIndicator startAnimation:self];
    
    //init update obj
    update = [[Update alloc] init];
    
    //check for update
    // 'updateResponse newVersion:' method will be called when check is done
    [update checkForUpdate:^(NSUInteger result, NSString* newVersion) {
        
        //slight delay for UI
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            //process response
            [self updateResponse:result newVersion:newVersion];
            
        });
        
    }];
    
    return;
}

//process update response
// error, no update, update/new version
-(void)updateResponse:(NSInteger)result newVersion:(NSString*)newVersion
{
    //re-enable button
    self.updateButton.enabled = YES;
    
    //stop/hide spinner
    [self.updateIndicator stopAnimation:self];
    
    switch(result)
    {
        //error
        case -1:
            
            //set label
            self.updateLabel.stringValue = @"error: update check failed";
            
            break;
            
        //no updates
        case 0:
            
            //dbg msg
            os_log_debug(logHandle, "no updates available");
            
            //set label
            self.updateLabel.stringValue = [NSString stringWithFormat:@"Installed version (%@),\r\nis the latest.", getAppVersion()];
            
            break;
         
            
        //new version
        case 1:
            
            //dbg msg
            os_log_debug(logHandle, "a new version (%{public}@) is available", newVersion);
            
            //alloc update window
            updateWindowController = [[UpdateWindowController alloc] initWithWindowNibName:@"UpdateWindow"];
            
            //configure
            [self.updateWindowController configure:[NSString stringWithFormat:@"a new version (%@) is available!", newVersion] buttonTitle:@"Update"];
            
            //center window
            [[self.updateWindowController window] center];
            
            //show it
            [self.updateWindowController showWindow:self];
            
            //float above other windows
            [self.updateWindowController.window setLevel:NSFloatingWindowLevel];
            [self.updateWindowController.window makeKeyAndOrderFront:nil];
            
            break;
    }
        
    return;
}

//on window close
// clean up and set activation policy
-(void)windowWillClose:(NSNotification *)notification
{
    //execute action checked but no command/path?
    if([self.preferences[PREF_EXECUTE_ACTION] boolValue] && !self.executePath.stringValue.length) {
        self.preferences = [xpcDaemonClient updatePreferences:@{PREF_EXECUTE_ACTION:@NO, PREF_EXECUTE_PATH:@""}];
    }
    
    //wait a bit, then set activation policy
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
    ^{
         //on main thread
         dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
             
             //set activation policy
             [((AppDelegate*)[[NSApplication sharedApplication] delegate]) setActivationPolicy];
             
         });
    });
    
    return;
}

@end
