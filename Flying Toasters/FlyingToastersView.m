//
//  FlyingToastersView.m
//  Flying Toasters
//
//  Created by Robert Venturini on 3/8/19.
//  Copyright © 2019 Robert Venturini. All rights reserved.
//

#import "FlyingToastersView.h"
#import "ScreenSaverScene.h"

// in the original Flying Toasters, the wings flapped at a constant rate, regardless of speed.
static const NSTimeInterval flapFrameDuration = 0.08;

@interface FlyingToastersView () <SKSceneDelegate, SKPhysicsContactDelegate>
@property (strong) ScreenSaverScene *toasterScene;
@property (strong) NSMutableArray<SKPhysicsBody *> *inContactBodies;

@property (readonly) CGFloat speedMultiplier;
@property (readonly) CGFloat fastSpeedMultipler;
@end

@implementation FlyingToastersView

- (instancetype)init
{
    if (self = [super initWithFrame:NSZeroRect]) {
        _speed = kMediumSpeed;
        _toastLevel = kGoldenBrownToast;
        
        _toasterScene = [[ScreenSaverScene alloc] initWithSize:self.frame.size];
        _toasterScene.backgroundColor = [NSColor blackColor];
        _toasterScene.delegate = self;
        
        SKPhysicsWorld *world = _toasterScene.physicsWorld;
        world.gravity = CGVectorMake(0, 0);
        world.contactDelegate = self;
        
        _inContactBodies = [NSMutableArray new];

        [self presentScene:_toasterScene];
    }
    
    return self;
}

- (void)setFrame:(NSRect)frame
{
    [super setFrame:frame];
    _toasterScene.size = frame.size;
}

- (CGFloat)speedMultiplier
{
    return self.speed / 10.0f;
}

- (CGFloat)fastSpeedMultipler
{
    FlightSpeed fasterSpeed = kSnailSpeed;
    
    switch (self.speed) {
        case kSnailSpeed:
            fasterSpeed = kSlowSpeed;
            break;
            
        case kSlowSpeed:
            fasterSpeed = kMediumSpeed;
            break;
            
        case kMediumSpeed:
            fasterSpeed = kFastSpeed;
            break;
            
        case kFastSpeed:
            fasterSpeed = kLightningSpeed;
            break;
        
        case kLightningSpeed:
            // Lets loop back around here, and use fast here,
            // the effect we're going for is simply to have a dynamic
            // feeling to flight speed
            fasterSpeed = kFastSpeed;
            break;
    }
    
    return fasterSpeed / 10.f;
}

- (CGFloat)_distanceBetweenPoint1:(CGPoint)point1 andPoint2:(CGPoint)point2
{
    CGFloat xDist = (point2.x - point1.x);
    CGFloat yDist = (point2.y - point1.y);
    return sqrt((xDist * xDist) + (yDist * yDist));
}

/** speed rate is 0.1 for slowest pace to 1.0 for fastest */
- (CGFloat)_speedForRate:(CGFloat)speedRate
        withInitialPoint:(CGPoint)initialPoint
             andEndpoint:(CGPoint)endPoint
                nodeSize:(CGSize)nodeSize
{
    CGFloat distance = [self _distanceBetweenPoint1:initialPoint
                                          andPoint2:endPoint];
    
    float nodeHypotenuse = sqrt((nodeSize.width * nodeSize.width) +
                                (nodeSize.height * nodeSize.height));

    CGFloat speed = (speedRate / nodeHypotenuse) * distance;
    return speed;
    
}

- (void)_getRandomStartingPoint:(CGPoint*)startingPoint
                 andEndingPoint:(CGPoint*)endingPoint
                    forNodeSize:(CGSize)nodeSize
                   andSceneSize:(CGSize)sceneSize
{
    NSAssert((sceneSize.width > 0 && sceneSize.height > 0), @"Unexpected Scene Size!");
    
    int axis = rand() % 2;
    if (axis == 0) {
        int initialXPoint = rand() % (int)sceneSize.width;
        
        *startingPoint = CGPointMake(initialXPoint + nodeSize.width,
                                     sceneSize.height + nodeSize.height);
        *endingPoint = CGPointMake(0 - nodeSize.width,
                                   sceneSize.height - initialXPoint - nodeSize.height);
    } else {
        int initialYPoint = rand() % (int)sceneSize.height;
        
        
        *startingPoint = CGPointMake(sceneSize.width + nodeSize.width,
                                     initialYPoint + nodeSize.height);
        *endingPoint = CGPointMake(sceneSize.width - initialYPoint - nodeSize.width,
                                   0 - nodeSize.height);
    }
}

- (void)didFinishUpdateForScene:(SKScene *)scene
{
    if (_inContactBodies.count > 0) {
        // how do we lerp the velocity smoothly?
        for (SKPhysicsBody *body in _inContactBodies) {
            SKNode *node = body.node;
            NSDictionary *userData = node.userData;
            CGFloat dx = [userData[@"dx"] doubleValue];
            CGFloat dy = [userData[@"dy"] doubleValue];
            body.velocity = CGVectorMake(dx, dy);
        }
        [_inContactBodies removeAllObjects];
    }
    NSArray *nodes = [_toasterScene.children copy];
    for (SKNode *node in nodes) {
        CGPoint position = node.position;
        CGSize size = node.frame.size;
        if (position.y < -size.height || position.x < -size.width) {
            [node removeFromParent];
            
            NSDictionary* userData = node.userData;
            NSArray<SKTexture *> *textures = userData[@"textures"];
            CGFloat speedRate = [userData[@"speedRate"] doubleValue];
            
            // Add another one to replace this one
            [self _addNodeWithTextures:textures andSpeed:speedRate];
        }
    }
}

- (void)didEndContact:(SKPhysicsContact *)contact
{
    SKPhysicsBody *bodyA = contact.bodyA, *bodyB = contact.bodyB;
    if (bodyA.allContactedBodies.count == 0) {
        [_inContactBodies addObject:bodyA];
    }
    if (bodyB.allContactedBodies.count == 0) {
        [_inContactBodies addObject:bodyB];        
    }
}

- (void)_addNodeWithTextures:(NSArray<SKTexture *> *)textures andSpeed:(CGFloat)speedRate
{
    if (textures.count && self.toasterScene != nil) {
        SKTexture *texture = textures.firstObject;
        SKSpriteNode* node = [SKSpriteNode spriteNodeWithTexture:texture];
        NSMutableDictionary *userData = [@{
            @"textures" : textures, @"speedRate" : @(speedRate)
        } mutableCopy];
        node.userData = userData;
        
        BOOL isFast = speedRate == self.fastSpeedMultipler;
        
        // all toaster motion now uses a physics body.
        SKPhysicsBody *body = [SKPhysicsBody bodyWithTexture:texture size:texture.size];
        body.usesPreciseCollisionDetection = YES;
        body.affectedByGravity = NO;
        body.allowsRotation = NO;
        body.contactTestBitMask = 0x1;
        body.friction = 0;
        body.linearDamping = 0;
        body.mass = isFast ? 1.0 : 3.0;
        body.restitution = 1.0;
        node.physicsBody = body;
        
        NSAssert(self.toasterScene != nil, @"Error: Toaster Scene not set!");
        CGSize sceneSize = self.toasterScene.size;
        
        CGPoint startPosition = CGPointZero;
        CGPoint endPosition = CGPointZero;
        
        [self _getRandomStartingPoint:&startPosition
                       andEndingPoint:&endPosition
                          forNodeSize:node.size
                         andSceneSize:sceneSize];
        
        node.position = startPosition;
        [self.toasterScene addChild:node];

        // use physics to move the toasters. I have no idea what these units mean!
        CGVector velocity = CGVectorMake(-120, -80);
        if (isFast) {
            velocity.dx *= 2;
            velocity.dy *= 2;
        }
        body.velocity = velocity;
        userData[@"dx"] = @(velocity.dx);
        userData[@"dy"] = @(velocity.dy);

        if (textures.count > 1) {
            SKAction* animateAction = [SKAction animateWithTextures:textures
                                                       timePerFrame:isFast ? flapFrameDuration / 2 : flapFrameDuration
                                                             resize:NO restore:YES];
            SKAction* repeatedAnimationAction = [SKAction repeatActionForever:animateAction];
            [node runAction:repeatedAnimationAction];
        }
        
#if 0
        // old way, using actions.
        CGFloat duration = [self _speedForRate:speedRate withInitialPoint:startPosition andEndpoint:endPosition nodeSize:node.size];
        
        __weak FlyingToastersView* toasterView = self;
        SKAction* flyAction = [SKAction moveTo:endPosition duration:duration];
        SKAction* doneAction = [SKAction runBlock:^{
            // Remove the current sprite
            [node removeFromParent];
            
            // Add another one to replace this one
            [toasterView _addNodeWithTextures:textures andSpeed:speedRate];
        }];
        
        SKAction* nodeActions = [SKAction sequence:@[flyAction, doneAction]];
        [node runAction:nodeActions];
#endif
    }
}

- (NSArray<SKTexture *> *)getToasterTextures
{
    NSBundle* thisBundle = [NSBundle bundleForClass:[self class]];
    NSString* texture1 = [thisBundle pathForResource:@"Textures/toaster01" ofType:@"png"];
    NSString* texture2 = [thisBundle pathForResource:@"Textures/toaster02" ofType:@"png"];
    NSString* texture3 = [thisBundle pathForResource:@"Textures/toaster03" ofType:@"png"];
    NSString* texture4 = [thisBundle pathForResource:@"Textures/toaster04" ofType:@"png"];
    
    SKTexture* toasterTexture1 = [SKTexture textureWithImageNamed:texture1]; // Low Point
    SKTexture* toasterTexture2 = [SKTexture textureWithImageNamed:texture2];
    SKTexture* toasterTexture3 = [SKTexture textureWithImageNamed:texture3];
    SKTexture* toasterTexture4 = [SKTexture textureWithImageNamed:texture4]; // High point
    SKTexture* toasterTexture5 = [SKTexture textureWithImageNamed:texture3];
    SKTexture* toasterTexture6 = [SKTexture textureWithImageNamed:texture2];

    // Start Low
    NSMutableArray* textures = [@[toasterTexture1,
                                  toasterTexture2,
                                  toasterTexture3,
                                  toasterTexture4,
                                  toasterTexture5,
                                  toasterTexture6] mutableCopy];

    NSUInteger shift = rand() % [textures count];
    while (shift != 0) {
        SKTexture* leadingTexture = [textures firstObject];

        // Move leading texture to end
        [textures removeObject:leadingTexture];
        [textures addObject:leadingTexture];

        shift--;
    }

    return textures;
}

- (NSArray<SKTexture *> *)getToastTexture
{
    NSString* textureName = @"Textures/toast1.gif";
    
    switch (self.toastLevel) {
        case kLightToast:
            textureName = @"Textures/toast0.gif";
            break;
            
        case kGoldenBrownToast:
            textureName = @"Textures/toast1.gif";
            break;
            
        case kDarkToast:
            textureName = @"Textures/toast2.gif";
            break;
            
        case kBurntToast:
            textureName = @"Textures/toast3.gif";
            break;
    }
    
    NSBundle* thisBundle = [NSBundle bundleForClass:[self class]];
    NSString* toastTexture = [thisBundle pathForResource:textureName ofType:nil];
    
    return @[[SKTexture textureWithImageNamed:toastTexture]];
}

#pragma mark - Actions
- (void)_addToasterAtIndex:(NSUInteger)index
                toastIndex:(NSUInteger)toastIndex
          fastToasterIndex:(NSUInteger)fastToasterIndex
{
    NSUInteger toasterCount = self.numOfToasters;
    if (toasterCount) {
        BOOL addToast = (index % 2) == 0;
        BOOL isSpeedyToaster = (index % 4) == 0;
        
        CGFloat speed = self.speedMultiplier;
        if (index < toasterCount) {
            // Add the toast first at regular speed
            if (addToast) {
                [self _addNodeWithTextures:[self getToastTexture]
                                  andSpeed:speed];
            }
            
            // If this is a fast toaster modify the speed
            if (isSpeedyToaster) {
                speed = self.fastSpeedMultipler;
            }
            
            // Add the toaster
            [self _addNodeWithTextures:[self getToasterTextures]
                              andSpeed:speed];
            
            __block FlyingToastersView* toasterView = self;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, speed * 1000000000), dispatch_get_main_queue(), ^{
                [toasterView _addToasterAtIndex:(index+1)
                                     toastIndex:toastIndex
                               fastToasterIndex:fastToasterIndex];
            });
        }
    }
}

- (void)start
{
    NSUInteger toasterCount = self.numOfToasters;
    if (toasterCount) {
        NSUInteger toastIndex = rand() % toasterCount;
        NSUInteger fastToasterIndex = rand() % toasterCount;

        [self _addToasterAtIndex:0 toastIndex:toastIndex fastToasterIndex:fastToasterIndex];
    }
}

- (void)end
{
    [self.toasterScene removeAllActions];
    [self.toasterScene removeAllChildren];
}

- (BOOL)acceptsFirstResponder
{
    return NO;
}

@end
