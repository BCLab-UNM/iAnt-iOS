//
//  FinderPattern.m
//  AntBot-iOS
//
//  Created by Joshua Hecker on 8/29/12.
//  Moses Lab, Department of Computer Science, University of New Mexico
//

#import "FinderPattern.h"

@implementation FinderPattern

@synthesize segments;
@synthesize columnsSinceLastModified;

- (id)init {
    self = [super init];
    segments = [[NSMutableArray alloc] init];
    columnsSinceLastModified = 0;
    
    return self;
}

+ (int)checkFinderRatioFor:(int[5])stateCount {
    int finderSize = 0;
    
    for (int i=0; i<5; i++) {
        if (stateCount[i] == 0) {
            return 0;
        }
        finderSize += stateCount[i];
    }
    
    if (finderSize < 7) {
        return 0;
    }
    
    // Calculate the size of one module
    int moduleSize = ceil(finderSize / 7.0);
    int maxVariance = moduleSize/2;
    
    bool retVal = ((abs(moduleSize - (stateCount[0])) < maxVariance) &&
                   (abs(moduleSize - (stateCount[1])) < maxVariance) &&
                   (abs(3*moduleSize - (stateCount[2])) < 3*maxVariance) &&
                   (abs(moduleSize - (stateCount[3])) < maxVariance) &&
                   (abs(moduleSize - (stateCount[4])) < maxVariance));
    
    if (retVal) {
        return finderSize;
    }
    else {
        return 0;
    }
}

@end