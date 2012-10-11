//
//  AbsoluteMotion.h
//  AntBot-iOS
//
//  Created by Joshua Hecker on 3/17/12.
//  Moses Lab, Department of Computer Science, University of New Mexico.
//

#import <CoreLocation/CoreLocation.h>
#import "CableManager.h"

@interface AbsoluteMotion : NSObject <CLLocationManagerDelegate>
{
    CableManager *cblMgr;
    CLLocationManager *locationManager;
}

@property float currentHeading;
@property CLLocationCoordinate2D currentCoordinate;
@property BOOL insideVirtualFence;
@property (nonatomic, retain) CLLocationManager *locationManager;

- (void)start;
- (void)stop;

- (void)enableRegionMonitoring:(NSString*)name withRadius:(double)radius;
- (void)disableRegionMonitoring:(NSString*)name;

- (AbsoluteMotion*)absoluteMotion;

@end
