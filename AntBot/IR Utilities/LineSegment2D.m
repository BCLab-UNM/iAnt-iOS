//
//  LineSegment2D.m
//  AntBot
//
//  Created by Joshua Hecker on 8/29/12.
//  Moses Lab, Department of Computer Science, University of New Mexico
//

#import "LineSegment2D.h"

@implementation LineSegment2D

- (id)initStartTo:(Point2D*)startPoint andEndTo:(Point2D*)endPoint {
    if (self = [super init]) {
        start = startPoint;
        end = endPoint;
    }
    
    return self;
}

- (Point2D*)getStart {
    return start;
}

- (Point2D*)getEnd {
    return end;
}

@end