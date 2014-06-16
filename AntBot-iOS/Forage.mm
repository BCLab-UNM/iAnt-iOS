//
//  Forage.m
//  AntBot-iOS
//
//  Created by Bjorn Swenson on 6/5/14.
//
//

#import "Forage.h"
#import "RouterCable.h"
#import "RouterServer.h"
#import "ImageRecognition.h"
#import "Utilities.h"

// Departing State
@implementation ForageStateDeparting
@synthesize forage;

- (void)enter:(id<ForageState>)previous {
    [[forage cable] send:@"align"];
    [[forage imageRecognition] startWithTarget:ImageRecognitionTargetNest];
}

- (void)driveFinished {
    [forage setState:[forage searching]];
}

- (void)alignFinished {
    [[forage cable] send:@"drive,%f", random()];
}

- (void)alignInfo:(NSValue*)info {
    CGPoint offset = [info CGPointValue];
    bool epsilonCondition = false;
    if(epsilonCondition) {
        [[forage cable] send:@"alignFinished"];
        [[forage cable] send:@"turnTo,%f", random()];
    }
    else {
        [[forage cable] send:@"%d,%d", (int)offset.x, (int)offset.y];
    }
}
@end

// Searching State
@implementation ForageStateSearching
@synthesize forage;

- (void)turn {
    [[forage cable] send:@"turn,%f", random()];
}

- (void)enter:(id<ForageState>)previous {
    [self turn];
}

- (void)driveFinished {
    [self turn];
}

- (void)alignFinished {
    [[forage cable] send:@"drive,%f", random()];
}

- (void)QRCodeRead:(int)qrCode {
    //
    [forage setState:[forage neighbors]];
}
@end

// Neighbor Search State
@implementation ForageStateNeighbors
@synthesize forage;

- (void)turn {
    [[forage cable] send:@"turn,%f", random()];
}

- (void)enter:(id<ForageState>)previous {
    turns = 0;
    [self turn];
}

- (void)turnFinished {
    [self turn];
    turns++;
    if(turns >= 8) {
        [forage setState:[forage returning]];
    }
}

- (void)QRCodeRead:(int)qrCode {
    //
}
@end

// Returning State
@implementation ForageStateReturning
@synthesize forage;

- (void)enter:(id<ForageState>)previous {
    [[forage cable] send:@"align"];
    [[forage imageRecognition] startWithTarget:ImageRecognitionTargetNest];
}

- (void)driveFinished {
    [forage setState:[forage departing]];
}

- (void)turnFinished {
    [[forage cable] send:@"getUltrasound"];
}

- (void)getUltrasound:(NSArray *)data {
    float distance = [[data objectAtIndex:0] floatValue];
    [[forage cable] send:@"drive,%f", distance];
}
@end

// "Controller"
@implementation Forage

@synthesize imageRecognition, cable, server;
@synthesize state, departing, searching, neighbors, returning;

- (id)initWithCable:(RouterCable*)_cable server:(RouterServer*)_server {
    if(!(self = [super init])) {
        return nil;
    }
    
    cable = _cable;
    server = _server;
    imageRecognition = [[ImageRecognition alloc] init];
    [imageRecognition setDelegate:self];
    
    departing = [[ForageStateDeparting alloc] init];
    searching = [[ForageStateSearching alloc] init];
    neighbors = [[ForageStateNeighbors alloc] init];
    returning = [[ForageStateReturning alloc] init];
    
    departing.forage = searching.forage = neighbors.forage = returning.forage = self;
    
    [cable handle:@"driveFinished" callback:^(NSArray* data) {
        if([state respondsToSelector:@selector(driveFinished)]) {
            [state driveFinished];
        }
    }];
    
    [cable handle:@"alignFinished" callback:^(NSArray* data) {
        if([state respondsToSelector:@selector(alignFinished)]) {
            [state alignFinished];
        }
    }];
    
    [cable handle:@"getUltrasound" callback:^(NSArray* data) {
        if([state respondsToSelector:@selector(getUltrasound:)]) {
            [state getUltrasound:data];
        }
    }];
    
    [server handle:@"pheromone" callback:^(NSArray* data) {
        if([state respondsToSelector:@selector(pheromone:)]) {
            [state pheromone:data];
        }
    }];
    
    [server handle:@"tag" callback:^(NSArray* data) {
        if([state respondsToSelector:@selector(tag:)]) {
            [state tag:data];
        }
    }];
    
    state = departing;
    
    return self;
}

- (void)setState:(id)next {
    if(state){[state leave:next];}
    if(next){[next enter:state];}
    state = next;
}

- (void)didReceiveAlignInfo:(NSValue*)info {
    if([state respondsToSelector:@selector(alignInfo:)]) {
        [state alignInfo:info];
    }
}

- (void)didReadQRCode:(int)qrCode {
    if([state respondsToSelector:@selector(QRCodeRead:)]) {
        [state QRCodeRead:qrCode];
    }
}

@end