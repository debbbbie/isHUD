//
//  ISHAppDelegate.m
//  isHUD
//
//  Created by ghawkgu on 11/15/11.
//  Copyright (c) 2011 ghawkgu.
//

#import "ISHAppDelegate.h"
#import "ISHAppDelegate+.h"
#import "ISHKeyCode.h"
#import "ISHDefaults.h"
#import <Carbon/Carbon.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - Implemetation
@implementation ISHAppDelegate (Preferences)
-(void) registerDefaultPreferences {
    NSDictionary *appDefaults = [NSDictionary
                                 dictionaryWithObject:[NSNumber numberWithInteger:COMMAND_R] forKey:DEFAULT_KEY_SELECT_INPUT_SOURCE];
    [[NSUserDefaults standardUserDefaults] registerDefaults:appDefaults];
}
-(void) loadPreferences {
    GHKLOG(@"Preferences changed!");
    hotkeySelectInputSource = [[NSUserDefaults standardUserDefaults] integerForKey:DEFAULT_KEY_SELECT_INPUT_SOURCE];
}
@end

@implementation ISHAppDelegate (Helper)
-(void) dumpInputResource:(TISInputSourceRef)inputResource {
#ifdef DEBUG
    NSString *isId = TISGetInputSourceProperty(inputResource, kTISPropertyInputSourceID);
    NSString *isModeId = TISGetInputSourceProperty(inputResource, kTISPropertyInputModeID);
    NSString *isBundleId = TISGetInputSourceProperty(inputResource, kTISPropertyBundleID);
    NSString *localizedName = TISGetInputSourceProperty(inputResource, kTISPropertyLocalizedName);
    BOOL isSelectable = CFBooleanGetValue(TISGetInputSourceProperty(inputResource, kTISPropertyInputSourceIsSelectCapable));
    BOOL enableCapable = CFBooleanGetValue(TISGetInputSourceProperty(inputResource, kTISPropertyInputSourceIsEnableCapable));
    BOOL isCurrentEnabled = CFBooleanGetValue(TISGetInputSourceProperty(inputResource, kTISPropertyInputSourceIsEnabled));
    GHKLOG(@"==========Dump input source (%@) ===========", isId);
    GHKLOG(@"=====>>>>> mode id (%@) ", isModeId);
    GHKLOG(@"=====>>>>> bundle id (%@) ", isBundleId);
    GHKLOG(@"=====>>>>> localized name (%@) ", localizedName);
    GHKLOG(@"=====>>>>> enable capable (%@) ", enableCapable ? @"YES" : @"NO");
    GHKLOG(@"=====>>>>> is enabled (%@) ", isCurrentEnabled ? @"YES" : @"NO");
    GHKLOG(@"=====>>>>> select capable (%@) ", isSelectable ? @"YES" : @"NO");
#endif
}
@end

@implementation ISHAppDelegate (LoginItem)
// I copied the codes from the following blog. And a little modification.
// http://cocoatutorial.grapewave.com/2010/02/creating-andor-removing-a-login-item/

-(LSSharedFileListItemRef) findLoginItem:(LSSharedFileListRef)loginItems {
    LSSharedFileListItemRef retVal = NULL;
    if (!loginItems) return retVal;
    
    NSString *appPath = [[NSBundle mainBundle] bundlePath];
    
    // This will retrieve the path for the application
	// For example, /Applications/test.app
    NSURL *url = [NSURL new];
    
    UInt32 seedValue;
    //Retrieve the list of Login Items and cast them to
    // a NSArray so that it will be easier to iterate.
    NSArray  *loginItemsArray = (NSArray *)LSSharedFileListCopySnapshot(loginItems, &seedValue);
    int i = 0;
    for(; i< [loginItemsArray count]; i++){
        LSSharedFileListItemRef itemRef = (LSSharedFileListItemRef)[loginItemsArray
                                                                    objectAtIndex:i];
        //Resolve the item with URL
        if (LSSharedFileListItemResolve(itemRef, 0, (CFURLRef*) &url, NULL) == noErr) {
            NSString * urlPath = [url path];
            [url release]; // The resolved url must be released!
            if ([urlPath compare:appPath] == NSOrderedSame){
                CFRetain(itemRef);
                retVal = itemRef;
                break;
            }
        }
    }
    // WARNING! Fix this for ARC.
    [loginItemsArray release];
    
    return retVal;
}

-(BOOL) isLoginItem {
	// Create a reference to the shared file list.
	LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL,
                                                            kLSSharedFileListSessionLoginItems, NULL);
    LSSharedFileListItemRef listItemRef = [self findLoginItem:loginItems];
    
    BOOL retVal = NO;
    
    if ([self findLoginItem:loginItems]) {
        retVal = YES;
        CFRelease(listItemRef);
    }
    
    CFRelease(loginItems);
    return retVal;
}

-(void) addAppAsLoginItem{
	NSString * appPath = [[NSBundle mainBundle] bundlePath];
    
	// This will retrieve the path for the application
	// For example, /Applications/test.app
	CFURLRef url = (CFURLRef)[NSURL fileURLWithPath:appPath]; 
    
	// Create a reference to the shared file list.
    // We are adding it to the current user only.
    // If we want to add it all users, use
    // kLSSharedFileListGlobalLoginItems instead of
    //kLSSharedFileListSessionLoginItems
	LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL,
                                                            kLSSharedFileListSessionLoginItems, NULL);
	if (loginItems) {
		//Insert an item to the list.
		LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(loginItems,
                                                                     kLSSharedFileListItemLast, NULL, NULL,
                                                                     url, NULL, NULL);
		if (item){
			CFRelease(item);
        }
	}	
    
	CFRelease(loginItems);
}

-(void) deleteAppFromLoginItem{
	// Create a reference to the shared file list.
	LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL,
                                                            kLSSharedFileListSessionLoginItems, NULL);
    
    LSSharedFileListItemRef itemRef = [self findLoginItem:loginItems];
    
    if (itemRef) {
        LSSharedFileListItemRemove(loginItems,itemRef);
        CFRelease(itemRef);
    }
    
    CFRelease(loginItems);
}
@end

#pragma mark -
@implementation ISHAppDelegate

@synthesize window = _window;
@synthesize isName = _isName;
@synthesize statusMenu = _statusMenu;
@synthesize panelView = _panelView;
@synthesize isImage = _isImage;
@synthesize myStatusMenu = _myStatusMenu;
@synthesize preferencesController = _preferencesController;

@synthesize timerToFadeOut = _timerToFadeOut;
@synthesize timerForHotKeyDelay = _timerForHotKeyDelay;

// WARNING! Fix this for ARC.
- (void) dealloc {
    self.timerToFadeOut = nil;
    self.timerForHotKeyDelay = nil;
    self.myStatusMenu = nil;
    self.preferencesController = nil;
    [super dealloc];
}

#pragma mark - Window fadding in/out animation
- (void)fadeInHud {
    if (self.timerToFadeOut) {
        [self.timerToFadeOut invalidate];
        self.timerToFadeOut = nil;
    }
    
    fadingOut = NO;
    
    [self.window orderFrontRegardless];

    [CATransaction begin];
    [CATransaction setValue:[NSNumber numberWithFloat:HUD_FADE_IN_DURATION] forKey:kCATransactionAnimationDuration];
    [CATransaction setValue:^{ [self didFadeIn]; } forKey:kCATransactionCompletionBlock];

    [[self.panelView layer] setOpacity:1.0];
    
    [CATransaction commit];
}

- (void) didFadeIn {
    self.timerToFadeOut = [NSTimer scheduledTimerWithTimeInterval:HUD_DISPLAY_DURATION target:self selector:@selector(fadeOutHud) userInfo:nil repeats:NO];
}

- (void)fadeOutHud {
    fadingOut = YES;
    [CATransaction begin];
    [CATransaction setValue:[NSNumber numberWithFloat:HUD_FADE_OUT_DURATION] forKey:kCATransactionAnimationDuration];
    [CATransaction setValue:^{ [self didFadeOut]; } forKey:kCATransactionCompletionBlock];
    
    [[self.panelView layer] setOpacity:0.0];
    
    [CATransaction commit];
}

- (void)didFadeOut {
    if (fadingOut) {
        GHKLOG(@"Did fade out!");
        [self.window orderOut:nil];
    }
    fadingOut = NO;
}

#pragma mark - HUD size adjustment
- (NSDictionary *) getLabelAttributes {
    NSFont *font = [NSFont fontWithName:@"Lucida Grande" size:24.0];
    NSDictionary *attrsDictionary =
    [NSDictionary dictionaryWithObject:font
                                forKey:NSFontAttributeName];
    return attrsDictionary;
}

- (NSString *)getLongestInputSourceName {
    NSDictionary *filter = [NSDictionary dictionaryWithObject:(NSString *)kTISCategoryKeyboardInputSource
                                                       forKey:(NSString *)kTISPropertyInputSourceCategory];
    
    NSArray *inputSources = (NSArray *)TISCreateInputSourceList((CFDictionaryRef)filter, false);
    
    TISInputSourceRef inputSource;
    NSString *name;
    NSString *nameForMaxLength;
    CGFloat currentLengthOfName = 0, maxLengthOfName = 0;
    NSDictionary *attributes = [self getLabelAttributes];
    
    for (int i = 0; i < [inputSources count]; i++) {
        inputSource = (TISInputSourceRef)[inputSources objectAtIndex:i];

        NSString *isModeId = TISGetInputSourceProperty(inputSource, kTISPropertyInputModeID);        
        name = (NSString *)TISGetInputSourceProperty(inputSource, kTISPropertyLocalizedName);
        GHKLOG(@"Found input method: %@", name);
        [self dumpInputResource:inputSource];
        
        if ([isModeId isEqualToString:name]) {
            GHKLOG(@">>>>>>>>>>> passed.");
            continue;
        } //Bypass some input source modes.
        
        NSSize stringSize = [name sizeWithAttributes:attributes];
        currentLengthOfName = stringSize.width;
        if (currentLengthOfName > maxLengthOfName) {
            maxLengthOfName = currentLengthOfName;
            nameForMaxLength = name;
        }
    }

    [inputSources release];
    
    GHKLOG(@"The input method with the longest name is: %@", nameForMaxLength);
    return nameForMaxLength;
}

- (void)setUpHUD {
    //Set the longest name in the label, the make the label to autofit the name.
    [self.isName setStringValue:[self getLongestInputSourceName]];
    [self.isName sizeToFit];
    
    //Re-calculate the window frame and the the positions of subviews.
    CGRect labelFrame = [self.isName frame];
    CGRect windowFrame = [self.window frame];
    GHKLOG(@"label:(%f, %f) (%f x %f) ", labelFrame.origin.x, labelFrame.origin.y, labelFrame.size.width, labelFrame.size.height);
    GHKLOG(@"window:(%f, %f) (%f x %f) ", windowFrame.origin.x, windowFrame.origin.y, windowFrame.size.width, windowFrame.size.height);
    
    windowFrame.size.width = labelFrame.size.width + HUD_HORIZONTAL_MARGIN * 2;
    windowFrame.size.height = HUD_HEIGHT;
    
    NSRect screenRect = [[[NSScreen screens] objectAtIndex:0] visibleFrame];
    windowFrame.origin.x = (screenRect.size.width - windowFrame.size.width) / 2;
    windowFrame.origin.y = (screenRect.size.height - windowFrame.size.height) / 2;
    
    [self.window setFrame:windowFrame display:YES];
    
    NSRect viewFrame = windowFrame;
    viewFrame.origin.x = 0;
    viewFrame.origin.y = 0;
    [self.panelView setFrame:viewFrame];
    
    labelFrame.origin.x = HUD_HORIZONTAL_MARGIN;
    labelFrame.origin.y = (windowFrame.size.height - labelFrame.size.height) / 2;
    [self.isName setFrame:labelFrame];
}

#pragma mark - Main application
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    GHKLOG(@"Initialized!");
    [self registerDefaultPreferences];
    [self loadPreferences];
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(inputSourceChanged:)
                                                            name:(NSString *)kTISNotifySelectedKeyboardInputSourceChanged object:nil];
    
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(enabledInputSourceChanged:)
                                                            name:(NSString *)kTISNotifyEnabledKeyboardInputSourcesChanged object:nil];
    
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(screenSizeChanged:)
                                                            name:NSApplicationDidChangeScreenParametersNotification object:nil];
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(localeChanged:)
                                                            name:NSCurrentLocaleDidChangeNotification object:nil];
}

-(void) initUIComponents {
    [self.window setOpaque:NO];
    [self.window setBackgroundColor:[NSColor clearColor]];
    [self.window setLevel:kCGUtilityWindowLevelKey + 1000]; //Make the window be the top most one while displayed. (The 1000 is a magic number.)
    [self.window setStyleMask:NSBorderlessWindowMask]; //No title bar;
    [self.window setHidesOnDeactivate:NO];
    // Make the window behavior like the menu bar.
    [self.window setCollectionBehavior: NSWindowCollectionBehaviorCanJoinAllSpaces];
        
    CALayer *viewLayer = [CALayer layer];
    [viewLayer setBackgroundColor:CGColorCreateGenericRGB(0.05, 0.05, 0.05, HUD_ALPHA_VALUE)]; //RGB plus Alpha Channel
    [viewLayer setCornerRadius:HUD_CORNER_RADIUS];
    [self.panelView setWantsLayer:YES]; // view's backing store is using a Core Animation Layer
    [self.panelView setLayer:viewLayer];
    [[self.panelView layer] setOpacity:0.0];
    
    [self setUpHUD];
}


-(void) updateLoginItemMenuState:(NSInteger)state {
    NSMenuItem *item = [self.statusMenu itemWithTag:MENUITEM_TAG_TOGGLE_LOGIN_ITEM];
    [item setState:state];
}

-(void)awakeFromNib{
    [self initUIComponents];
    
    // Initialize the menu.
    self.myStatusMenu = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [self.myStatusMenu setMenu:self.statusMenu];
    [self.myStatusMenu setImage:[NSImage imageNamed:STATUS_MENU_ICON]];
    [self.myStatusMenu setHighlightMode:YES];
    
    if ([self isLoginItem]) {
        [self updateLoginItemMenuState:NSOnState];
    } else {
        [self updateLoginItemMenuState:NSOffState];
    }
    
//    [self registerHotKey];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
    [self unregisterHotKey];
}

- (void)inputSourceChanged:(NSNotification *) notification {
    GHKLOG(@"Input method changed, %@", notification);

    TISInputSourceRef inputSource = TISCopyCurrentKeyboardInputSource();
    NSString *name = (NSString *)TISGetInputSourceProperty(inputSource, kTISPropertyLocalizedName);
    //GHKLOG(@"The current is: %@", name);
    [self dumpInputResource:inputSource];
    CFRelease(inputSource);
    
    static NSString *previousIsName = nil;
    
    //Display the input source name only if it has changed.
    if (![previousIsName isEqualToString:name]) {
        previousIsName = name;
        
        [self.isName setStringValue:name];
                        
        NSURL *iconUrl = (NSURL *)TISGetInputSourceProperty(inputSource, kTISPropertyIconImageURL);
        GHKLOG(@"Icon url:%@", iconUrl);
        // WARNING! Fix this for ARC.
        self.isImage.image = [[[NSImage alloc] initWithContentsOfURL:iconUrl] autorelease];
        
        [self fadeInHud];
    }

}

- (void)enabledInputSourceChanged:(NSNotification *) notification {
    [self setUpHUD];
}

- (void)screenSizeChanged:(NSNotification *) notification {
    [self setUpHUD];
}

- (void)localeChanged:(NSNotification *) notification {
    [self setUpHUD];
}

#pragma mark - Menu item event handler
- (IBAction)quit:(id)sender {
    GHKLOG(@"Bye!");
    [NSApp terminate:nil];
}

- (IBAction)toggleLoginItem:(id)sender {
    if ([self isLoginItem]) {
        [self deleteAppFromLoginItem];
        [self updateLoginItemMenuState:NSOffState];
    } else {
        [self addAppAsLoginItem];
        [self updateLoginItemMenuState:NSOnState];
    }
}

- (IBAction)openPreferences:(id)sender {
    GHKLOG(@"Preferences...");
    if (!self.preferencesController) {
        ISHPreferencesWindowController *controller = [[ISHPreferencesWindowController alloc] initWithWindowNibName:@"PreferencesWindow"];
        self.preferencesController = controller;
        [controller release];
    }

    [self.preferencesController showWindow:nil];
    [self.preferencesController.window orderFront:nil];
}

#pragma mark - Hotkey handler
- (IBAction)onHotKey:(id)sender {
    self.timerForHotKeyDelay = [NSTimer scheduledTimerWithTimeInterval:HOT_KEY_HOLD_DELAY
                                                            target:self
                                                          selector:@selector(fadeInHud)
                                                          userInfo:nil
                                                           repeats:NO];
}

- (IBAction)cancelHotKey:(id)sender {
    [self.timerForHotKeyDelay invalidate];
    self.timerForHotKeyDelay = nil;
}

- (IBAction)showHud:(id)sender {
    [self fadeInHud];
}
@end
