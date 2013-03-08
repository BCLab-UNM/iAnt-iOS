//
//  FinderPattern.h
//  AntBot-iOS
//
//  Created by Joshua Hecker
//  Moses Lab, Department of Computer Science, University of New Mexico
//

#import "LineSegment2D.h"

@interface FinderPattern : NSObject

@property NSMutableArray *segments;
@property int columnsSinceLastModified;

+ (int)checkFinderRatioFor:(int[5])stateCount;

@end