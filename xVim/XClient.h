// Created by Alex Gordon on stardate -311147.99
// This is an alternative to swizzling that cooperative editors can use
#import <Cocoa/Cocoa.h>

@class XTextViewBridge;

@interface XClient : NSObject {
	XTextViewBridge* bridge;
}

@property (readonly) XTextViewBridge* bridge;

- (id)initWithTextView:(NSTextView*)tv;

// Returns the new event to use. If it returns nil, then the event should be blocked
- (NSEvent*)keyDown:(NSEvent*)event;

- (NSRect)drawInsertionPointInRect:(NSRect)rect color:(NSColor *)color turnedOn:(BOOL)turnedOn;
- (NSRect)_drawInsertionPointInRect:(NSRect)rect color:(NSColor *)color;

- (void)selectionRangeForProposedRange:(NSRange)proposed granularity:(NSSelectionGranularity)granularity

- (NSArray *)textView:(NSTextView *)tv willChangeSelectionFromCharacterRanges:(NSArray *)oldSelectedCharRanges toCharacterRanges:(NSArray *)newSelectedCharRanges;
- (void)textViewDidChangeSelection:(NSNotification *)notif;

@end
