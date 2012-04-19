//
//  AbsoluteMotion.h
//  AntBot
//
//  Created by Joshua Hecker on 3/17/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@interface AbsoluteMotion : NSObject <CLLocationManagerDelegate> 
{
    CLLocationManager *locationManager;
}

@property float currentHeading;
@property CLLocationCoordinate2D currentCoordinate;
@property (nonatomic, retain) CLLocationManager *locationManager;

- (void)start;
- (void)stop;

- (AbsoluteMotion*)absoluteMotion;

@end
