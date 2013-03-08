//
//  ThresholdRange.h
//  AntBot-iOS
//
//  Created by Joshua Hecker
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