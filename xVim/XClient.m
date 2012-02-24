// Created by Alex Gordon on stardate -311147.99
// This is an alternative to XGlobal that cooperative editors can use
#import "XClient.h"
#import "XGlobal.h"
#import "XTextViewBridge.h"
#import "XVimController.h"

@implementation XClient

@synthesize isActive;
@synthesize bridge;

- (id)initWithTextView:(NSTextView*)tv {
    self = [super init];
    if (!self)
        return nil;
    
    bridge = [[XTextViewBridge alloc] initWithTextView:tv];
    
    return self;
}

// Returns the new event to use. If it returns nil, then the event should be blocked
- (BOOL)keyDown:(NSEvent*)event {
    if (!isActive)
        return YES;
    [bridge processKeyEvent:event];
    return NO;
}

- (NSRect)drawInsertionPointInRect:(NSRect)rect color:(NSColor *)color turnedOn:(BOOL)turnedOn {
    if (isActive)
        configureInsertionPointRect([bridge targetView], &rect);
    return rect;
}
- (NSRect)_drawInsertionPointInRect:(NSRect)rect color:(NSColor *)color {
    if (isActive)
        configureInsertionPointRect([bridge targetView], &rect);
    return rect;
}

- (void)selectionRangeForProposedRange:(NSRange)proposed granularity:(NSSelectionGranularity)granularity {
    if (isActive)
        [[bridge vimController] selRangeForProposed:proposed];
}

- (NSArray *)textView:(NSTextView *)tv willChangeSelectionFromCharacterRanges:(NSArray *)oldRanges toCharacterRanges:(NSArray *)newRanges {
    
    if (!isActive)
        return newRanges;
    return [[bridge vimController] selectionChangedFrom:oldRanges to:newRanges];
}

- (void)textViewDidChangeSelection:(NSNotification *)notif {
    if (isActive)
        [[bridge vimController] didChangedSelection];
}

@end
