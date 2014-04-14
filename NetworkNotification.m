//
//  NetworkNotification.m
//  NetworkChanged2
//
//  Created by Andrew James on 7/04/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "NetworkNotification.h"

static void scCallback (SCDynamicStoreRef store, CFArrayRef changedKeys, 
						void *info)
{
#pragma unused(info)
	
	NetworkNotification *controller = (NetworkNotification *)info;
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

@implementation NetworkNotification
-(void)awakeFromNib{
	
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
	
	CFRelease(watchedKeys);
	
	CFRunLoopSourceRef runLoopSource = SCDynamicStoreCreateRunLoopSource (NULL, dynStore, 0); 
	CFRunLoopAddSource (CFRunLoopGetCurrent (), runLoopSource, kCFRunLoopDefaultMode);
	CFRelease (runLoopSource);
	
	airportStatus = SCDynamicStoreCopyValue(dynStore, CFSTR("State:/Network/Interface/en1/AirPort"));
	
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

@end
