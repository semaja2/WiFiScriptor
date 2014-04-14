#import "AppController.h"
//#define DEBUG

static void scCallback (SCDynamicStoreRef store, CFArrayRef changedKeys, 
						void *info)
{
#pragma unused(info)
	
	AppController *controller = (AppController *)info;
	CFIndex count = CFArrayGetCount(changedKeys);
	int i;
	for (i=0; i<count; ++i) {
		CFStringRef key = CFArrayGetValueAtIndex(changedKeys, (CFIndex)i);
		if (CFStringCompare(key,
							CFSTR("State:/Network/Interface/en1/AirPort"),
							0) == kCFCompareEqualTo) {
			CFDictionaryRef newValue = SCDynamicStoreCopyValue(store, key);
			
			[controller airportStatusChange:(CFDictionaryRef) newValue];
			if (newValue)
				CFRelease(newValue);
		}
	}
	
}





@implementation AppController

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSArray *ssidDicDefaults = [[NSUserDefaults standardUserDefaults] objectForKey:@"ssidData"];
	
	ssidDic = [[NSMutableArray alloc] init];
	if (ssidDicDefaults != nil) { // found default entry ...
		NSEnumerator *dictsEnumerator = [ssidDicDefaults objectEnumerator];
		id theObject;
		while (theObject = [dictsEnumerator nextObject]) {
			[ssidDic addObject:[[NSMutableDictionary dictionaryWithDictionary:theObject] retain]];
		}
	}
	else {
		ssidDic = [[NSMutableArray arrayWithArray:ssidDicDefaults] retain];
	}
	[theList reloadData];
	
	[pool release];
}

- (void) dealloc {
	[ssidDic release];
	[statusImageOn release];
	[statusImageOff release];
	[uncompiledAttributes release];
	[super dealloc];
}

- (void) awakeFromNib{
	
	[NSApp setDelegate:self];
	[theList setDataSource:self];
	[theList setDelegate:self];
	[connectSourceScript setDelegate:self];
	[disconnectSourceScript setDelegate:self];
	
	
	NSColor *fontColor = [NSColor colorWithCalibratedRed:0.51 green:0.0 blue:0.53 alpha:1.0];
	NSFont *font = [NSFont fontWithName:@"Courier" size:12.0];
	uncompiledAttributes = [[NSDictionary alloc] initWithDictionary:
		[NSDictionary dictionaryWithObjectsAndKeys:
			font, NSFontAttributeName,
			fontColor,NSForegroundColorAttributeName,
			nil]];
	
	SCDynamicStoreContext context = {
        0, self, NULL, NULL, NULL
    };
	
	dynStore = SCDynamicStoreCreate(kCFAllocatorDefault,
									CFBundleGetIdentifier(CFBundleGetMainBundle()),
									scCallback,
									/*context*/ &context);
	if (!dynStore) {
		NSLog(@"SCDynamicStoreCreate() failed: %s",
			  SCErrorString(SCError()));
		return;
	}
	
	const CFStringRef keys[3] = {
		CFSTR("State:/Network/Interface/en0/Link"),
		CFSTR("State:/Network/Global/IPv4"),
		CFSTR("State:/Network/Interface/en1/AirPort")
	};
	CFArrayRef watchedKeys = CFArrayCreate(kCFAllocatorDefault,
										   (const void **)keys,
										   3,
										   &kCFTypeArrayCallBacks);
	
	if (!SCDynamicStoreSetNotificationKeys(dynStore,
										   (CFArrayRef) watchedKeys,
										   NULL)) {
		
		CFRelease(watchedKeys);
		NSLog(@"SCDynamicStoreSetNotificationKeys() failed: %s",
			  SCErrorString(SCError()));
		CFRelease(dynStore);
		dynStore = NULL;
		return;
	}
	
	/* Status Item */
	if (!([[NSUserDefaults standardUserDefaults] integerForKey:@"disableStatusItem"])){
		statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength] retain];
		
		NSBundle *bundle = [NSBundle mainBundle];
		
		statusImageOn = [[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:@"icon" ofType:@"png"]];
		statusImageOff = [[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:@"icon-off" ofType:@"png"]];
		
		[statusItem setMenu:statusMenu];
		[statusItem setToolTip:@"WiFiScriptor"];
		[statusItem setHighlightMode:YES];
	}
	/********************************/
	
	running = [[NSUserDefaults standardUserDefaults] integerForKey:@"enabled"];
	
	if (!([[NSUserDefaults standardUserDefaults] integerForKey:@"statusItem"])){
		if (!running) {
			[ableMenuItem setTitle:@"Enable"];
			[statusItem setImage:statusImageOff];
			//NSLog(@"WiFiScriptor: Disabled");
		}
		else {
			[ableMenuItem setTitle:@"Disable"];
			[statusItem setImage:statusImageOn];
			//NSLog(@"WiFiScriptor: Enabled");
		}
	}
	
	
	
	CFRelease(watchedKeys);
	
	CFRunLoopSourceRef runLoopSource = SCDynamicStoreCreateRunLoopSource (NULL, dynStore, 0); 
	CFRunLoopAddSource (CFRunLoopGetCurrent (), runLoopSource, kCFRunLoopDefaultMode);
	CFRelease (runLoopSource);
	
	airportStatus = SCDynamicStoreCopyValue(dynStore, CFSTR("State:/Network/Interface/en1/AirPort"));
} 

- (int)numberOfRowsInTableView:(NSTableView *)aTableView {
	return ([ssidDic count]);
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex{	
	NSString *theKey = [aTableColumn identifier];
	return ( [[ssidDic objectAtIndex:rowIndex] objectForKey:theKey]);
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex{
	NSString *theKey = [aTableColumn identifier];
	[[ssidDic objectAtIndex:rowIndex] setObject:anObject forKey:theKey];
	[self newUserDefaults];
}

- (void)newUserDefaults{
	[[NSUserDefaults standardUserDefaults] setObject:(NSArray *)ssidDic forKey:@"ssidData"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

-(IBAction)addSSID:(id)sender{
#if defined DEBUG
	NSLog(@"Attempting to add SSID");	
#endif
	int theRow = [theList selectedRow];
	if (! (++theRow)) {
		theRow = [ssidDic count];
	}
	[ssidDic insertObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
		@"SSID", @"SSID",
		@"description",@"Desc",
		@"--connect script",@"connectSource",
		@"--disconnect ScriptCode",@"disconnectSource",
		nil] atIndex:theRow];
	
	[self newUserDefaults];
	
	[theList reloadData];
	
}

-(IBAction)deleteSSID:(id)sender{
	NSIndexSet *selectedRows = [theList selectedRowIndexes];
	
	unsigned int index = [selectedRows lastIndex];
	
	if (index != NSNotFound){
		while (index != NSNotFound){
			[ssidDic removeObjectAtIndex: index];
			index = [selectedRows indexLessThanIndex: index];
		}
	}
	
	[theList selectRowIndexes:nil byExtendingSelection:NO];
	
	[self newUserDefaults];
	
	[theList reloadData];
	
}

-(IBAction)compileConnectSource:(id)sender{
	[self compileAS:connectSourceScript];
}

-(IBAction)compileDisconnectSource:(id)sender{
	[self compileAS:disconnectSourceScript];
}

-(IBAction)executeConnectSource:(id)sender{
	[self runAS:connectSourceScript];
}

-(IBAction)executeDisconnectSource:(id)sender{
	[self runAS:disconnectSourceScript];
}

-(IBAction)ableItem:(id)sender{
	running = [[NSUserDefaults standardUserDefaults] integerForKey:@"enabled"];
	if (running) {
		running = NO;
		[ableMenuItem setTitle:@"Enable"];
		[statusItem setImage:statusImageOff];
		//NSLog(@"WiFiScriptor: Disabled");
	} else {
		running = YES;
		[ableMenuItem setTitle:@"Disable"];
		[statusItem setImage:statusImageOn];
		//NSLog(@"WiFiScriptor: Enabled");
	}
	[[NSUserDefaults standardUserDefaults] setInteger:running forKey:@"enabled"];
	[[NSUserDefaults standardUserDefaults] synchronize];
#if defined DEBUG
	NSLog(@"%d", running);	
#endif
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification{
	int theRow = [theList selectedRow];
	
	if (theRow != -1) {
		NSAttributedString *connectSource = [[NSAttributedString alloc] 
			initWithString:[[ssidDic objectAtIndex:theRow] objectForKey:@"connectSource"] 
				attributes:uncompiledAttributes];
		[[connectSourceScript textStorage] setAttributedString:connectSource];
		[connectSource release];
		
		NSAttributedString *disconnectSource = [[NSAttributedString alloc] 
			initWithString:[[ssidDic objectAtIndex:theRow] objectForKey:@"disconnectSource"] 
				attributes:uncompiledAttributes];
		[[disconnectSourceScript textStorage] setAttributedString:disconnectSource];
		[disconnectSource release];
	}
}

-(void)compileAS:(NSTextView *)tv{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSString *source;
	source = [tv string];
	NSAppleScript *ascript = [[NSAppleScript alloc] initWithSource:source];
	NSString *errMsg;
	NSDictionary *compileResult;
	
	if ([ascript compileAndReturnError:&compileResult]) {
		errMsg = @"Script compiled correctly, ready for use";
		
		[[tv textStorage] setAttributedString:[ascript richTextSource]];
		
		int theRow = [theList selectedRow];
		
		if ([tv isEqual:connectSourceScript]) {
			[[ssidDic objectAtIndex:theRow] setObject:[[connectSourceScript string] copy] forKey:@"connectSource"];
			[connectResultScript setString: errMsg];
		} else if ([tv isEqual:disconnectSourceScript]){
			[[ssidDic objectAtIndex:theRow] setObject:[[disconnectSourceScript string] copy] forKey:@"disconnectSource"];
			[disconnectResultScript setString: errMsg];
		}
		[self newUserDefaults];	
	} else {
		errMsg = [NSString stringWithFormat:@"Error %@: %@",[compileResult objectForKey:NSAppleScriptErrorNumber],[compileResult objectForKey:NSAppleScriptErrorMessage]];
		
		if ([tv isEqual:connectSourceScript]) {
			[connectResultScript setString: errMsg];
		} else if ([tv isEqual:disconnectSourceScript]){
			[disconnectResultScript setString: errMsg];
		}
		NSAttributedString *uncompiledSource = [[NSAttributedString alloc] initWithString:[tv string] attributes:uncompiledAttributes];
		[[tv textStorage] setAttributedString:uncompiledSource];
		[uncompiledSource release];
		[tv setSelectedRange:[[compileResult objectForKey:NSAppleScriptErrorRange] rangeValue]];	
	}
	NSRunAlertPanel(@"Applescript", errMsg, nil, nil, nil);
	[ascript release];
	[pool release];
}

-(void)runAS:(NSTextView *)tv{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSString *source;
	source = [tv string];
	NSAppleScript *ascript = [[NSAppleScript alloc] initWithSource:source];
	NSString *errMsg;
	NSDictionary *compileResult;
	if ([ascript executeAndReturnError:&compileResult]) {
		errMsg = @"Script executed correctly, ready for compile and save";
		if ([tv isEqual:connectSourceScript]) {
			[connectResultScript setString: errMsg];
		} else if ([tv isEqual:disconnectSourceScript]){
			[disconnectResultScript setString: errMsg];
		}
		
	} else {
		errMsg = [NSString stringWithFormat:@"Error %@: %@",[compileResult objectForKey:NSAppleScriptErrorNumber],[compileResult objectForKey:NSAppleScriptErrorMessage]];
		if ([tv isEqual:connectSourceScript]) {
			[connectResultScript setString: errMsg];
		} else if ([tv isEqual:disconnectSourceScript]){
			[disconnectResultScript setString: errMsg];
		}
	}
	NSRunAlertPanel(@"Applescript", errMsg, nil, nil, nil);
	[ascript release];
	[pool release];
}

- (void)airportStatusChange:(CFDictionaryRef) newValue{
	//NSLog(@"AirPort event");
	CFDataRef newBSSID = CFDictionaryGetValue(newValue, @"BSSID");
	
	if (!(airportStatus && CFEqual(CFDictionaryGetValue(airportStatus, CFSTR("BSSID")), newBSSID))) {
		int status;
		CFNumberRef linkStatus = CFDictionaryGetValue(newValue, @"Link Status");
		if (linkStatus) {
			CFNumberGetValue(linkStatus, kCFNumberIntType, &status);
			NSString *SSID;
			if (status == 1)
			{
				//NSLog(@"statusdict: %@",(NSDictionary *)airportStatus);
				SSID = (NSString *)CFDictionaryGetValue(airportStatus, @"SSID");
				NSLog(@"Disconnected from : %@", SSID);
				[self executeScriptForSSID:SSID :@"disconnectSource"]; 
			}
			else
			{	
				SSID = (NSString *)(CFDictionaryGetValue(newValue, @"SSID"));
				NSLog(@"Connected to : %@", SSID);
				[self executeScriptForSSID:SSID :@"connectSource"]; 
			}
		}
	}
	if (airportStatus)
		CFRelease(airportStatus);
	airportStatus = CFRetain(newValue);
}

-(void)executeScriptForSSID:(NSString *)ssid:(NSString *)script{
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSEnumerator *searchEnum = [ssidDic objectEnumerator];
	BOOL ssidFound = NO;
	NSMutableDictionary *nextSsidDict;
	NSString *source;
	
	while (nextSsidDict = [searchEnum nextObject]) {
		if ([[nextSsidDict objectForKey:@"SSID"] isEqualToString:ssid]) {
			ssidFound = YES;
			source = [nextSsidDict objectForKey:script];
			break;
		}
	}
	
	if (ssidFound) {
		if (running) {
			NSLog(@"%@", source);
			NSAppleScript *as = [[NSAppleScript alloc] initWithSource:source];
			[as executeAndReturnError:nil];
			[as release];
		}
	} else {
		// ssid not found ...
	}
	
	[pool release];
}

- (IBAction)aboutItem:(id)sender{
	[[NSApplication sharedApplication] orderFrontStandardAboutPanel: nil ];
	[NSApp activateIgnoringOtherApps:YES];
}

-(IBAction)prefItem:(id)sender{
	[preferenceWindow makeKeyAndOrderFront:nil];
	[NSApp activateIgnoringOtherApps:YES];
}
@end
