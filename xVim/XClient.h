// Created by Alex Gordon on stardate -311147.99
// This is an alternative to swizzling that cooperative editors can use
#import <Cocoa/Cocoa.h>

@class XTextViewBridge;

@interface XClient : NSObject {
    BOOL isActive;
	XTextViewBridge* bridge;
}

@property (assign) BOOL isActive;
@property (readonly) XTextViewBridge* bridge;

- (id)initWithTextView:(NSTextView*)tv;

// Returns YES if the event if the caller should continue processing the event
// Returns NO if the event should be blocked
- (BOOL)keyDown:(NSEvent*)event;

- (NSRect)drawInsertionPointInRect:(NSRect)rect color:(NSColor *)color turnedOn:(BOOL)turnedOn;
- (NSRect)_drawInsertionPointInRect:(NSRect)rect color:(NSColor *)color;

- (void)selectionRangeForProposedRange:(NSRange)proposed granularity:(NSSelectionGranularity)granularity;

- (NSArray *)textView:(NSTextView *)tv willChangeSelectionFromCharacterRanges:(NSArray *)oldSelectedCharRanges toCharacterRanges:(NSArray *)newSelectedCharRanges;
- (void)textViewDidChangeSelection:(NSNotification *)notif;

@end


@protocol XClientTextView <NSObject>

- (void)handleVimKeyEvent:(NSEvent*)event;

@end
