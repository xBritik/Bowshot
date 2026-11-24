// A physical controller's face buttons as Switch buttons, shared by the Mac front end (front_mac.m) and the iOS gamepad (DmGamepad.m). GameController names most pads' face
// buttons by position, as on an Xbox pad (buttonA bottom, buttonB right, buttonX left, buttonY top), but a Nintendo pad's by their printed labels (buttonA is the right
// button, marked A): a Switch Pro Controller (or a pad that presents itself as one) and Joy-Con (productCategory "Nintendo Switch Joy-Con (L)", "(R)", "(L/R)").
// The Switch's layout is right A, bottom B, top X, left Y, so a Nintendo pad maps name for name and any other pad by position. Checked with a Pro Controller on the Mac
// and on iOS (PR #650). Open: a single Joy-Con held sideways is matched too and has not been tried; if GameController keeps its labels there instead of turning them
// with the controller, its face buttons come out a quarter turn off.
#pragma once
#import <GameController/GameController.h>
#include <stdint.h>
#include "dm_input.h"

static inline int dm_pad_labelled(GCController *c) {
    NSString *k = c.productCategory;
    return [k isEqualToString:@"Switch Pro Controller"] || [k containsString:@"Joy-Con"];
}
// DM_PAD_LAYOUT=xbox / playstation / auto (dm_input.h) maps every pad by its printed labels, as a Nintendo pad always is.
// The layout a pad's own labels and icons belong to: a Nintendo pad the Switch's, a DualShock 4 / DualSense / PlayStation pad PlayStation's, any other (Xbox, generic) Xbox's.
static inline int dm_pad_layout_of(GCController *c) {
    if (dm_pad_labelled(c)) return DM_PAD_LAYOUT_SWITCH;
    NSString *k = c.productCategory ?: @"";
    if ([k isEqualToString:GCProductCategoryDualSense] || [k isEqualToString:GCProductCategoryDualShock4] || [k localizedCaseInsensitiveContainsString:@"PlayStation"]) return DM_PAD_LAYOUT_PLAYSTATION;
    return DM_PAD_LAYOUT_XBOX;
}
// DM_PAD_LAYOUT=auto: the first controller found with an extended gamepad decides, once (the icons are loaded with it); none: unknown, the Switch's. Returns the layout in force, -1 for none known.
static inline int dm_pad_auto_update(NSArray<GCController *> *list, GCController *gone) {
    if (dm_pad_auto_layout >= 0) return dm_pad_auto_layout;   // decided: later pads, of any kind, and a pad that leaves change nothing
    for (GCController *c in list) if (c != gone && c.extendedGamepad) { dm_pad_auto_layout = dm_pad_layout_of(c); break; }
    return dm_pad_auto_layout;
}
// DM_BTN_A / B / X / Y of the pad's pressed face buttons
static inline uint64_t dm_pad_face(GCExtendedGamepad *g) {
    GCControllerButtonInput *a = g.buttonA, *b = g.buttonB, *x = g.buttonX, *y = g.buttonY;
    if (!dm_pad_labelled(g.controller) && !dm_pad_labels_mode()) { GCControllerButtonInput *t = a; a = b; b = t; t = x; x = y; y = t; }   // by position: right A, bottom B, top X, left Y
    return (a.isPressed ? DM_BTN_A : 0) | (b.isPressed ? DM_BTN_B : 0) | (x.isPressed ? DM_BTN_X : 0) | (y.isPressed ? DM_BTN_Y : 0);
}
