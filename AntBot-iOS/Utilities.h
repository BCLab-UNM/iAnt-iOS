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

#ifdef __cplusplus
struct Cartesian {
    Cartesian(){}
    Cartesian(float a, float b):x(a),y(b){}
    bool operator==(const Cartesian other) {
        return ((x == other.x) && (y == other.y));
    }
    bool operator!=(const Cartesian other) {
        return ((x != other.x) || (y != other.y));
    }
    Cartesian operator+=(const Cartesian other) {
        x += other.x;
        y += other.y;
        return *this;
    }
    Cartesian operator+(const Cartesian b) {
        *this += b;
        return *this;
    }
    Cartesian operator-=(const Cartesian other) {
        x -= other.x;
        y -= other.y;
        return *this;
    }
    Cartesian operator-(const Cartesian b) {
        *this -= b;
        return *this;
    }
    float x,y;
};
struct Polar {
    Polar(){}
    Polar(float a, float b):r(a),theta(b){}
    float r,theta;
};

+ (float)angleFrom:(float)start to:(float)end;
+ (float)deg2rad:(float)degree;
+ (float)rad2deg:(float)radian;
+ (float)clamp:(float)x min:(float)min max:(float)max;
+ (float)exponentialDecay:(float)quantity time:(float)time lambda:(float)lambda;
+ (float)poissonCDF:(float)k lambda:(float)lambda;

+ (Cartesian)pol2cart:(Polar)pol;
+ (Polar)cart2pol:(Cartesian)cart;

+ (float)randomFloat;
+ (float)randomFloat:(float)x;
+ (float)randomWithMean:(float)m standardDeviation:(float)s;
#endif

+ (NSString*)getMacAddress;

@end