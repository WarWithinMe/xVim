// Created by Alex Gordon on stardate -311147.99
// This is an alternative to swizzling that cooperative editors can use
#import <Cocoa/Cocoa.h>

@class XTextViewBridge;

@interface XClient : NSObject {
	XTextViewBridge* bridge;
    
    NSRect lastDrawnRect;
    BOOL lastWasInactive;
}

@property (readonly) BOOL isActive;
@property (readonly) XTextViewBridge* bridge;

- (id)initWithTextView:(NSTextView*)tv;

// Returns YES if the event if the caller should continue processing the event
// Returns NO if the event should be blocked
- (BOOL)keyDown:(NSEvent*)event;

- (void)drawInsertionPointInRect:(NSRect)rect color:(NSColor *)color turnedOn:(BOOL)turnedOn shouldUseStandard:(BOOL*)shouldUseStandard;
- (void)_drawInsertionPointInRect:(NSRect)rect color:(NSColor *)color shouldUseStandard:(BOOL*)shouldUseStandard;

- (void)selectionRangeForProposedRange:(NSRange)proposed granularity:(NSSelectionGranularity)granularity;

- (NSArray *)textView:(NSTextView *)tv willChangeSelectionFromCharacterRanges:(NSArray *)oldSelectedCharRanges toCharacterRanges:(NSArray *)newSelectedCharRanges;
- (void)textViewDidChangeSelection:(NSNotification *)notif;
- (BOOL)drawCursor:(NSRect)r;

@end


@protocol XClientTextView <NSObject>

- (NSColor*)cursorColor;
- (NSColor*)cursorBackgroundColor;
- (void)handleVimKeyEvent:(NSEvent*)event;
- (BOOL)isVimModeActive;

@end
