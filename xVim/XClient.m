// Created by Alex Gordon on stardate -311147.99
// This is an alternative to XGlobal that cooperative editors can use
#ifdef __LP64__
#import "XClient.h"
#import "XGlobal.h"
#import "XTextViewBridge.h"
#import "XVimController.h"
#import "XVimMode.h"

typedef struct {
    BOOL useStandard;
    NSRect rect;
    CGFloat alpha;
    BOOL shouldFrame;
} XInsertionPoint;

/*
typedef enum e_VimMode
{
    InsertMode   = 0, // Insertion-point cursor
    NormalMode   = 1, // Block cursor
    VisualMode   = 2,
    ExMode       = 3,
    ReplaceMode  = 4, // Underline cursor
    VimModeCount,
    
    // Submode
    NoSubMode,
    VisualLineMode,
    SingleReplaceMode
} VimMode;
*/

static XInsertionPoint XInsertionPointForTextView(XTextViewBridge* bridge, NSTextView* tv, VimMode mode, NSRect suggestedRect) {
    
    XInsertionPoint ip;
    ip.useStandard = YES;
    ip.shouldFrame = YES;
    
    // Get the bounding rect of the character
    NSRect b;
    
    NSRange range  = [tv selectedRange];
    NSString* string = [[tv textStorage] string];
    
    NSSize stringSize = [@" " sizeWithAttributes:[tv typingAttributes]];
    CGFloat emptyWidth = stringSize.width;
    
    suggestedRect.origin.y -= [tv textContainerOrigin].y;
    
    if (mode == VisualMode)
        return ip;
    else if (range.location >= [string length]) {
        b = suggestedRect;
        b.size.width = emptyWidth;
    }
    else {
        b = suggestedRect;
        
        unichar ch = [string characterAtIndex:range.location];
        if ((ch >= 0xA && ch <= 0xD) || ch == 0x85) {
            b.size.width = emptyWidth;
        }
        else {
            NSUInteger glyphIndex = [[tv layoutManager] glyphIndexForCharacterAtIndex:range.location];
            b = [[tv layoutManager] boundingRectForGlyphRange:NSMakeRange(glyphIndex, 1) inTextContainer:[tv textContainer]];
        }
    }
    
    ip.alpha = 1.0;
    ip.rect = b;
    ip.useStandard = NO;
    
    if (mode == NormalMode) {
        if ([[bridge vimController] isWaitingForMotion]) {
            CGFloat h = floor(ip.rect.size.height * 0.4);
            ip.rect.origin.y += ip.rect.size.height - h;
            ip.rect.size.height = h;
            ip.shouldFrame = NO;
        }
    }
    else if (mode == InsertMode) {
        ip.useStandard = YES;
    }
    else if (mode == ReplaceMode || mode == SingleReplaceMode) {
        ip.rect.origin.y += ip.rect.size.height - 3;
        ip.rect.size.height = 3;
        ip.shouldFrame = NO;
    }
    else {
        // No idea?
        ip.useStandard = YES;
    }
    ip.rect.origin.y += [tv textContainerOrigin].y;
    
    return ip;
}


@implementation XClient

@synthesize bridge;

- (id)initWithTextView:(NSTextView*)tv {
    self = [super init];
    if (!self)
        return nil;
    
    bridge = [[XTextViewBridge alloc] initWithTextView:tv];
    lastWasInactive = YES;
    
    return self;
}

- (BOOL)isActive {
//    // Only supported on 10.7
//    if (!NSClassFromString(@"NSLinguisticTagger"))
//        return NO;
    
    BOOL isActive = [(id<XClientTextView>)[bridge targetView] isVimModeActive];
    
    if (isActive && lastWasInactive) {
        // Switch to normal/visual mode, whichever is more appropriate
        NSRange sel = [[bridge targetView] selectedRange];
        if (sel.location > 0 && sel.location == [[[[bridge targetView] textStorage] string] length])
            [[bridge vimController] switchToMode:InsertMode];
        else if (sel.length > 0)
            [[bridge vimController] switchToMode:VisualMode];
        else
            [[bridge vimController] switchToMode:NormalMode];
        lastWasInactive = NO;
    }
    else if (!isActive) {
        lastWasInactive = YES;
    }
    
    return isActive;
}
- (NSString*)vimModeName {
    VimMode mode = [[bridge vimController] mode];
    XVimModeHandler* handler = [[bridge vimController] currentHandler];
    switch (mode) {
        case NormalMode:
            return @"Normal";
        
        case VisualMode:
            if ([(XVimVisualModeHandler*)handler isLineMode])
                return @"Visual Line";
            return @"Visual";
        
        case InsertMode:
            return @"Insert";
        
        case ExMode:
            return @"Ex";
        
        case ReplaceMode:
            if ([[bridge vimController] isWaitingForMotion])
                return [NSString stringWithFormat:@"Replace%C", 0x2026]; 
            return @"Replace";
        default:
            return nil;
    }
    return nil;
}

- (BOOL)keyDown:(NSEvent*)event {
    if (!self.isActive)
        return YES;
    
    [bridge processKeyEvent:event];
    
    return NO;
}

- (void)blankCursor:(NSRect)r {
    
    if (!NSEqualRects(lastDrawnRect, NSZeroRect))
        [[bridge targetView] setNeedsDisplayInRect:NSIntegralRect(lastDrawnRect) avoidAdditionalLayout:YES];
}
- (BOOL)drawCursor:(NSRect)r {
    
    VimMode mode = [[bridge vimController] mode];
    XInsertionPoint ip = XInsertionPointForTextView(bridge, [bridge targetView], mode, r);
    if (ip.useStandard) {
        lastDrawnRect = NSZeroRect;
        return YES;
    }
    
    NSColor* cursorForeground = [(id<XClientTextView>)[bridge targetView] cursorColor];
    NSColor* cursorBackground = [(id<XClientTextView>)[bridge targetView] cursorBackgroundColor];
    
    NSColor* color = cursorForeground;
    CGFloat alpha = [color alphaComponent] * ip.alpha;
    color = [color colorWithAlphaComponent:1.0];
    color = [cursorBackground blendedColorWithFraction:alpha ofColor:color];
    [color set];
    
    if (ip.shouldFrame)
        NSFrameRectWithWidthUsingOperation(ip.rect, 1, NSCompositeSourceOver);
    else
        NSRectFillUsingOperation(ip.rect, NSCompositeSourceOver);
    lastDrawnRect = ip.rect;
    return NO;
}
- (void)drawInsertionPointInRect:(NSRect)rect color:(NSColor *)color turnedOn:(BOOL)turnedOn shouldUseStandard:(BOOL*)shouldUseStandard {
    if (shouldUseStandard) *shouldUseStandard = YES;
    if (self.isActive) {
        configureInsertionPointRect(bridge, [bridge targetView], &rect);
        if (turnedOn) {
            if (![self drawCursor:rect] && shouldUseStandard)
                *shouldUseStandard = NO;
        }
        else {
            [self blankCursor:rect];
            //[[bridge targetView] setNeedsDisplayInRect:rect avoidAdditionalLayout:YES];
        }
    }
}
- (void)_drawInsertionPointInRect:(NSRect)rect color:(NSColor *)color shouldUseStandard:(BOOL*)shouldUseStandard {
    if (shouldUseStandard) *shouldUseStandard = YES;
    if (self.isActive) {
        configureInsertionPointRect(bridge, [bridge targetView], &rect);
        if (![self drawCursor:rect] && shouldUseStandard)
            *shouldUseStandard = NO;
    }
}

- (void)selectionRangeForProposedRange:(NSRange)proposed granularity:(NSSelectionGranularity)granularity {
    if (self.isActive)
        [[bridge vimController] selRangeForProposed:proposed];
}

- (NSArray *)textView:(NSTextView *)tv willChangeSelectionFromCharacterRanges:(NSArray *)oldRanges toCharacterRanges:(NSArray *)newRanges {
    
    if (!self.isActive)
        return newRanges;
    return [[bridge vimController] selectionChangedFrom:oldRanges to:newRanges];
}

- (void)textViewDidChangeSelection:(NSNotification *)notif {
    if (self.isActive)
        [[bridge vimController] didChangedSelection];
}

@end

#endif
