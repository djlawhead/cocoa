#include "cocoa.h"

extern void cocoaStart();
extern void cocoaUrl(char *url);

@interface CocoaAppDelegate : NSObject <NSApplicationDelegate>

- (void)showDialogWithMessage:(NSString *)message;

- (NSUInteger)showDialogWithMessage:(NSString *)message
                 andButtonLeftLabel:(NSString *)button1
                   rightButtonLabel:(NSString *)button2;

- (NSString *)showFilesystemDialogWithTitle:(NSString *)title 
                                   fileTypes:(NSArray *)fileTypes
                                 initialPath:(NSURL *)initialPathURL
                           enableMultiSelect:(BOOL)multiSelection
                                 selectFiles:(BOOL)selectFiles;

- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event 
           withReplyEvent:(NSAppleEventDescriptor *)replyEvent;


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

- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
    NSURL *url = [NSURL URLWithString:[[event paramDescriptorForKeyword:keyDirectObject] stringValue]];
    NSLog(@"handleGetURLEvent:withReplyEvent: -- Got URL %@", url);
    cocoaUrl((char *)[[url absoluteString] UTF8String]);
}

- (void)showDialogWithMessage:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"OK"];
    [alert setInformativeText:message];
    [alert setAlertStyle:0];
    [alert runModal];
}

- (NSUInteger)showDialogWithMessage:(NSString *)message
                 andButtonLeftLabel:(NSString *)button1
                   rightButtonLabel:(NSString *)button2 {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:button1];
    [alert addButtonWithTitle:button2];
    [alert setInformativeText:message];
    [alert setAlertStyle:0];
    return [alert runModal];
}

- (NSString *)showFilesystemDialogWithTitle:(NSString *)title 
                                    fileTypes:(NSArray *)fileTypes
                                  initialPath:(NSURL *)initialPath
                            enableMultiSelect:(BOOL)multiSelection
                                  selectFiles:(BOOL)selectFiles {

    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setFloatingPanel:YES];
    [openPanel setCanChooseFiles:selectFiles];
    [openPanel setCanChooseDirectories:!selectFiles];
    [openPanel setAllowsMultipleSelection:multiSelection];
    [openPanel setDirectoryURL:initialPath];
    [openPanel setTitle:title];
    
    NSString *retval = nil;
    
    if ([openPanel runModal] == NSModalResponseOK)
    {
        NSMutableArray *selectedPaths = [[NSMutableArray alloc] init];
        for (NSURL *url in [openPanel URLs])
        {
            [selectedPaths addObject:[url path]];
        }

        retval = [selectedPaths componentsJoinedByString:@","];
    }
        
    return retval;
}

@end

void printLog(char *msg) {
	NSString *message = [NSString stringWithUTF8String:msg];
	NSLog(@"Log message: %@", message);
}

void cocoaDialog(char *msg) {
	dispatch_sync(dispatch_get_main_queue(), ^{
		[(CocoaAppDelegate *)[NSApp delegate] showDialogWithMessage:[NSString stringWithUTF8String:msg]];
	});
}

int cocoaPrompt(char *msg, char *btn1, char *btn2) {
    NSUInteger retval = 0;
    retval = [(CocoaAppDelegate *)[NSApp delegate] showDialogWithMessage:[NSString stringWithUTF8String:msg]
                                                      andButtonLeftLabel:[NSString stringWithUTF8String:btn1]
                                                        rightButtonLabel:[NSString stringWithUTF8String:btn2]];
    return (int)retval;
}


const char* cocoaFSDialog(char *title,
    char *fileTypesCsv,
    char *initialPath,
    bool canChooseFiles,
    bool multiSelection) {

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
        fileTypesArr = [csvStr componentsSeparatedByString:@","];
    }
    
    __block const char *retval = NULL;
    
    dispatch_sync(dispatch_get_main_queue(), ^{
    	CocoaAppDelegate *delegate = (CocoaAppDelegate *)[NSApp delegate];
    	NSString *pathsCsv = [delegate showFilesystemDialogWithTitle:titleStr
    		                                               fileTypes:fileTypesArr
    		                                             initialPath:initialURL
    		                                        enableMultiSelect:multiSelection
    		                                              selectFiles:canChooseFiles];
    	retval = [pathsCsv UTF8String];
    });
        
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
