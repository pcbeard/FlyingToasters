//
//  FlyingToasterScreenSaverView.m
//  Flying Toasters
//
//  Created by Robert Venturini on 3/9/19.
//  Copyright © 2019 Robert Venturini. All rights reserved.
//

#import "FlyingToasterPreferencesController.h"
#import "FlyingToastersView.h"
#import "FlyingToasterScreenSaverView.h"
#import <CoreFoundation/CFCGTypes.h>

@interface FlyingToasterScreenSaverView ()
@property (strong) FlyingToastersView* ftv;
@property (strong) FlyingToasterPreferencesController* prefsController;
@end

@implementation FlyingToasterScreenSaverView

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview
{
    if (self = [super initWithFrame:frame isPreview:isPreview]) {
        if (isPreview) {
            _ftv = [[FlyingToastersView alloc] initWithFrame:frame];
            [self addSubview:_ftv];
        }
    }
    return self;
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    
    if (!self.isPreview) {
        // idea:  lazily create the sub-view if *THIS* window is on the main display.
        NSScreen *screen = self.window.screen;
        if (screen == NSScreen.mainScreen) {
            NSRect frame = self.frame;
            _ftv = [[FlyingToastersView alloc] initWithFrame:frame];        
            [self addSubview:_ftv];
            
            self.animationTimeInterval = 1 / 60.0;
        }
    }
}

- (void)setFrame:(NSRect)frame
{
    [super setFrame:frame];
    _ftv.frame = NSMakeRect(0, 0, frame.size.width, frame.size.height);
}

- (void)startAnimation
{
    [super startAnimation];
    
    FlyingToastersView *ftv = self.ftv;
    if (ftv != nil) {
        ftv.toastLevel = [ToasterDefaults getToastLevel];
        ftv.speed = [ToasterDefaults getFlightSpeed];
        ftv.numOfToasters = [ToasterDefaults getNumberOfToasters];
        
        [ftv start];
    }
}

- (void)stopAnimation
{
    [super stopAnimation];
    [self.ftv end];
}

- (void)animateOneFrame
{
    return;
}

- (BOOL)hasConfigureSheet
{
    return YES;
}

- (NSWindow*)configureSheet
{
    _prefsController =
    [[FlyingToasterPreferencesController alloc] initWithWindowNibName:@"FlyingToasterPreferencesController"];
    
    return _prefsController.window;
}

@end
