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

// Set up a CALL macro for running a selector on the current forage state (with an optional argument).
#define CALL1(X) if([state respondsToSelector:@selector(X)]){[state X];}
#define CALL2(X, Y) if([state respondsToSelector:@selector(X:)]){[state X:Y];}
#define GET_CALL(_1, _2, NAME, ...) NAME
#define CALL(...) GET_CALL(__VA_ARGS__, CALL2, CALL1)(__VA_ARGS__)

// Depart
@implementation ForageStateDeparting
@synthesize forage;

- (void)enter:(id<ForageState>)previous {
    [forage localize];
}

- (void)localizeDone {
    [forage driveTo:Cartesian(random(), random())];
}

- (void)driveDone {
    [forage setState:[forage searching]];
}
@end

// Random Walk
@implementation ForageStateSearching
@synthesize forage;

- (void)enter:(id<ForageState>)previous {
    [[forage imageRecognition] startWithTarget:ImageRecognitionTargetTag];
    [forage turn:[forage dTheta]];
}

- (void)turnDone {
    [forage drive:random()];
}

- (void)driveDone {
    [forage turn:[forage dTheta]];
}

- (void)tag:(int)code {
    [forage setState:[forage neighbors]];
}
@end

// Neighbor Search
@implementation ForageStateNeighbors
@synthesize forage;

- (void)enter:(id<ForageState>)previous {
    [[forage imageRecognition] startWithTarget:ImageRecognitionTargetNeighbors];
    turns = 0;
    tags = 0;
    [forage turn:random()];
}

- (void)turnDone {
    if(++turns >= 8) {
        [forage setState:[forage returning]];
    }
    else {
        [forage turn:random()];
    }
}

- (void)tag:(int)code {
    tags++;
}
@end

// Return
@implementation ForageStateReturning
@synthesize forage;

- (void)enter:(id<ForageState>)previous {
    [forage localize];
}

- (void)localizeDone {
    [forage driveTo:Cartesian(0, 0)];
}

- (void)driveDone {
    [[forage server] send:@"%@,%d,%@,%@,home", [Utilities getMacAddress], [forage microseconds], forage.position.x, forage.position.y];
}

- (void)pheromone {
    [forage setState:[forage departing]];
}
@end

// "Controller"
@implementation Forage

@synthesize position, heading, tag, pheromone, localizing;
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
    
    NSArray* states = [NSArray arrayWithObjects:@"departing", @"searching", @"neighbors", @"returning", nil];
    for(NSString* name in states) {
        id instance = [[NSClassFromString(name) alloc] init];
        [instance setForage:self];
        [self setValue:instance forKey:name];
    }
    
    [cable handle:@"drive" callback:^(NSArray* data) {
        CALL(driveDone);
        [server send:@"%@,%d,%@,%@", [Utilities getMacAddress], [self microseconds], position.x, position.y];
    }];
    
    [cable handle:@"align" callback:^(NSArray* data) {
        CALL(turnDone);
    }];
    
    [cable handle:@"compass" callback:^(NSArray* data) {
        float result = [[data objectAtIndex:0] floatValue];
        
        if(localizing) {
            [self setHeading:result];
            [cable send:@"ultrasound"];
        }
        
        CALL(compass, result);
    }];
    
    [cable handle:@"ultrasound" callback:^(NSArray* data) {
        float result = [[data objectAtIndex:0] floatValue];
        
        if(localizing) {
            position = [Utilities pol2cart:Polar(result, heading)];
            localizing = NO;
            CALL(localizeDone);
        }
        
        CALL(ultrasound, result);
    }];
    
    [server handle:@"pheromone" callback:^(NSArray* data) {
        pheromone = CGPointMake([[data objectAtIndex:0] floatValue], [[data objectAtIndex:1] floatValue]);
        CALL(pheromone);
    }];
    
    [server handle:@"tag" callback:^(NSArray* data) {
        if([[data objectAtIndex:0] isEqualToString:@"new"]) {
            CALL(tag, tag);
        }
        
        tag = -1;
    }];

    position = Cartesian(0, 0);
    heading = 0;
    tag = -1;
    pheromone = CGPointMake(INT_MAX, INT_MAX);
    startTime = [NSDate date];
    
    //state = departing;
    
    return self;
}

- (void)setState:(id)next {
    if(state){[state leave:next];}
    if(next){[next enter:state];}
    state = next;
}

- (double)microseconds {
    return [startTime timeIntervalSinceNow] * -1000000.0;
}

- (void)localize {
    localizing = YES;
    [imageRecognition startWithTarget:ImageRecognitionTargetNest];
}

- (void)driveTo:(Cartesian)destination {
    Polar pol = [Utilities cart2pol:(destination - position)];
    [self turnTo:pol.theta];
    [self drive:pol.r];
}

- (void)turnTo:(float)target {
    heading = target;
    [cable send:@"align,%f", heading];
}

- (void)drive:(float)distance {
    [cable send:@"drive,%f", distance];
    position += [Utilities pol2cart:Polar(distance, heading)];
}

- (void)turn:(float)radians {
    [self turnTo:(heading + radians)];
}

- (float)dTheta {
    return random();
}

- (void)didReceiveAlignInfo:(NSValue*)info {
    CGPoint offset = [info CGPointValue];
    if(localizing) {
        if(abs(offset.x <= 1)) {
            [cable send:@"motors,%d,%d", 0, 0];
            [cable send:@"compass"];
            [imageRecognition stop];
        }
        else {
            [cable send:@"motors,%d,%d", (int)offset.x, (int)offset.y];
        }
    }
    
    CALL(alignInfo, offset);
}

- (void)didReadQRCode:(int)_tag {
    tag = _tag;
    [server send:@"%@,%d", [Utilities getMacAddress], tag];
}

@end