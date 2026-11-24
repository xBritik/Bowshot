// Face buttons of the shared GameController adapter (pad_apple.h) with fake pads: by position on most pads, by label on a Nintendo pad; no physical controller is needed.
#import "../pad_apple.h"
#include <assert.h>
#include <stdio.h>

@interface TestButton : NSObject
@property BOOL isPressed;
@end
@implementation TestButton
@end
@interface TestController : NSObject
@property NSString *productCategory;
@end
@implementation TestController
@end
@interface TestPad : NSObject
@property TestController *controller;
@property TestButton *buttonA, *buttonB, *buttonX, *buttonY;
@end
@implementation TestPad
@end

// The Switch buttons of a pad of this category with only the named GameController button pressed
static uint64_t face(NSString *category, char pressed) {
    TestPad *g = [TestPad new]; g.controller = [TestController new]; g.controller.productCategory = category;
    g.buttonA = [TestButton new]; g.buttonB = [TestButton new]; g.buttonX = [TestButton new]; g.buttonY = [TestButton new];
    TestButton *b = pressed == 'A' ? g.buttonA : pressed == 'B' ? g.buttonB : pressed == 'X' ? g.buttonX : g.buttonY;
    b.isPressed = YES;
    return dm_pad_face((GCExtendedGamepad *)(id)g);
}

int main(void) { @autoreleasepool {
    for (NSString *k in @[@"Xbox One", @"DualSense", @"HID"]) {   // by position: buttonA bottom (B), buttonB right (A), buttonX left (Y), buttonY top (X)
        assert(face(k, 'A') == DM_BTN_B); assert(face(k, 'B') == DM_BTN_A); assert(face(k, 'X') == DM_BTN_Y); assert(face(k, 'Y') == DM_BTN_X);
    }
    assert(face(nil, 'B') == DM_BTN_A);   // no category: by position
    for (NSString *k in @[@"Switch Pro Controller", @"Nintendo Switch Joy-Con (L/R)", @"Nintendo Switch Joy-Con (R)"]) {   // by label
        assert(face(k, 'A') == DM_BTN_A); assert(face(k, 'B') == DM_BTN_B); assert(face(k, 'X') == DM_BTN_X); assert(face(k, 'Y') == DM_BTN_Y);
    }
    for (NSString *lay in @[@"xbox", @"playstation"]) {   // DM_PAD_LAYOUT: every pad by its printed labels
        setenv("DM_PAD_LAYOUT", lay.UTF8String, 1);
        for (id c in @[@"Xbox One", @"DualSense", [NSNull null]]) {
            NSString *k = [c isKindOfClass:[NSString class]] ? c : nil;
            assert(face(k, 'A') == DM_BTN_A); assert(face(k, 'B') == DM_BTN_B); assert(face(k, 'X') == DM_BTN_X); assert(face(k, 'Y') == DM_BTN_Y);
        }
    }
    setenv("DM_PAD_LAYOUT", "auto", 1);   // every pad by its labels, the icons' layout is the one found
    assert(dm_pad_face_layout() == DM_PAD_LAYOUT_SWITCH);   // no pad known yet: by position, the Switch's icons
    assert(face(@"DualSense", 'A') == DM_BTN_B);
    dm_pad_auto_layout = DM_PAD_LAYOUT_PLAYSTATION; assert(face(@"DualSense", 'A') == DM_BTN_A); assert(face(@"Xbox One", 'Y') == DM_BTN_Y);
    dm_pad_auto_layout = DM_PAD_LAYOUT_SWITCH; assert(face(@"Xbox One", 'A') == DM_BTN_B);   // the Switch's layout found: by position
    for (NSString *k in @[@"DualSense", @"DualShock 4", @"Xbox One", @"HID", @"Switch Pro Controller"]) {
        TestController *tc = [TestController new]; tc.productCategory = k;
        int want = [k hasPrefix:@"Dual"] ? DM_PAD_LAYOUT_PLAYSTATION : [k hasPrefix:@"Switch"] ? DM_PAD_LAYOUT_SWITCH : DM_PAD_LAYOUT_XBOX;
        assert(dm_pad_layout_of((GCController *)(id)tc) == want);
        dm_pad_auto_layout = want; assert(dm_pad_face_layout() == want);
    }
    dm_pad_auto_layout = -1;
    setenv("DM_PAD_LAYOUT", "bogus", 1); assert(face(@"DualSense", 'A') == DM_BTN_B);   // unknown: the Switch's
    unsetenv("DM_PAD_LAYOUT"); assert(face(@"DualSense", 'A') == DM_BTN_B);
    TestPad *g = [TestPad new];   // nothing pressed, buttons nil: none
    assert(dm_pad_face((GCExtendedGamepad *)(id)g) == 0);
    printf("t_pad_apple OK\n");
} return 0; }
