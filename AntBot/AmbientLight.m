//
//  AmbientLight.m
//  AntBot-iOS
//
//  Created by Joshua Hecker on 7/10/12.
//  Moses Lab, Department of Computer Science, University of New Mexico.
//

#import "AmbientLight.h"

#pragma mark - AmbientLight extension

@interface AmbientLight()

- (void)startAmbientLightSensing;
- (void)stopAmbientLightSensing;

void handleEvent(void* target, void* refcon, IOHIDServiceRef service, IOHIDEventRef event);

@end

@implementation AmbientLight

- (void)start
{
    [self startAmbientLightSensing];
}

- (void)stop
{
    [self stopAmbientLightSensing];
}

- (AmbientLight*)ambientLight
{
    AmbientLight* ambLight = [[AmbientLight alloc] init];
    return ambLight;
}

#pragma mark - Internal start/stop methods

- (void)startAmbientLightSensing
{
    mach_port_t master;
    IOMasterPort(MACH_PORT_NULL, &master);
    
    IOHIDEventSystemRef system = (IOHIDEventSystemRef)IOHIDEventSystemCreate(0);
    
    //Set the PrimaryUsagePage and PrimaryUsage for the Ambient Light Sensor Service 
    int page = 0xff00;
    int usage = 3;
    
    //Create a dictionary to match the service with
    CFNumberRef nums[2];
    CFStringRef keys[2];
    keys[0] = CFSTR("PrimaryUsagePage");
    keys[1] = CFSTR("PrimaryUsage");
    nums[0] = CFNumberCreate(0, kCFNumberSInt32Type, &page);
    nums[1] = CFNumberCreate(0, kCFNumberSInt32Type, &usage);
    
    
    CFDictionaryRef dict = CFDictionaryCreate(0, (const void**)keys, (const void**)nums, 2, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    
    //Get all services matching the above criteria
    CFArrayRef srvs = (CFArrayRef)IOHIDEventSystemCopyMatchingServices(system,dict,0,0,0,0);
    CFRelease(dict);
    
    //Get the service
    IOHIDServiceRef serv = (IOHIDServiceRef)CFArrayGetValueAtIndex(srvs, 0);
    CFRelease(srvs);
    
    //Set the ReportInterval of ALS service to something faster than the default (5428500)
    int interval = 1;
    CFNumberRef num = CFNumberCreate(0, kCFNumberSInt32Type, &interval);
    IOHIDServiceSetProperty((IOHIDServiceRef)serv, CFSTR("ReportInterval"), num);
    CFRelease(num);
    
    //Start event system
    IOHIDEventSystemOpen(system, handleEvent, NULL, NULL, NULL);
}

- (void)stopAmbientLightSensing
{
    //IOHIDEventSystemClose(system, NULL);
    CFRelease(system);
}

#pragma mark - Callback delagate

void handleEvent (void* target, void* refcon, IOHIDServiceRef service, IOHIDEventRef event)
{
    if (IOHIDEventGetType(event)==kIOHIDEventTypeAmbientLightSensor)
    {        
        int luxValue=IOHIDEventGetIntegerValue(event, (IOHIDEventField)kIOHIDEventFieldAmbientLightSensorLevel); // lux Event Field
        int channel0=IOHIDEventGetIntegerValue(event, (IOHIDEventField)kIOHIDEventFieldAmbientLightSensorRawChannel0); // ch0 Event Field
        int channel1=IOHIDEventGetIntegerValue(event, (IOHIDEventField)kIOHIDEventFieldAmbientLightSensorRawChannel1); // ch1 Event Field
        
        //lux==0 : no light, lux==1000+: almost direct sunlight
        NSLog(@"IOHID: ALS Sensor: Lux : %d  ch0 : %d   ch1 : %d",luxValue,channel0,channel1);
    } 
}


@end
