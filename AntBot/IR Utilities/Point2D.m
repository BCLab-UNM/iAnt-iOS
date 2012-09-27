//
//  Point2D.m
//  AntBot
//
//  Created by Joshua Hecker on 8/29/12.
//  Moses Lab, Department of Computer Science, University of New Mexico
//

#import "Point2D.h"

@implementation Point2D

- (id)initXTo:(int)_x andYTo:(int)_y {
    if (self = [super init]) {
        x = _x;
        y = _y;
    }
    
    return self;
}

- (int)getX {
    return x;
}

- (int)getY {
    return y;
}

@end