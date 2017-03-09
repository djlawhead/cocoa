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

@property (nonatomic) BOOL autoLaunch;


@end

@implementation CocoaAppDelegate

@synthesize autoLaunch=_autoLaunch;

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
    }];  
}

- (void)setAutoLaunch:(BOOL)flag
{
    NSString *bundleIdentifier = (NSString *)[[NSBundle mainBundle] valueForKey:@"NSBundleIdentifier"];
    SMLoginItemSetEnabled((__bridge CFStringRef)bundleIdentifier, flag);
}

- (BOOL)autoLaunch
{
    return _autoLaunch;
}

@end

void setAutoStart(bool flag) {
    CocoaAppDelegate *delegate = (CocoaAppDelegate *)[NSApp delegate];
    delegate.autoLaunch = flag;
}

void printLog(char *msg) {
    NSString *message = [NSString stringWithUTF8String:msg];
    NSLog(@"Log message: %@", message);
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
        NSLog(@"dispatching to delegate");
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
                blockret = csv;
                dispatch_semaphore_signal(sem);
            }
        ];
    });
    [NSApp activateIgnoringOtherApps:YES];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    sem = nil;
        
    char *retval = (char *)[[blockret copy] UTF8String];
    return retval;
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
