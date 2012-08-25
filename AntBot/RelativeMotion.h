//
//  RelativeMotion.h
//  AntBot
//
//  Created by Joshua Hecker on 12/29/11.
//  Moses Lab, Department of Computer Science, University of New Mexico
//

#import <CoreMotion/CoreMotion.h>
#import "CableManager.h"

typedef struct
{
    double x,y,z;
} vec3d_t;

@interface RelativeMotion : NSObject
{
    CableManager *cblMgr;
}

@property vec3d_t currentDist;
@property vec3d_t currentVel;
@property CMAcceleration currentAcc;
@property vec3d_t previousDist;
@property vec3d_t previousVel;
@property CMAcceleration previousAcc;
@property (assign) NSDate *timer;

- (void)start;
- (void)stop;

- (RelativeMotion*)relativeMotion;
- (void)updateSpace;

@end