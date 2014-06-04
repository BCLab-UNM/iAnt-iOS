//
//  AbsoluteMotion.h
//  AntBot-iOS
//
//  Created by Joshua Hecker
//  Moses Lab, Department of Computer Science, University of New Mexico.
//

#import <CoreLocation/CoreLocation.h>
#import "RouterCable.h"

@interface AbsoluteMotion : NSObject <CLLocationManagerDelegate>
{
    CLLocationManager *locationManager;
}

@property float currentHeading;
@property CLLocationCoordinate2D currentCoordinate;
@property BOOL insideVirtualFence;
@property (nonatomic, retain) CLLocationManager *locationManager;
@property RouterCable* cable;

- (void)start;
- (void)stop;

- (void)enableRegionMonitoring:(NSString*)name withRadius:(double)radius;
- (void)disableRegionMonitoring:(NSString*)name;

@end
