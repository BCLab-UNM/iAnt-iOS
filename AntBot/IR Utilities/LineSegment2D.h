//
//  LineSegment2D.h
//  AntBot
//
//  Created by Joshua Hecker on 8/29/12.
//  Moses Lab, Department of Computer Science, University of New Mexico
//

#import "Point2D.h"

@interface LineSegment2D : NSObject {
    Point2D *start;
    Point2D *end;
}

- (id)initStartTo:(Point2D*)start andEndTo:(Point2D*)end;

- (Point2D*)getStart;
- (Point2D*)getEnd;

@end