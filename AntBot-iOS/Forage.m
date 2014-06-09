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
            case RobotStatusInactive:
                // [imageRecognition setTarget:ImageRecognitionTargetNest];
                // [imageRecognition start];
                // [cable send:@"align"]; // Tell the arduino we'll be streaming it motor offsets for a while.
                break;
            
            default:
                NSLog(@"Received init, but was in inappropriate state %d", status);
                break;
        }
    }];
    
    // driveFinished
    [cable handle:@"driveFinished" callback:^(NSArray* data) {
        switch(status) {
            case RobotStatusDeparting:
                status = RobotStatusSearching;
                break;
                
            case RobotStatusReturning:
                // check pheromones from server
                status = RobotStatusDeparting;
                // changing to the leaving nest state will pick a random location and tell the arduino to drive there
                // will probably also involve an align
                break;
            
            case RobotStatusSearching:
                // turn a little bit
                // tell it to drive
                break;
            
            default:
                NSLog(@"Received driveFinished, but was in inappropriate state %d", status);
                break;
        }
    }];
    
    // alignFinished
    [cable handle:@"alignFinished" callback:^(NSArray* data) {
        switch(status) {
            case RobotStatusDeparting:
                // Tell it to drive to the destination
                break;
                
            case RobotStatusReturning:
                // Tell it to drive to the nest
                break;
                
            case RobotStatusSearching:
                // Tell it to drive forward a tad
                break;
                
            default:
                NSLog(@"Received alignFinished, but was in inappropriate state %d", status);
                break;
        }
    }];
}

- (void)loop {
    // Hopefully we don't have to put anything here
}

- (void)setStatus:(RobotStatus)_status {
    switch(_status) {
        // State change logic here.
        default:
            break;
    }
    
    status = _status;
}

- (void)didReceiveAlignInfo:(int)horizontal vertical:(int)vertical {
    // ImageRecognition processed a frame.
    [cable send:[NSString stringWithFormat:@"%d,%d", horizontal, vertical]];
}

@end
