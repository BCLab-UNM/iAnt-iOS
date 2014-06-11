//
//  Forage.m
//  AntBot-iOS
//
//  Created by Bjorn Swenson on 6/5/14.
//
//

#import "Forage.h"
#import "RouterCable.h"
#import "ImageRecognition.h"

#define SLEEP(x) [NSThread sleepForTimeInterval:x];

@implementation Forage

@synthesize status;

- (void)setup:(RouterCable*)_cable {
    cable = _cable;
    status = RobotStatusInactive;
    imageRecognition = [[ImageRecognition alloc] init];
    [imageRecognition setDelegate:self];
    
    [cable send:@"init"];
    
    // init
    [cable handle:@"init" callback:^(NSArray* data) {
        switch(status) {
            
            // Arduino is ready for commands.  Start the state machine.
            case RobotStatusInactive:
                status = RobotStatusDeparting;
                break;
            
            default:
                NSLog(@"Received init, but was in inappropriate state %d", status);
                break;
        }
    }];
    
    // driveFinished
    [cable handle:@"driveFinished" callback:^(NSArray* data) {
        switch(status) {
                
            // Robot has reached its destination.  Perform a random walk.
            case RobotStatusDeparting: {
                status = RobotStatusSearching;
                // Fallthrough to RobotStatusSearching
            }
                
            case RobotStatusSearching: {
                float dTheta = random();
                [cable send:[NSString stringWithFormat:@"turn,%f", dTheta]];
                break;
            }
                
            case RobotStatusReturning:
                // check pheromones from server
                status = RobotStatusDeparting;
                // changing to the leaving nest state will pick a random location and tell the arduino to drive there
                // will probably also involve an align
                break;
            
            default:
                NSLog(@"Received driveFinished, but was in inappropriate state %d", status);
                break;
        }
    }];
    
    // turnFinished
    [cable handle:@"turnFinished" callback:^(NSArray* data) {
        switch(status) {
                
            // Robot has finished aligning to its destination.  Tell it to drive there.
            case RobotStatusDeparting: {
                float distance = random();
                [cable send:[NSString stringWithFormat:@"drive,%f", distance]];
                break;
            }
                
            case RobotStatusReturning:
                // Tell it to drive to the nest
                break;
                
            // Robot has finished adjusting its direction.  Tell it to drive forward.
            case RobotStatusSearching: {
                float distance = random();
                [cable send:[NSString stringWithFormat:@"drive,%f", distance]];
                break;
            }
                
            default:
                NSLog(@"Received alignFinished, but was in inappropriate state %d", status);
                break;
        }
    }];
}

- (void)setStatus:(RobotStatus)_status {
    switch(_status) {
        case RobotStatusDeparting:
            [self localize];
            break;
            
        case RobotStatusSearching:
            [imageRecognition setTarget:ImageRecognitionTargetTag];
            [imageRecognition start];
            break;
            
        default: break;
    }
    
    status = _status;
}

- (void)didReceiveAlignInfo:(NSValue*)info {
    CGPoint offset = [info CGPointValue];
    bool epsilonCondition = false;
    if(epsilonCondition) {
        [cable send:@"alignFinished"];
        switch(status) {
            case RobotStatusDeparting: {
                // Decide on a destination based on pheromones and site fidelity.
                float heading = random();
                [cable send:[NSString stringWithFormat:@"turnTo,%f", heading]];
                break;
            }
                
            default: break;
        }
    }
    else {
        [cable send:[NSString stringWithFormat:@"%d,%d", (int)offset.x, (int)offset.y]];
    }
}

- (void)localize {
    [imageRecognition setTarget:ImageRecognitionTargetNest];
    [imageRecognition start];
    [cable send:@"align"]; // Tell the arduino we'll be streaming it motor offsets for a while.
}

@end
