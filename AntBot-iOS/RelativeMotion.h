//
//  RelativeMotion.h
//  AntBot-iOS
//
//  Created by Joshua Hecker
//  Moses Lab, Department of Computer Science, University of New Mexico
//

#import <CoreMotion/CoreMotion.h>
#import "RouterCable.h"

typedef struct
{
    double x,y,z;
} vec3d_t;

@interface RelativeMotion : NSObject

@property vec3d_t currentDist;
@property vec3d_t currentVel;
@property CMAcceleration currentAcc;
@property vec3d_t previousDist;
@property vec3d_t previousVel;
@property CMAcceleration previousAcc;
@property (assign) NSDate *timer;
@property RouterCable* cable;

- (void)start;
- (void)stop;

- (RelativeMotion*)relativeMotion;
- (void)updateSpace;

@end