//
//  Utilities.m
//  AntBot
//
//  Created by Joshua Hecker on 2/1/13.
//
//

#import "Utilities.h"

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

@end
