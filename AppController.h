/* AppController */

#import <Cocoa/Cocoa.h>
#import <SystemConfiguration/SystemConfiguration.h>


static CFDictionaryRef airportStatus;

@interface AppController : NSObject
{
	IBOutlet NSTableView *theList;
	
	IBOutlet NSWindow			*preferenceWindow;
	IBOutlet NSTextView			*connectSourceScript;
	IBOutlet NSTextView			*connectResultScript;
	IBOutlet NSTextView			*disconnectSourceScript;
	IBOutlet NSTextView			*disconnectResultScript;
	IBOutlet NSMenu				*statusMenu;
	IBOutlet NSMenuItem			*ableMenuItem;
	
			 NSStatusItem		*statusItem;
			 NSImage			*statusImageOn;
			 NSImage			*statusImageOff;
	
			 BOOL				running;
			 NSDictionary		*uncompiledAttributes;
	
			 NSMutableArray		*ssidDic;
	
			 SCDynamicStoreRef  dynStore;
}
-(IBAction)addSSID:(id)sender;
-(IBAction)deleteSSID:(id)sender;
-(IBAction)compileConnectSource:(id)sender;
-(IBAction)compileDisconnectSource:(id)sender;
-(IBAction)executeConnectSource:(id)sender;
-(IBAction)executeDisconnectSource:(id)sender;
-(IBAction)ableItem:(id)sender;
-(IBAction)aboutItem:(id)sender;
-(IBAction)prefItem:(id)sender;

-(void)runAS:(NSTextView *)tv;
-(void)compileAS:(NSTextView *)tv;
-(void)newUserDefaults;
-(void)airportStatusChange:(CFDictionaryRef) newValue;
-(void)executeScriptForSSID:(NSString *)ssid:(NSString *)script;
@end
