//
//  RelativeMotion.m
//  AntBot
//
//  Created by Joshua Hecker on 12/29/11.
//  Moses Lab, Department of Computer Science, University of New Mexico
//

#import "RelativeMotion.h"

#pragma RelativeMotion extension

@interface RelativeMotion() {
    CMMotionManager *motionManager;
}

- (void)startRelativeMotion;
- (void)stopRelativeMotion;

@end

@implementation RelativeMotion

@synthesize currentDist;
@synthesize currentVel;
@synthesize currentAcc;
@synthesize previousDist;
@synthesize previousVel;
@synthesize previousAcc;
@synthesize timer;

- (void)start {
    [self startRelativeMotion];
    [self setTimer:[NSDate date]];
    
    vec3d_t loc;
    loc.x = loc.y = loc.z = 0;
    [self setCurrentDist:loc];
    [self setCurrentVel:loc];
    [self setPreviousDist:loc];
    [self setPreviousVel:loc];
    
    CMAcceleration loc2;
    loc2.x = loc2.y = loc2.z = 0;
    [self setCurrentAcc:loc2];
    [self setPreviousAcc:loc2];
    
    cblMgr = [CableManager cableManager];
}

- (void)stop {
    [self stopRelativeMotion];
}

- (void)startRelativeMotion {
    motionManager = [[CMMotionManager alloc] init];
    
    if (motionManager.deviceMotionAvailable) {
        motionManager.showsDeviceMovementDisplay = YES;
        motionManager.deviceMotionUpdateInterval = 1.0/20.0;
        [motionManager startDeviceMotionUpdates];
        
        motionManager.gyroUpdateInterval = 1.0/20.0;
        [motionManager startGyroUpdatesToQueue:[NSOperationQueue currentQueue]
                                   withHandler: ^(CMGyroData *gyroData, NSError *error) {
                                       CMRotationRate rotationRate = gyroData.rotationRate; //we only care about rotation around z-axis
                                       int rate = MAX(MIN((rotationRate.z * (180.0/M_PI)),127),-127); //bound at [-127,127]
                                       [cblMgr send:[NSString stringWithFormat:@"%d",rate]]; //transmit rate
                                       [cblMgr send:@"\n"];
                                   }];
    }
    else {
        NSLog(@"Device-motion service is not available on this device");
    }
}

- (void)stopRelativeMotion {
    [motionManager stopDeviceMotionUpdates];
    [motionManager stopGyroUpdates];
	motionManager = nil;
}
   
- (RelativeMotion*)relativeMotion {
    RelativeMotion* relMotion = [[RelativeMotion alloc] init];
    return relMotion;
}

- (void)updateSpace {
    NSTimeInterval timePassed = [[NSDate date] timeIntervalSinceDate:timer];
    
    if (timePassed >= motionManager.deviceMotionUpdateInterval) {
        CMDeviceMotion *d = motionManager.deviceMotion;
        
        if (d != nil) {
            currentAcc = d.userAcceleration;
            
            if  ((fabs(currentAcc.x) < .01) && (fabs(currentAcc.y) < .01) && (fabs(currentAcc.z) < .01)) {
                currentAcc.x = 0;
                currentAcc.y = 0;
                currentAcc.z = 0;
            }
            
            currentVel.x = (currentAcc.x  + previousAcc.x)*9.81/2.0 * timePassed + previousVel.x;
            currentVel.y = (currentAcc.y  + previousAcc.y)*9.81/2.0 * timePassed + previousVel.y;
            currentVel.z = (currentAcc.z  + previousAcc.z)*9.81/2.0 * timePassed + previousVel.z;
            
            currentDist.x = (currentVel.x  + previousVel.x)/2.0 * timePassed + previousDist.x;
            currentDist.y = (currentVel.y  + previousVel.y)/2.0 * timePassed + previousDist.y;
            currentDist.z = (currentVel.z  + previousVel.z)/2.0 * timePassed + previousDist.z;
            
            previousAcc = currentAcc;
            previousVel = currentVel;
            previousDist = currentDist;
            
            [self setTimer:[NSDate date]];
        }
	}
}

@end