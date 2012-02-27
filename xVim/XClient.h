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

// Let the text view customize the cursor color
- (NSColor*)cursorColor;
- (NSColor*)cursorBackgroundColor;

// Send a key event back to the text view
- (void)handleVimKeyEvent:(NSEvent*)event;

// Give the text view a chance to override VIM mode, i.e. if the user turns it off
- (BOOL)isVimModeActive;

// Notify the text view that the mode has changed, so it can
- (void)vimModeDidChange;

@end
