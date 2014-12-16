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
#import "DebugView.h"

#import "Camera.h"
#import "FiducialPipeline.h"

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
    [forage driveTo:[forage destination]];
}

- (void)driveDone {
    [forage setState:[forage searching]];
}
@end

// Random Walk
@implementation ForageStateSearching
@synthesize forage;

- (void)enter:(id<ForageState>)previous {
    [[forage camera] startPipeline:[forage fiducialPipeline]];
    searchTime = 0;
    [forage turn:[forage dTheta:searchTime++]];
}

- (void)turnDone {
    [forage delay:.02f];
    [forage drive:[forage searchStepSize]];
}

- (void)driveDone {
    [forage delay:.11f];
    [forage turn:[forage dTheta:searchTime++]];
}

- (void)tag:(int)code {
    [forage setState:[forage neighbors]];
}
@end

// Neighbor Search
@implementation ForageStateNeighbors
@synthesize forage;

- (void)enter:(id<ForageState>)previous {
    turns = 0;
    tags = 1;
    [[forage camera] startPipeline:[forage fiducialPipeline]];
    [forage turn:10];
}

- (void)turnDone {
    if(++turns >= 36) {
        [forage setState:[forage returning]];
        NSNumber* tag = [NSNumber numberWithInt:[forage tag]];
        NSNumber* neighbors = [NSNumber numberWithInt:tags];
        [forage serverSend:[NSArray arrayWithObjects:@"tag", tag, neighbors, nil]];
        [forage setLastNeighbors:tags];
    }
    else {
        [forage delay:.2f];
        [forage turn:10];
    }
}

- (void)tag:(int)code {
    tags++;
    [[forage distinctTags] setObject:[NSNumber numberWithBool:YES] forKey:[NSNumber numberWithInt:code]];
    [[forage.debug data] setObject:[NSNumber numberWithInt:(int)[forage.distinctTags count]] forKey:@"unique"];
    [[forage.debug data] setObject:[NSNumber numberWithInt:([[[forage.debug data] objectForKey:@"total"] intValue] + 1)] forKey:@"total"];
    [[forage.debug table] reloadData];
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
    [forage serverSend:[NSArray arrayWithObject:@"home"]];
}

- (void)pheromone {
    [forage setState:[forage departing]];
}
@end

// "Controller"
@implementation Forage

@synthesize position, heading, informedStatus, tag, lastNeighbors, lastTagLocation, pheromone, localizing;
@synthesize fenceRadius, searchStepSize, travelGiveUpProbability, searchGiveUpProbability;
@synthesize uninformedSearchCorrelation, informedSearchCorrelationDecayRate;
@synthesize pheromoneDecayRate, pheromoneLayingRate, siteFidelityRate;
@synthesize driveEnabled, turnEnabled;
@synthesize fiducialPipeline;
@synthesize imageRecognition, cable, server, camera, debug;
@synthesize state, departing, searching, neighbors, returning;
@synthesize distinctTags;

- (id)initWithCable:(RouterCable*)_cable server:(RouterServer*)_server camera:(Camera*)_camera {
    if(!(self = [super init])) {
        return nil;
    }
    
    cable = _cable;
    server = _server;
    camera = _camera;

    imageRecognition = [[ImageRecognition alloc] init];
    [imageRecognition setDelegate:self];
    
    // Init states
    NSArray* states = [NSArray arrayWithObjects:@"departing", @"searching", @"neighbors", @"returning", nil];
    for(NSString* name in states) {
        NSString* uppercase = [name stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:[[name substringToIndex:1] uppercaseString]];
        Class stateClass = NSClassFromString([NSString stringWithFormat:@"ForageState%@", uppercase]);
        id instance = [[stateClass alloc] init];
        [instance setForage:self];
        [self setValue:instance forKey:name];
    }
    
    // Serial cable callbacks
    [cable handle:@"ready" callback:^(NSArray* data) {
        if(!startTime) {
            self.state = searching;
            startTime = [NSDate date];
            //[server send:[Utilities getMacAddress]];
        }
    }];
    
    [cable handle:@"drive" callback:^(NSArray* data) {
        CALL(driveDone);
        [self serverSend:nil];
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
    
    // Server callbacks
    [server handle:@"pheromone" callback:^(NSArray* data) {
        pheromone = Cartesian([[data objectAtIndex:0] floatValue], [[data objectAtIndex:1] floatValue]);
        CALL(pheromone);
    }];
    
    [server handle:@"tag" callback:^(NSArray* data) {
        if([[data objectAtIndex:0] isEqualToString:@"new"]) {
            CALL(tag, tag);
        }
        
        tag = -1;
    }];

    // State data
    position = Cartesian(0, 0);
    heading = 0;
    informedStatus = RobotInformedStatusNone;
    tag = -1;
    lastNeighbors = 0;
    lastTagLocation = Cartesian(INFINITY, INFINITY);
    pheromone = Cartesian(INFINITY, INFINITY);
    localizing = NO;
    
    // Behavior parameters
    fenceRadius = 200;
    searchStepSize = 8.15;
    travelGiveUpProbability = 0.322792589664459;
    searchGiveUpProbability = 0.000770092010498047;
    
    // Random walk parameters
    uninformedSearchCorrelation = 0.279912143945694;
    informedSearchCorrelationDecayRate = 0.251652657985687;
    
    // Information parameters
    siteFidelityRate = 3.53300333023071;
    
    // Image recognition pipelines
    fiducialPipeline = [[FiducialPipeline alloc] init];
    [fiducialPipeline setDelegate:self];

    distinctTags = [[NSMutableDictionary alloc] init];
    
    return self;
}

- (void)setState:(id)next {
    if([state respondsToSelector:@selector(leave:)]){[state leave:next];}
    if([next respondsToSelector:@selector(enter:)]){[next enter:state];}
    state = next;
}

- (unsigned)microseconds {
    return (unsigned)([startTime timeIntervalSinceNow] * -1000000.0);
}

/**
 * "Library" methods
 */
- (void)serverSend:(NSArray *)event {
    return;
    int x = (int)roundf(position.x);
    int y = (int)roundf(position.y);
    NSString* message = [NSString stringWithFormat:@"%@,%d,%d,%d,", [Utilities getMacAddress], [self microseconds], x, y];
    
    if(event) {
        message = [message stringByAppendingString:[event componentsJoinedByString:@","]];
    }
    
    [server send:message];
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
    
    [[debug data] setObject:[NSNumber numberWithInt:heading] forKey:@"heading"];
    [[debug table] reloadData];
    
    if(!turnEnabled) {
        CALL(turnDone);
        return;
    }
    
    [cable send:@"align,%f", heading];
}

- (void)drive:(float)distance {
    position += [Utilities pol2cart:Polar(distance, heading)];
    
    [[debug data] setObject:[NSNumber numberWithInt:position.x] forKey:@"x"];
    [[debug data] setObject:[NSNumber numberWithInt:position.y] forKey:@"y"];
    [[debug table] reloadData];
    
    if(!driveEnabled) {
        CALL(driveDone);
        return;
    }
    
    [cable send:@"drive,%f", distance];
}

- (void)turn:(float)degrees {
    [self turnTo:(heading + degrees)];
}

- (void)delay:(float)seconds {
    [cable send:@"delay,%d", (int)roundf(seconds * 1000)];
}

- (float)dTheta:(int)searchTime {
    float sigma = uninformedSearchCorrelation;
    
    if(informedStatus != RobotInformedStatusNone) {
        float quantity = (4 * M_PI) - uninformedSearchCorrelation;
        sigma += [Utilities exponentialDecay:quantity time:searchTime lambda:informedSearchCorrelationDecayRate];
    }
    
    float result = [Utilities rad2deg:[Utilities clamp:[Utilities randomWithMean:0 standardDeviation:sigma] min:-M_PI max:M_PI]];
    float distance = sqrtf(position.x * position.x + position.y * position.y);
    
    // Fence bias
    if(distance > fenceRadius) {
        //float correction = [Utilities angleFrom:(heading + result) to:(heading - 180)];
        //result += [Utilities poissonCDF:(distance - fenceRadius) / 100.0f lambda:3] * correction;
        Polar p = [Utilities cart2pol:position];
        result = (p.theta + 180) - heading;
    }
    
    return result;
}

- (Cartesian)destination {
    BOOL useSiteFidelity = [Utilities randomFloat] < [Utilities poissonCDF:lastNeighbors lambda:siteFidelityRate];
    BOOL usePheromone = true;
    if(informedStatus == RobotInformedStatusPheromone && pheromone.x != 0 && pheromone.y != 0 && usePheromone) {
        return pheromone;
    }
    else if (informedStatus == RobotInformedStatusMemory && useSiteFidelity) {
        return lastTagLocation;
    }
    else {
        float distance = 0;
        for(distance = 0; distance < fenceRadius; distance += searchStepSize) {
            if([Utilities randomFloat] < travelGiveUpProbability) {
                break;
            }
        }
        
        return [Utilities pol2cart:Polar(distance, [Utilities randomFloat:360])];
    }
}

/**
 * Delegate methods
 */
- (void)didReceiveAlignInfo:(NSValue*)info {
    CGPoint offset = [info CGPointValue];
    if(localizing) {
        if(fabsf(offset.x) <= 1) {
            [cable send:@"motors,%d,%d", 0, 0];
            [cable send:@"compass"];
            [imageRecognition stop];
        }
        else {
            [cable send:@"motors,%d,%d,%d", (int)offset.x, (int)offset.y, MIN(MAX((int)fabsf(offset.x), 5), 150)];
        }
    }
    
    CALL(alignInfo, offset);
}

- (void)pipeline:(id)pipeline didProcessFrame:(NSNumber*)result {
    if([pipeline isMemberOfClass:[FiducialPipeline class]]) {
        //[server send:[NSString stringWithFormat:@"%@,%@", [Utilities getMacAddress], [result stringValue], nil]];
        //lastTagLocation = position;
        tag = [result intValue];
        CALL(tag, tag);
    }
}

@end