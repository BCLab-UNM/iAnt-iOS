//
//  LineSegment2D.m
//  AntBot-iOS
//
//  Created by Joshua Hecker
//  Moses Lab, Department of Computer Science, University of New Mexico
//

#import "LineSegment2D.h"

@implementation LineSegment2D

- (id)initStartTo:(Rect2D*)startPoint andEndTo:(Rect2D*)endPoint {
    if (self = [super init]) {
        start = startPoint;
        end = endPoint;
    }
    
    return self;
}

- (Rect2D*)getStart {
    return start;
}

- (Rect2D*)getEnd {
    return end;
}

@end