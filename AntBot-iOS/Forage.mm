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
    [[forage imageRecognition] startWithTarget:ImageRecognitionTargetTag];
    [self turn];
}

- (void)driveFinished {
    [self turn];
}

- (void)alignFinished {
    [[forage cable] send:@"drive,%f", random()];
}

- (void)tag:(int)code {
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
    [[forage imageRecognition] startWithTarget:ImageRecognitionTargetNeighbors];
    turns = 0;
    tags = 0;
    [self turn];
}

- (void)turnFinished {
    [self turn];
    turns++;
    if(turns >= 8) {
        [forage setState:[forage returning]];
    }
}

- (void)tag:(int)code {
    tags++;
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

@synthesize tag, pheromone;
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
        
        [server send:@"%@,%d,%@,%@", [Utilities getMacAddress], /*microseconds*/0, [data objectAtIndex:0], [data objectAtIndex:1]];
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
        pheromone = CGPointMake([[data objectAtIndex:0] floatValue], [[data objectAtIndex:1] floatValue]);
    }];
    
    [server handle:@"tag" callback:^(NSArray* data) {
        if([[data objectAtIndex:0] isEqualToString:@"new"] && [state respondsToSelector:@selector(tag:)]) {
            [state tag:tag];
        }
        
        tag = -1;
    }];
    
    tag = -1;
    pheromone = CGPointMake(INT_MAX, INT_MAX);
    
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

- (void)didReadQRCode:(int)_tag {
    tag = _tag;
    [server send:@"%@,%d", [Utilities getMacAddress], tag];
}

@end