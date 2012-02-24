// Created by Alex Gordon on stardate -311147.99
// This is an alternative to XGlobal that cooperative editors can use
#import "XClient.h"
#import "XGlobal.h"

@implementation XClient

@synthesize bridge;

- (id)initWithTextView:(NSTextView*)tv {
    self = [super init];
    if (!self)
        return nil;
    
    bridge = [[XTextViewBridge alloc] initWithTextView:tv];
    
    return self;
}

// Returns the new event to use. If it returns nil, then the event should be blocked
- (NSEvent*)keyDown:(NSEvent*)event {
    [bridge processKeyEvent:event];
    return nil;
}

- (NSRect)drawInsertionPointInRect:(NSRect)rect color:(NSColor *)color turnedOn:(BOOL)turnedOn {
    configureInsertionPointRect(self, &rect);
    return rect;
}
- (NSRect)_drawInsertionPointInRect:(NSRect)rect color:(NSColor *)color {
    configureInsertionPointRect(self, &rect);
    return rect;
}

- (void)selectionRangeForProposedRange:(NSRange)proposed granularity:(NSSelectionGranularity)granularity {
    [[bridge vimController] selRangeForProposed:proposed];
}

- (NSArray *)textView:(NSTextView *)tv willChangeSelectionFromCharacterRanges:(NSArray *)oldSelectedCharRanges toCharacterRanges:(NSArray *)newSelectedCharRanges {
    
    return [[bridge vimController] selectionChangedFrom:oldRanges to:newRanges];
}

- (void)textViewDidChangeSelection:(NSNotification *)notif {
    [[bridge vimController] didChangedSelection];
}

@end