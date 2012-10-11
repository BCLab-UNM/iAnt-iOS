//
//  Rect2D.m
//  AntBot-iOS
//
//  Created by Joshua Hecker on 8/29/12.
//  Moses Lab, Department of Computer Science, University of New Mexico
//

#import "Rect2D.h"

@implementation Rect2D

- (id)initXTo:(int)_x andYTo:(int)_y {
    if (self = [super init]) {
        x = _x;
        y = _y;
        width = 40;
        height = 40;
    }
    
    return self;
}

- (id)initXTo:(int)_x yTo:(int)_y widthTo:(int)_width heightTo:(int)_height {
    if (self = [super init]) {
        x = _x;
        y = _y;
        width = _width;
        height = _height;
    }
    
    return self;
}

- (int)getX {
    return x;
}

- (int)getY {
    return y;
}

- (int)getWidth {
    return width;
}

- (int)getHeight {
    return height;
}

@end