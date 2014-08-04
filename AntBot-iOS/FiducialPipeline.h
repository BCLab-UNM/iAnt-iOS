//
//  FiducialPipeline.h
//  AntBot-iOS
//
//  Created by Bjorn Swenson on 7/16/14.
//
//

#import <Foundation/Foundation.h>
#import "Camera.h"
#import "CameraView.h"

#include "segment.h"
#include "fidtrackX.h"
#include "tiled_bernsen_threshold.h"

@interface FiducialPipeline : NSObject <CameraPipeline> {
    BOOL initialized;
    FidtrackerX fidtrackerx;
    FiducialX *fiducials;
    Segmenter segmenter;
    TreeIdMap treeidmap;
    TiledBernsenThresholder *thresholder;
    int lastId;
}

@end
