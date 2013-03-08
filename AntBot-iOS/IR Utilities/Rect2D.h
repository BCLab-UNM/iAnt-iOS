//
//  Rect2D.h
//  AntBot-iOS
//
//  Created by Joshua Hecker
//  Moses Lab, Department of Computer Science, University of New Mexico
//

@interface Rect2D : NSObject {
    int x;
    int y;
    int width;
    int height;
    double area;
}

- (id)initXTo:(int)x andYTo:(int)y;
- (id)initXTo:(int)x yTo:(int)y widthTo:(int)width heightTo:(int)height areaTo:(double)area;

- (int)getX;
- (int)getY;
- (int)getWidth;
- (int)getHeight;
- (double)getArea;

@end