//
//  ThresholdRange.mm
//  AntBot-iOS
//
//  Created by Joshua Hecker on 8/29/12.
//  Moses Lab, Department of Computer Science, University of New Mexico
//

#import "ThresholdRange.h"

@implementation ThresholdRange

- (id)initMinTo:(CvScalar)minimum andMaxTo:(CvScalar)maximum
{
    if (self = [super init]) {
        min = minimum;
        max = maximum;
    }
    
    return self;
}

- (CvScalar)getMin;
{
    return min;
}

- (CvScalar)getMax;
{
    return max;
}

@end