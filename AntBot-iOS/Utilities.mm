//
//  Utilities.m
//  AntBot
//
//  Created by Joshua Hecker on 2/1/13.
//
//

#import "Utilities.h"
#include <sys/sysctl.h>
#include <net/if.h>
#include <net/if_dl.h>

@implementation Utilities

/**
 *	Calculates angle between two compass headings in degrees
 *	Return value is bounded between -180 and 180
 **/
+ (float)angleFrom:(float)start to:(float)end {
	float angle = [self rad2deg:atan2([self pol2cart:Polar(1,end)].y,[self pol2cart:Polar(1,end)].x) -
                   atan2([self pol2cart:Polar(1,start)].y,[self pol2cart:Polar(1,start)].x)];
	if (angle > 180) return(angle - 360);
	else if (angle < -180) return(angle + 360);
	else return(angle);
}

/**
 *	Converts degrees to radians
 **/
+ (float)deg2rad:(float)degree {
	return (degree * (M_PI/180));
}

/**
 *	Converts radians to degrees
 **/
+ (float)rad2deg:(float)radian {
	return (radian * (180/M_PI));
}

/**
 *	Converts polar to cartesian coordinates
 **/
+ (Cartesian)pol2cart:(Polar)pol {
	if ((pol.theta == 90.0) || (pol.theta == 270.0))
		return (Cartesian(0,pol.r*sin([self deg2rad:pol.theta])));
	else if ((pol.theta == 90.0) || (pol.theta == 270.0))
		return (Cartesian(pol.r*cos([self deg2rad:pol.theta]),0));
	else
		return (Cartesian(pol.r*cos([self deg2rad:pol.theta]),pol.r*sin([self deg2rad:pol.theta])));
}

/**
 *	Converts cartesian to polar coordinates
 **/
+ (Polar)cart2pol:(Cartesian)cart {
	if (cart.y < 0)
	{
		if (cart.x < 0) return Polar(sqrt(pow(cart.x,2)+pow(cart.y,2)),[self rad2deg:atan(cart.y/cart.x)]+180);
		else if (cart.x > 0) return Polar(sqrt(pow(cart.x,2)+pow(cart.y,2)),[self rad2deg:atan(cart.y/cart.x)]+360);
		else return Polar(sqrt(pow(cart.x,2)+pow(cart.y,2)),270);
	}
    
	else if (cart.y > 0)
	{
		if (cart.x < 0) return Polar(sqrt(pow(cart.x,2)+pow(cart.y,2)),[self rad2deg:atan(cart.y/cart.x)]+180);
		else if (cart.x > 0) return Polar(sqrt(pow(cart.x,2)+pow(cart.y,2)),[self rad2deg:atan(cart.y/cart.x)]);
		else return Polar(sqrt(pow(cart.x,2)+pow(cart.y,2)),90);
	}
	else
	{
		if (cart.x < 0) return Polar(sqrt(pow(cart.x,2)+pow(cart.y,2)),180);
		else return Polar(sqrt(pow(cart.x,2)+pow(cart.y,2)),0);
	}
}

/**
 *  Return MAC Address of device
 */
+ (NSString*)getMacAddress {
    int                 mgmtInfoBase[6];
    char                *msgBuffer = NULL;
    size_t              length;
    unsigned char       macAddress[6];
    struct if_msghdr    *interfaceMsgStruct;
    struct sockaddr_dl  *socketStruct;
    NSString            *errorFlag = nil;
    
    // Setup the management Information Base (mib)
    mgmtInfoBase[0] = CTL_NET;        // Request network subsystem
    mgmtInfoBase[1] = AF_ROUTE;       // Routing table info
    mgmtInfoBase[2] = 0;
    mgmtInfoBase[3] = AF_LINK;        // Request link layer information
    mgmtInfoBase[4] = NET_RT_IFLIST;  // Request all configured interfaces
    
    // With all configured interfaces requested, get handle index
    if ((mgmtInfoBase[5] = if_nametoindex("en0")) == 0) {
        errorFlag = @"if_nametoindex failure";
    }
    else
    {
        // Get the size of the data available (store in len)
        if (sysctl(mgmtInfoBase, 6, NULL, &length, NULL, 0) < 0) {
            errorFlag = @"sysctl mgmtInfoBase failure";
        }
        else {
            // Alloc memory based on above call
            if ((msgBuffer = (char*)malloc(length)) == NULL) {
                errorFlag = @"buffer allocation failure";
            }
            else {
                // Get system information, store in buffer
                if (sysctl(mgmtInfoBase, 6, msgBuffer, &length, NULL, 0) < 0) {
                    errorFlag = @"sysctl msgBuffer failure";
                }
            }
        }
    }
    
    // Befor going any further...
    if (errorFlag != nil) {
        free(msgBuffer);
        NSLog(@"Error: %@", errorFlag);
        return errorFlag;
    }
    
    // Map msgbuffer to interface message structure
    interfaceMsgStruct = (struct if_msghdr *) msgBuffer;
    
    // Map to link-level socket structure
    socketStruct = (struct sockaddr_dl *) (interfaceMsgStruct + 1);
    
    // Copy link layer address data in socket structure to an array
    memcpy(&macAddress, socketStruct->sdl_data + socketStruct->sdl_nlen, 6);
    
    // Read from char array into a string object, into traditional Mac address format
    NSString *macAddressString = [NSString stringWithFormat:@"%02X:%02X:%02X:%02X:%02X:%02X",
                                  macAddress[0], macAddress[1], macAddress[2],
                                  macAddress[3], macAddress[4], macAddress[5]];
    
    // Release the buffer memory
    free(msgBuffer);
    
    return macAddressString;
}

@end
