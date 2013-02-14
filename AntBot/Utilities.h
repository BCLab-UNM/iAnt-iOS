//
//  Utilities.h
//  AntBot
//
//  Created by Joshua Hecker on 2/1/13.
//
//

#import <Foundation/Foundation.h>
#import <math.h>

@interface Utilities : NSObject

struct Cartesian {
    Cartesian(float a, float b):x(a),y(b){}
    float x,y;
};
struct Polar {
    Polar(float a, float b):r(a),theta(b){}
    float r,theta;
};

+ (float)angleFrom:(float)start to:(float)end;
+ (float)deg2rad:(float)degree;
+ (float)rad2deg:(float)radian;
+ (Cartesian)pol2cart:(Polar)pol;
+ (Polar)cart2pol:(Cartesian)cart;

@end