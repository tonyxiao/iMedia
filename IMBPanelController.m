/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2009 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
 The new architecture for version 2.0 was developed by Peter Baumgartner.
 Contributions have also been made by Matt Gough, Martin Wennerberg and others
 as indicated in source files.
 
 The iMedia Browser Framework is licensed under the following terms:
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in all or substantial portions of the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to permit
 persons to whom the Software is furnished to do so, subject to the following
 conditions:
 
	Redistributions of source code must retain the original terms stated here,
	including this list of conditions, the disclaimer noted below, and the
	following copyright notice: Copyright (c) 2005-2009 by Karelia Software et al.
 
	Redistributions in binary form must include, in an end-user-visible manner,
	e.g., About window, Acknowledgments window, or similar, either a) the original
	terms stated here, including this list of conditions, the disclaimer noted
	below, and the aforementioned copyright notice, or b) the aforementioned
	copyright notice and a link to karelia.com/imedia.
 
	Neither the name of Karelia Software, nor Sandvox, nor the names of
	contributors to iMedia Browser may be used to endorse or promote products
	derived from the Software without prior and express written permission from
	Karelia Software or individual contributors, as appropriate.
 
 Disclaimer: THE SOFTWARE IS PROVIDED BY THE COPYRIGHT OWNER AND CONTRIBUTORS
 "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
 LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE,
 AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 LIABLE FOR ANY CLAIM, DAMAGES, OR OTHER LIABILITY, WHETHER IN AN ACTION OF
 CONTRACT, TORT, OR OTHERWISE, ARISING FROM, OUT OF, OR IN CONNECTION WITH, THE
 SOFTWARE OR THE USE OF, OR OTHER DEALINGS IN, THE SOFTWARE.
*/


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBPanelController.h"
#import "IMBParserController.h"
#import "IMBLibraryController.h"
#import "IMBNodeViewController.h"
#import "IMBImageViewController.h"
#import "IMBAudioViewController.h"
#import "IMBMovieViewController.h"
#import "IMBConfig.h"
#import "IMBCommon.h"
#import "NSWorkspace+iMedia.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark GLOBALS

static IMBPanelController* sSharedPanelController = nil;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBPanelController

@synthesize delegate = _delegate;
@synthesize mediaTypes = _mediaTypes;
@synthesize viewControllers = _viewControllers;
@synthesize loadedLibraries = _loadedLibraries;
@synthesize oldMediaType = _oldMediaType;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

+ (IMBPanelController*) sharedPanelController
{
	if (sSharedPanelController == nil)
	{
		sSharedPanelController = [self sharedPanelControllerWithDelegate:nil mediaTypes:[NSArray arrayWithObjects:
			kIMBMediaTypeImage,
			kIMBMediaTypeAudio,
			kIMBMediaTypeMovie,
			nil]];
	}
	
	return sSharedPanelController;
}


+ (IMBPanelController*) sharedPanelControllerWithDelegate:(id)inDelegate mediaTypes:(NSArray*)inMediaTypes
{
	if (sSharedPanelController == nil)
	{
		sSharedPanelController = [[IMBPanelController alloc] init];
		sSharedPanelController.delegate = inDelegate;
		sSharedPanelController.mediaTypes = inMediaTypes;
		
		[sSharedPanelController loadControllers];
	}

	return sSharedPanelController;
}


//----------------------------------------------------------------------------------------------------------------------


- (id) init
{
	if (self = [super initWithWindowNibName:@"IMBPanel"])
	{
		self.viewControllers = [NSMutableArray array];
		self.loadedLibraries = [NSMutableDictionary dictionary];
		
		[[NSNotificationCenter defaultCenter] 
			addObserver:self 
			selector:@selector(applicationWillTerminate:) 
			name:NSApplicationWillTerminateNotification 
			object:nil];
	}
	
	return self;
}


- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	IMBRelease(_mediaTypes);
	IMBRelease(_viewControllers);
	IMBRelease(_loadedLibraries);
	IMBRelease(_oldMediaType);
	
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 


- (void) loadControllers
{
	IMBLibraryController* libraryController = nil;
	IMBNodeViewController* nodeViewController = nil;
	IMBObjectViewController* objectViewController = nil;
	
	// Load the parsers...
	
	IMBParserController* parserController = [IMBParserController sharedParserController];
	[parserController setDelegate:self.delegate];
	[parserController loadParsers];

	for (NSString* mediaType in self.mediaTypes)
	{
		// Load the library for each media type...
		
		libraryController = [IMBLibraryController sharedLibraryControllerWithMediaType:mediaType];
		[libraryController setDelegate:self.delegate];

		// Create the node view controllers for each media type...
		
		nodeViewController = [IMBNodeViewController viewControllerForLibraryController:libraryController];

		// Create the object view controllers for each media type...
		
		if ([mediaType isEqualToString:kIMBMediaTypeImage])
		{
			objectViewController = [IMBImageViewController viewControllerForLibraryController:libraryController];
		}
		else if ([mediaType isEqualToString:kIMBMediaTypeAudio])
		{
			objectViewController = [IMBAudioViewController viewControllerForLibraryController:libraryController];
		}
		else if ([mediaType isEqualToString:kIMBMediaTypeMovie])
		{
			objectViewController = [IMBMovieViewController viewControllerForLibraryController:libraryController];
		}
		
		// Store the object view controller in an array. Note that the node view controller is attached to the
		// object view controller, so we do not need to store it separately...
		
		objectViewController.nodeViewController = nodeViewController;
		[self.viewControllers addObject:objectViewController];
	}
}


//----------------------------------------------------------------------------------------------------------------------


- (void) windowDidLoad
{
	[ibTabView setDelegate:self];
	[ibToolbar setSizeMode:NSToolbarSizeModeSmall];
	[ibToolbar setAllowsUserCustomization:NO];
	
	// Create a tab for each controller and install the subviews in it...
		
	for (IMBObjectViewController* objectViewController in self.viewControllers)
	{
		IMBNodeViewController* nodeViewController = objectViewController.nodeViewController;
		NSString* mediaType = nodeViewController.mediaType;

		NSView* nodeView = [nodeViewController view];
		NSView* containerView = [nodeViewController objectContainerView];
		NSView* objectView = [objectViewController view];
		
		[nodeView setFrame:[ibTabView bounds]];
		[objectView setFrame:[containerView bounds]];
		[containerView addSubview:objectView];

		NSTabViewItem* item = [[NSTabViewItem alloc] initWithIdentifier:mediaType];
		[item setLabel:mediaType];
		[item setView:nodeView];
		[ibTabView addTabViewItem:item];
		[item release];
	}
		
	// Restore window size and selected tab...
	
	NSString* frame = [IMBConfig prefsValueForKey:@"windowFrame"];
	if (frame) [self.window setFrame:NSRectFromString(frame) display:YES animate:NO];

	NSString* mediaType = [IMBConfig prefsValueForKey:@"selectedMediaType"];
	if (mediaType) [ibTabView selectTabViewItemWithIdentifier:mediaType];
}


//----------------------------------------------------------------------------------------------------------------------


// We need to save preferences before tha app quits...
		
- (void) applicationWillTerminate:(NSNotification*)inNotification
{
	NSString* frame = NSStringFromRect(self.window.frame);
	if (frame) [IMBConfig setPrefsValue:frame forKey:@"windowFrame"];
	
	NSString* mediaType = ibTabView.selectedTabViewItem.identifier;
	if (mediaType) [IMBConfig setPrefsValue:mediaType forKey:@"selectedMediaType"];
}


//----------------------------------------------------------------------------------------------------------------------


- (IBAction) showWindow:(id)inSender
{
	[self.window makeKeyAndOrderFront:nil];
}


- (IBAction) hideWindow:(id)inSender
{
	[self.window orderOut:nil];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark NSToolbarDelegate


- (NSArray*) toolbarAllowedItemIdentifiers:(NSToolbar*)inToolbar
{
	return self.mediaTypes;
}

- (NSArray*) toolbarDefaultItemIdentifiers:(NSToolbar*)inToolbar
{
	return self.mediaTypes;
}

- (NSArray*) toolbarSelectableItemIdentifiers:(NSToolbar*)inToolbar
{
	return self.mediaTypes;
}


- (NSToolbarItem*) toolbar:(NSToolbar*)inToolbar itemForItemIdentifier:(NSString*)inIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
	NSImage* icon = nil;
	NSString* name = nil;
	
	for (IMBObjectViewController* controller in self.viewControllers)
	{
		if ([controller.mediaType isEqualToString:inIdentifier])
		{
			name = [controller displayName];
			icon = [controller icon];
			[icon setScalesWhenResized:YES];
			[icon setSize:NSMakeSize(32,32)];
		}
	}

	NSToolbarItem* item = [[[NSToolbarItem alloc] initWithItemIdentifier:inIdentifier] autorelease];
	if (icon) [item setImage:icon];
	if (name) [item setLabel:name];
	[item setAction:@selector(selectTabViewItemWithIdentifier:)];
	[item setTarget:self];
	
	return item;
}


- (IBAction) selectTabViewItemWithIdentifier:(id)inSender
{
	NSToolbarItem* item = (NSToolbarItem*)inSender;
	return [ibTabView selectTabViewItemWithIdentifier:item.itemIdentifier];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark NSTabViewDelegate


// Ask the delegate whether we are allowed to switch to another media type...

- (BOOL) tabView:(NSTabView*)inTabView shouldSelectTabViewItem:(NSTabViewItem*)inTabViewItem
{
	NSString* mediaType = inTabViewItem.identifier;
	
	if (_delegate!=nil && [_delegate respondsToSelector:@selector(controller:shouldShowPanelForMediaType:)])
	{
		return [_delegate controller:self shouldShowPanelForMediaType:mediaType];
	}
	
	return YES;
}


// We are about to switch tabs...

- (void) tabView:(NSTabView*)inTabView willSelectTabViewItem:(NSTabViewItem*)inTabViewItem
{
	self.oldMediaType = inTabView.selectedTabViewItem.identifier;
	NSString* newMediaType = inTabViewItem.identifier;

	// If the library for the new tab has been loaded yet then do it now...
	
	if ([_loadedLibraries objectForKey:newMediaType] == nil)
	{
		IMBLibraryController* libraryController = [IMBLibraryController sharedLibraryControllerWithMediaType:newMediaType];
		[libraryController reload];
		[_loadedLibraries setObject:newMediaType forKey:newMediaType];
	}
	
	// Notify the delegate...

	if (_delegate!=nil && [_delegate respondsToSelector:@selector(controller:willHidePanelForMediaType:)])
	{
		return [_delegate controller:self willHidePanelForMediaType:_oldMediaType];
	}

	if (_delegate!=nil && [_delegate respondsToSelector:@selector(controller:willShowPanelForMediaType:)])
	{
		return [_delegate controller:self willShowPanelForMediaType:newMediaType];
	}
}


// Notify the delegate that we did switch...

- (void) tabView:(NSTabView*)inTabView didSelectTabViewItem:(NSTabViewItem*)inTabViewItem
{
	NSString* newMediaType = inTabViewItem.identifier;
	
	if (_delegate!=nil && [_delegate respondsToSelector:@selector(controller:didHidePanelForMediaType:)])
	{
		return [_delegate controller:self didHidePanelForMediaType:_oldMediaType];
	}

	if (_delegate!=nil && [_delegate respondsToSelector:@selector(controller:didShowPanelForMediaType:)])
	{
		return [_delegate controller:self didShowPanelForMediaType:newMediaType];
	}
}


//----------------------------------------------------------------------------------------------------------------------


@end
