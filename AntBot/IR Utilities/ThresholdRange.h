//
//  ThresholdRange.h
//  AntBot-iOS
//
//  Created by Joshua Hecker on 8/29/12.
//  Moses Lab, Department of Computer Science, University of New Mexico
//

@interface ThresholdRange: NSObject {
    CvScalar min;
    CvScalar max;
}

- (id)initMinTo:(CvScalar)min andMaxTo:(CvScalar)max;

- (CvScalar)getMin;
- (CvScalar)getMax;

@end