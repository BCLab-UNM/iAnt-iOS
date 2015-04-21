#import "FiducialPipeline.h"

// Knobs to turn
#define TILE_SIZE 12
#define GRADIENT 32
#define MAX_FIDUCIALS 1
#define FIDUCIAL_DIM 30
#define QUALITY AVCaptureSessionPreset352x288
#define GRAYSCALE(x) (*(x) + *(x + 1) + *(x + 2)) / 3

@implementation FiducialPipeline

@synthesize devicePosition, quality, delegate;

- (id)init {
    if(!(self = [super init])){return nil;}
    initialized = NO;
    devicePosition = AVCaptureDevicePositionBack;
    quality = QUALITY;
    thresholder = new TiledBernsenThresholder;
    initialize_treeidmap(&treeidmap);
    lastId = -1;
    return self;
}

- (void)didReceiveFrame:(CMSampleBufferRef)frame fromCamera:(Camera*)camera {
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(frame);
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    UInt8* baseAddress = (uint8_t*)CVPixelBufferGetBaseAddress(imageBuffer);
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    int width = (int)CVPixelBufferGetWidth(imageBuffer);
    int height = (int)CVPixelBufferGetHeight(imageBuffer);
    size_t size = width * height;
    
    UInt8* bytes = new UInt8[size];
    UInt8* original = bytes;
    for(unsigned int i = 0; i < size; i++) {
        *bytes = GRAYSCALE(baseAddress);
        bytes++;
        baseAddress += 4;
    }
    
    bytes = original;

    if(!initialized) {
        initialize_tiled_bernsen_thresholder(thresholder, width, height, TILE_SIZE);
        initialize_fidtrackerX(&fidtrackerx, &treeidmap, NULL);
        initialize_segmenter(&segmenter, width, height, treeidmap.max_adjacencies);
        initialized = YES;
    }
    
    UInt8* thresholded = new UInt8[size];
    tiled_bernsen_threshold(thresholder, thresholded, bytes, 1, width, height, TILE_SIZE, GRADIENT);
    
    step_segmenter(&segmenter, thresholded);
	BOOL fiducialFound = find_fiducialsX(&fiducial, MAX_FIDUCIALS, &fidtrackerx, &segmenter, width, height);
    
    [CATransaction begin];
    [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
    
    if(fiducialFound && (fiducial.id != lastId) && (fiducial.id >= 0)) {
        //Create rectangle to contain object
        CGRect rect = CGRectMake((height - fiducial.y - FIDUCIAL_DIM/2) * ([[camera view] frame].size.width/height),
                                 (fiducial.x - FIDUCIAL_DIM/2) * ([[camera view] frame].size.height/width),
                                 FIDUCIAL_DIM * ([[camera view] frame].size.width/height),
                                 FIDUCIAL_DIM * ([[camera view] frame].size.height/width));
        UIBezierPath* path = [UIBezierPath bezierPathWithRect:rect];
        [[camera shapeLayer] setPath:[path CGPath]];
        
        if([delegate respondsToSelector:@selector(pipeline:didProcessFrame:)]) {
            dispatch_async(dispatch_get_main_queue(), ^ {
                [delegate pipeline:self didProcessFrame:[NSNumber numberWithInt:fiducial.id]];
            });
            lastId = fiducial.id;
        }
    }
    else {
        [[camera shapeLayer] setPath:nil];
    }
    
    [CATransaction commit];
    
    delete[] bytes;
    delete[] thresholded;
}

@end
