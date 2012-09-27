//
//  Point2D.h
//  AntBot
//
//  Created by Joshua Hecker on 8/29/12.
//  Moses Lab, Department of Computer Science, University of New Mexico
//

@interface Point2D : NSObject {
    int x;
    int y;
}

- (id)initXTo:(int)x andYTo:(int)y;

- (int)getX;
- (int)getY;

@end