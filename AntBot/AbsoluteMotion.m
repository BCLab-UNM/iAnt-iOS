//
//  AbsoluteMotion.m
//  AntBot-iOS
//
//  Created by Joshua Hecker on 3/17/12.
//  Moses Lab, Department of Computer Science, University of New Mexico.
//

#import "AbsoluteMotion.h"

#pragma AbsoluteMotion extension

@interface AbsoluteMotion()

- (void)startAbsoluteMotion;
- (void)stopAbsoluteMotion;

@end

@implementation AbsoluteMotion

@synthesize currentHeading;
@synthesize currentCoordinate;
@synthesize insideVirtualFence;
@synthesize locationManager;

- (void)start
{
    [self startAbsoluteMotion];
    cblMgr = [CableManager cableManager];
}

- (void)stop
{
    [self stopAbsoluteMotion];
}

- (AbsoluteMotion*)absoluteMotion
{
    AbsoluteMotion* absMotion = [[AbsoluteMotion alloc] init];
    return absMotion;
}

- (void)enableRegionMonitoring:(NSString*)name withRadius:(double)radius
{
    CLRegion* region = [[CLRegion alloc] initCircularRegionWithCenter:currentCoordinate radius:(CLLocationDistance)radius identifier:name];
    [locationManager startMonitoringForRegion:region];
}

- (void)disableRegionMonitoring:(NSString*)name
{
    NSArray* regions = [[locationManager monitoredRegions] allObjects];
    for (int i = 0; i < [regions count]; i++)
    {
        CLRegion *region = [regions objectAtIndex:i];
        if ([[region identifier] compare:name])
        {
            [locationManager stopMonitoringForRegion:[regions objectAtIndex:i]];
        }
    }
}

#pragma mark - Internal start/stop methods

- (void)startAbsoluteMotion
{
    self.locationManager = [[CLLocationManager alloc] init];
        
    if ([CLLocationManager locationServicesEnabled])
    {
        locationManager.distanceFilter = kCLDistanceFilterNone;
        locationManager.delegate = self;
        [locationManager startUpdatingLocation];
    }
    else
    {
        NSLog(@"Location Services are currently disabled");
        self.locationManager = nil;
    }
    
    if ([CLLocationManager headingAvailable])
    {
        locationManager.headingFilter = kCLHeadingFilterNone;
        locationManager.delegate = self;
        [locationManager startUpdatingHeading];
    }
    else
    {
        NSLog(@"Heading is not available on this device");
        self.locationManager = nil;
    }
}

- (void)stopAbsoluteMotion
{
    if ([CLLocationManager locationServicesEnabled])
        [locationManager stopUpdatingLocation];
    if ([CLLocationManager headingAvailable])
        [locationManager stopUpdatingHeading];
}

#pragma mark - CLLocationManagerDelegate methods

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation
{
    currentCoordinate = newLocation.coordinate;
}

- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region
{
    if ([[region identifier] compare:@"virtual fence"]) insideVirtualFence = true;
}

- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region
{
    if ([[region identifier] compare:@"virtual fence"]) insideVirtualFence = false;
}

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)heading
{
    if (heading.headingAccuracy  < 0) return;
    
    if (heading.trueHeading > 0) currentHeading = heading.trueHeading;
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    NSLog(@"Error: %@",[error localizedDescription]);
}

@end