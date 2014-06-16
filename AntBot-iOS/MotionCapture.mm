//
//  MotionCapture.m
//  AntBot-iOS
//
//  Created by Bjorn Swenson on 6/12/14.
//
//

#import "MotionCapture.h"

#import "RouterCable.h"
#import "RouterServer.h"
#import "Utilities.h"

@implementation MotionCapture

-(id) initWithCable:(RouterCable *)_cable server:(RouterServer *)_server {
    if(!(self = [super init])) {
        return nil;
    }
    
    cable = _cable;
    server = _server;
    
    // Arduino handlers
    [cable handle:@"align" callback:^(NSArray* data) {
        context = [[data objectAtIndex:0] intValue];
        monitoring = true;
        [cable send:@"align"];
    }];
    
    [cable handle:@"heading" callback:^(NSArray* data) {
        [cable send:@"%f", heading];
    }];
    
    // Server handlers
    [server handle:@"heading" callback:^(NSArray* data) {
        heading = [[data objectAtIndex:0] floatValue];
        
        //Create storage variables
        short int cmd[2] = {0, 0};
        cmd[0] = 2 * (int)[Utilities angleFrom:context to:heading];
        
        //Transmit data to Arduino
        [cable send:@"(%d,%d)", cmd[0], cmd[1]];
        
        //If angle is small enough, we transmit an additional command to Arduino to stop alignment
        if (abs(cmd[0]) < 2) {
            [cable send:@"(%d,%d)", cmd[0], cmd[1]];
            monitoring = false;
        }
    }];
    
    [server handle:@"tag" callback:^(NSArray* data) {
        if(monitoring) {
            // If we receive tag information while the mocapHeading is being monitored,
            // send a stop message to the Arduino
            monitoring = false;
            short int cmd[2] = {0, 0};
            [cable send:@"(%d,%d)", cmd[0], cmd[1]];
            [cable send:@"(%d,%d)", cmd[0], cmd[1]];
        }
    }];
    
    return self;
}

@end
