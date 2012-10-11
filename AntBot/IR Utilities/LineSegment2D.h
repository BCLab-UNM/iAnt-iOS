//
//  LineSegment2D.h
//  AntBot-iOS
//
//  Created by Joshua Hecker on 8/29/12.
//  Moses Lab, Department of Computer Science, University of New Mexico
//

#import "Rect2D.h"

@interface LineSegment2D : NSObject {
    Rect2D *start;
    Rect2D *end;
}

- (id)initStartTo:(Rect2D*)start andEndTo:(Rect2D*)end;

- (Rect2D*)getStart;
- (Rect2D*)getEnd;

@end