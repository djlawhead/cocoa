#include "cocoa.h"

extern void cocoaStart();
extern void cocoaUrl(char *url);

void runOnMainQueueWithoutDeadlocking(void (^ block)(dispatch_semaphore_t s))
{
    if ([NSThread isMainThread])
    {
        block(nil);
    }
    else
    {
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        dispatch_async(dispatch_get_main_queue(), ^{
            block(sema);
        });
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        sema = nil;
    }
}

@interface CocoaAppDelegate : NSObject <NSApplicationDelegate>

- (void)showDialogWithMessage:(NSString *)message;

- (void) showDialogWithMessage:(NSString *)message
            andButtonLeftLabel:(NSString *)button1
              rightButtonLabel:(NSString *)button2
             completionHandler:(void (^)(NSModalResponse returnCode))handler;

- (void)showFilesystemDialogWithTitle:(NSString *)title 
                                    fileTypes:(NSArray *)fileTypes
                                  initialPath:(NSURL *)initialPath
                            enableMultiSelect:(BOOL)multiSelection
                                  selectFiles:(BOOL)selectFiles
                            completionHandler:(void (^)(NSString *csv))handler;

- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event 
           withReplyEvent:(NSAppleEventDescriptor *)replyEvent;

- (NSString *)bundleIdentifier;

- (NSString *)bundlePath;

@property (nonatomic,assign) BOOL autoLaunch;


@end

@implementation CocoaAppDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification {
    NSAppleEventManager *appleEventManager = [NSAppleEventManager sharedAppleEventManager];
    [appleEventManager setEventHandler:self
                           andSelector:@selector(handleGetURLEvent:withReplyEvent:)
                         forEventClass:kInternetEventClass andEventID:kAEGetURL];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    cocoaStart();
}

- (void)applicationDidEnterBackground:(NSApplication *)app {
}

- (void)applicationDidBecomeActive:(NSApplication *)app {
}

- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
    NSURL *url = [NSURL URLWithString:[[event paramDescriptorForKeyword:keyDirectObject] stringValue]];
    cocoaUrl((char *)[[url absoluteString] UTF8String]);
}

- (void)showDialogWithMessage:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"OK"];
    [alert setInformativeText:message];
    [alert setAlertStyle:0];
    [alert runModal];
}

- (void) showDialogWithMessage:(NSString *)message
            andButtonLeftLabel:(NSString *)button1
              rightButtonLabel:(NSString *)button2
             completionHandler:(void (^)(NSModalResponse returnCode))handler {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:button1];
    [alert addButtonWithTitle:button2];
    [alert setInformativeText:message];
    [alert setAlertStyle:0];
    handler([alert runModal]);
}

- (void)showFilesystemDialogWithTitle:(NSString *)title 
                                    fileTypes:(NSArray *)fileTypes
                                  initialPath:(NSURL *)initialPath
                            enableMultiSelect:(BOOL)multiSelection
                                  selectFiles:(BOOL)selectFiles
                            completionHandler:(void (^)(NSString *csv))handler {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setFloatingPanel:YES];
    [openPanel setCanChooseFiles:selectFiles];
    [openPanel setCanChooseDirectories:!selectFiles];
    [openPanel setAllowsMultipleSelection:multiSelection];
    [openPanel setDirectoryURL:initialPath];
    [openPanel setTitle:title];
    if ([fileTypes count] > 0)
        [openPanel setAllowedFileTypes:fileTypes];
    
    [openPanel beginWithCompletionHandler:^(NSInteger result){
        if (result  == NSModalResponseOK)
        {
            NSMutableArray *selectedPaths = [[NSMutableArray alloc] init];
            for (NSURL *url in [openPanel URLs])
            {
                [selectedPaths addObject:[url path]];
            }
            handler([selectedPaths componentsJoinedByString:@"\n"]);
        }
        else {
            handler(nil);
        }
    }];  
}
// TODO forward applescript errors up to the go layer for proper error handling
- (void)setAutoLaunch:(BOOL)flag forApplication:(NSString *)appName atPath:(NSString *)path
{
    static const AEKeyword aeName = 'pnam';
    static const AEKeyword aePath = 'ppth';
    NSString *src = @"tell application \"System Events\" to get the name of every login item";
    BOOL alreadyAdded = false;
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:src];
    NSDictionary *err = nil;
    NSAppleEventDescriptor *evtDesc = [script executeAndReturnError:&err];
    script = nil;
    for (int i = 0; i < [evtDesc numberOfItems]; ++i)
    {
        NSAppleEventDescriptor *loginItem = [evtDesc descriptorAtIndex:i];
        NSString *loginItemName = [[loginItem descriptorForKeyword:aeName] stringValue];
        if ([loginItemName isEqualTo:appName])
        {
            alreadyAdded = TRUE;
        }
    }
    evtDesc = nil;
    if (flag && !alreadyAdded)
    {
        src = @"tell application \"System Events\" to make login item at end with properties {name:\"%s\",path:\"%s\",hidden:false}";
    }
    else if (!flag && alreadyAdded)
    {
        src = @"tell application \"System Events\" to delete login item \"%s\"";
    }
    script = [[NSAppleScript alloc] initWithSource:[NSString stringWithFormat:src, [appName UTF8String], [path UTF8String]]];
    evtDesc = [script executeAndReturnError:&err]; 
}

- (NSString *)bundleIdentifier {
    if ([NSBundle mainBundle] == nil) return @"com.apple.Safari";
    return [[NSBundle mainBundle] bundleIdentifier];
}

- (NSString *)bundlePath {
    if ([NSBundle mainBundle] == nil) return @"/Applications/Safari.app/Contents/MacOS/Safari";
    return [[NSBundle mainBundle] bundlePath];
}

@end

CocoaAppDelegate *getDelegate() {
    return (CocoaAppDelegate *)[NSApp delegate];
}

char* bundlePath() {
    __block char *retval = nil;
    CocoaAppDelegate *delegate = getDelegate();
    dispatch_sync(dispatch_get_main_queue(), ^{
        retval = (char *)[[delegate bundlePath] UTF8String];
    });
    return retval;
}

char* bundleIdentifier() {
    __block char *retval = nil;
    CocoaAppDelegate *delegate = getDelegate();
    dispatch_sync(dispatch_get_main_queue(), ^{
        NSString *identifier = [delegate bundleIdentifier];
        if (identifier == nil) identifier = @"unknown.bundle";
        retval =  (char *)[identifier UTF8String];
    });
    return retval;
}

void autoStart(bool flag) {
    CocoaAppDelegate *delegate = (CocoaAppDelegate *)[NSApp delegate];
    [delegate setAutoLaunch:flag forApplication:[delegate bundleIdentifier] atPath:[delegate bundlePath]];
}

void printLog(char *msg) {
    NSString *message = [NSString stringWithUTF8String:msg];
}

void cocoaDialog(char *msg) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [(CocoaAppDelegate *)[NSApp delegate] showDialogWithMessage:[NSString stringWithUTF8String:msg]];
    });
}

int cocoaPrompt(char *msg, char *btn1, char *btn2) {
    __block NSUInteger retval = 0;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    void (^handler)(NSModalResponse) = ^(NSModalResponse response){
        retval = (NSUInteger)response;
        dispatch_semaphore_signal(sem);
    };
    dispatch_async(dispatch_get_main_queue(), ^{
        [(CocoaAppDelegate *)[NSApp delegate] showDialogWithMessage:[NSString stringWithUTF8String:msg]
                                                 andButtonLeftLabel:[NSString stringWithUTF8String:btn1]
                                                   rightButtonLabel:[NSString stringWithUTF8String:btn2]
                                                  completionHandler:handler]; 
    });
    [NSApp activateIgnoringOtherApps:YES];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    sem = nil;
    return (int)retval;
}


const char* cocoaFSDialog(char *title,
    char *fileTypesCsv,
    char *initialPath,
    bool canChooseFiles,
    bool multiSelection) {

    sleep(1);

    NSURL *initialURL = nil;
    NSString *titleStr = nil;
    NSArray *fileTypesArr = nil;

    if (initialPath != NULL) {
        initialURL = [NSURL fileURLWithPath:[NSString stringWithCString:initialPath encoding:NSUTF8StringEncoding]];
    }
    if (title != NULL) {
        titleStr = [[NSString alloc] initWithUTF8String:title];
    }
    if (fileTypesCsv != NULL)  {
        NSString *csvStr = [[NSString alloc] initWithUTF8String:fileTypesCsv];
    if (![csvStr isEqualTo:@""])
            fileTypesArr = [csvStr componentsSeparatedByString:@","];
    }
    
    __block NSString *blockret = NULL;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    dispatch_async(dispatch_get_main_queue(), ^{
        CocoaAppDelegate *delegate = (CocoaAppDelegate *)[NSApp delegate];
        [delegate showFilesystemDialogWithTitle:titleStr
            fileTypes:fileTypesArr
            initialPath:initialURL
            enableMultiSelect:multiSelection
            selectFiles:canChooseFiles
            completionHandler:^(NSString *csv) {
                if (csv != nil) { 
                    blockret = csv;
                }
                dispatch_semaphore_signal(sem);
            }
        ];
    });
    [NSApp activateIgnoringOtherApps:YES];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    sem = nil;
        
    if (blockret != nil) {
        char *retval = (char *)[[blockret copy] UTF8String];
        return retval;
    }
    return nil;
}
void cocoaMain() {
        @autoreleasepool {
            CocoaAppDelegate *delegate = [[CocoaAppDelegate alloc] init];
            [[NSApplication sharedApplication] setDelegate:delegate];
            [NSApp run];
        }
}

void cocoaExit() {
    [NSApp terminate:nil];
}
