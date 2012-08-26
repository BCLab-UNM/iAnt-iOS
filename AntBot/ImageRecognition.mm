//
//  ImageRecognition.m
//  AntBot
//
//  Created by Joshua Hecker on 3/27/12.
//  Moses Lab, Department of Computer Science, University of New Mexico
//

#import "ImageRecognition.h"

#pragma mark - ImageRecognition interface

@implementation ImageRecognition

@synthesize imgThresholdUI;
@synthesize imgIpl;
@synthesize imgGrayBGRA;
@synthesize maskIpl;

- (ImageRecognition*)imageRecognition {
    ImageRecognition* imgRecog = [[ImageRecognition alloc] init];
    return imgRecog;
}

#pragma mark - Higher-level vision functions

- (CvPoint)findColorCentroidIn:(CMSampleBufferRef)buffer usingThreshold:(NSArray*)ranges {
    //Convert CMSampleBuffer to IplImage
    [self createIplImageFromCMSampleBuffer:buffer];
    
    //If mask has not already been loaded into memory
    if (maskIpl == nil) {
        //Load image
        UIImage *maskUI = [UIImage imageNamed:@"mask"];
        
        //Convert UIImage to IplImage
        maskIpl = cvCreateImage(cvSize(maskUI.size.width, maskUI.size.height), IPL_DEPTH_8U, 4);
        maskIpl = [self createIplImageFromUIImage:maskUI];
    }
    
    //Make copy of original image and release it
    IplImage *temp = cvCreateImage(cvGetSize(imgIpl), IPL_DEPTH_8U, 4);
    cvCopy(imgIpl, temp);
    cvReleaseImage(&imgIpl);
    
    //Apply mask to copy to generate final image
    imgIpl = cvCreateImage(cvGetSize(temp), IPL_DEPTH_8U, 4);
    cvCopy(temp, imgIpl, maskIpl);
    cvReleaseImage(&temp);
    
    //Convert BGRA to BGR format
    IplImage* imgBGR = cvCreateImage(cvGetSize(imgIpl), IPL_DEPTH_8U, 3);
    cvCvtColor(imgIpl, imgBGR, CV_BGRA2BGR);
    
    //Convert BGR to HSV format
    IplImage* imgHSV = cvCreateImage(cvGetSize(imgIpl), IPL_DEPTH_8U, 3);
    cvCvtColor(imgBGR, imgHSV, CV_BGR2HSV);
    
    //Union of all thresholded images produced using the provided ranges
    IplImage* imgThresholdUnion = cvCreateImage(cvGetSize(imgIpl), IPL_DEPTH_8U, 1);

    //Do for all range pairs in ranges
    for (int index=0; index<[ranges count]; index++) {
        //Get range at current index
        ThresholdRange *range = [ranges objectAtIndex:index];
        
        //Threshold image
        IplImage* imgThreshold = cvCreateImage(cvGetSize(imgIpl), IPL_DEPTH_8U, 1);
        cvInRangeS(imgHSV, [range getMin], [range getMax], imgThreshold);
        
        //Create negative of thresholded image
        IplImage* imgThresholdInverse = cvCreateImage(cvGetSize(imgIpl), IPL_DEPTH_8U, 1);
        cvNot(imgThresholdUnion, imgThresholdInverse);
        
        //Merge into final thresholded image
        //We use the inverse as a mask to ensure that the white pixels are not overwritten
        cvCopy(imgThreshold, imgThresholdUnion, imgThresholdInverse);
        
        //Free memory
        cvReleaseImage(&imgThreshold);
        cvReleaseImage(&imgThresholdInverse);
    }
    
    //Convert thresholded image back to BGRA for display (see captureOutput callback in MainController)
    if (imgGrayBGRA != nil) {
        cvReleaseImage(&imgGrayBGRA);
    }
    imgGrayBGRA = cvCreateImage(cvGetSize(imgIpl), IPL_DEPTH_8U, 4);
    cvCvtColor(imgThresholdUnion, imgGrayBGRA, CV_GRAY2BGRA);
    
    //convert IplImage to UIImage and store
    imgThresholdUI = [self createUIImageFromIplImage:imgGrayBGRA];
    
    //Calculate centroid of thresholded image
    CvPoint c;
    CvMoments* moments = (CvMoments*)malloc(sizeof(CvMoments)); 
    cvMoments(imgThresholdUnion, moments, 1);
    c.x = cvGetSpatialMoment(moments, 1, 0) / cvGetSpatialMoment(moments, 0, 0); 
    c.y = cvGetSpatialMoment(moments, 0, 1) / cvGetSpatialMoment(moments, 0, 0);
    free(moments);
    
    //Free memory
    cvReleaseImage(&imgBGR);
    cvReleaseImage(&imgHSV);
    cvReleaseImage(&imgThresholdUnion);
    
    return c;
}

- (int)locateQRFinderPatternsIn:(UIImage*)buffer
{
    //Convert CMSampleBuffer to IplImage
    //[self createIplImageFromCMSampleBuffer:buffer];
    if (imgIpl != nil) {
        cvReleaseImage(&imgIpl);
    }
    imgIpl = cvCreateImage(cvSize(buffer.size.width,buffer.size.height), IPL_DEPTH_8U, 4);
    imgIpl = [self createIplImageFromUIImage:buffer];
    
    //Convert to grayscale
    IplImage *imgGray = cvCreateImage(cvGetSize(imgIpl), IPL_DEPTH_8U, 1);
    cvCvtColor(imgIpl, imgGray, CV_BGRA2GRAY);
    
    //Convert to bi-level (i.e. binary)
    //cvThreshold(imgGray, imgGray, 180, 255, CV_THRESH_BINARY);
    cvAdaptiveThreshold(imgGray, imgGray, 255, CV_ADAPTIVE_THRESH_MEAN_C, CV_THRESH_BINARY, 49);
    
    //Create storage variables for finder pattern search
    int stateCount[5]; //counters for each of five regions in the finder pattern
    int currentState; //holds current state
    NSMutableArray *finderPatterns = [[NSMutableArray alloc] init]; //array of discovered finder patterns
    int numberOfFinderPatterns = 0; //number of legitimate finder patterns discovered; returned at function end
    
    //Perform pixel-by-pixel nested loop search through image
    for (int row=0; row<imgGray->height; row++) {
        //Erase storage
        currentState = 0;
        memset(stateCount, 0, sizeof(stateCount));
        
        for(int col=0; col<imgGray->width; col++) {
            uchar *ptr = (uchar*)(imgGray->imageData + row*imgGray->widthStep + col);
            //If pixel is black
            if (ptr[0] < 128) {
                //And current state is a white (i.e. odd)
                if (currentState % 2) {
                    //Then the state should be changed (W->B transition)
                    currentState++;
                }
                //Regardless of state, we increase the state count
                stateCount[currentState]++;
            }
            //Otherwise, pixel is white
            else {
                //If state is white (i.e. odd)
                if (currentState % 2) {
                    //Then increase the state count
                    stateCount[currentState]++;
                }
                //Otherwise, state is black (i.e. even)
                else {
                    //If in final state (i.e. the "accept state" of an FSM)
                    if (currentState == 4) {
                        //Check the ratio for the discovered pixels. If the ratio is correct, proceed by searching for the proper location to store the segment
                        if (int finderSize = [self checkFinderRatioFor:stateCount]) {
                            //Create line segment
                            CvPoint end = cvPoint(row, col);
                            CvPoint start = cvPoint(row, col - finderSize);
                            LineSegment2D *line = [[LineSegment2D alloc] initStartTo:start andEndTo:end];
                            
                            //Create block object for creating and storing a new pattern
                            void (^createPattern)(LineSegment2D*) = ^(LineSegment2D *line) {
                                //If not, create new pattern array and store line segment
                                FinderPattern *pattern = [[FinderPattern alloc] init];
                                [[pattern segments] addObject:line];
                                //Mark pattern as modified
                                [pattern setModifiedFlag:YES];
                                //Initialize patterns array with new pattern
                                [finderPatterns addObject:pattern];
                            };
                            
                            //Check to see if any patterns have been recorded
                            if ([finderPatterns count] > 0) {
                                int counter = 0;
                                //Enumerate through patterns
                                for (; counter < [finderPatterns count]; counter++) {
                                    //Load pattern
                                    FinderPattern *pattern = [finderPatterns objectAtIndex:counter];
                                    //Retrieve newest segment (the segment found on the last iteration of for loop)
                                    LineSegment2D *mostRecentSegment = [[pattern segments] lastObject];
                                    
                                    //If center of the new segment lies above the most recently found segment
                                    if (([line getStart].y + finderSize/2) < [mostRecentSegment getStart].y) {
                                        //Create a new pattern and store the new segment in it
                                        createPattern(line);
                                        //And exit the pattern search
                                        break;
                                    }
                                    //If center of new segment lies within previous segment
                                    else if (([line getStart].y + finderSize/2) < [mostRecentSegment getEnd].y) {
                                        //Append new segment to current pattern
                                        [[pattern segments] addObject:line];
                                        //Mark pattern as modified and update the object
                                        [pattern setModifiedFlag:YES];
                                        [finderPatterns replaceObjectAtIndex:[finderPatterns indexOfObject:pattern]
                                                                  withObject:pattern];
                                        //Quit pattern search
                                        break;
                                    }                                    
                                }
                                
                                //If all patterns have been checked, the new segment must be below current patterns
                                if (counter == [finderPatterns count]) {
                                    //Create a new pattern and store the new segment in it
                                    createPattern(line);
                                }
                            }
                            //If no patterns have been found
                            else {
                                //Create a new pattern and store the new segment in it
                                createPattern(line);
                            }
                        }
                        else {
                            currentState = 3;
                            stateCount[0] = stateCount[2];
                            stateCount[1] = stateCount[3];
                            stateCount[2] = stateCount[4];
                            stateCount[3] = 1;
                            stateCount[4] = 0;
                            continue;
                        }
                        currentState = 0;
                        memset(stateCount, 0, sizeof(stateCount));
                    }
                    //Otherwise, the end of the pattern has not been reached
                    else {
                        // So increment the state (B->W transition)
                        currentState++;
                        //And the state count
                        stateCount[currentState]++;
                    }
                }
            }
        }
        
        //Scan all discovered finder patterns
        int segmentThreshold = 10;
        int counter = 0;
        
        for (; counter < [finderPatterns count]; counter++) {
            //Load pattern
            FinderPattern *pattern = [finderPatterns objectAtIndex:counter];
            //If pattern was not modified in previous loop iteration
            if (![pattern modifiedFlag]) {
                //Remove pattern from array
                [finderPatterns removeObjectAtIndex:[finderPatterns indexOfObject:pattern]];
                
                NSLog(@"Number of segments: %d",[[pattern segments] count]);
                
                int xsum = 0;
                int ysum = 0;
                for (int i = 0; i < [[pattern segments] count]; i++) {
                    xsum += (([[[pattern segments] objectAtIndex:i] getEnd].x -
                              [[[pattern segments] objectAtIndex:i] getStart].x) / 2) +
                    [[[pattern segments] objectAtIndex:i] getStart].x;
                    ysum += (([[[pattern segments] objectAtIndex:i] getEnd].y -
                              [[[pattern segments] objectAtIndex:i] getStart].y) / 2) +
                    [[[pattern segments] objectAtIndex:i] getStart].y;
                }
                
                NSLog(@"Centroid: %d,%d",xsum/[[pattern segments] count],ysum/[[pattern segments] count]);
                
                //If the number of segments found for the pattern is above a defined threshold
                if ([[pattern segments] count] > segmentThreshold) {
                    //Then increment the total
                    numberOfFinderPatterns++;
                }
            }
            //Otherwise, it was modified
            else {
                //Reset flag and update the object
                [pattern setModifiedFlag:NO];
                [finderPatterns replaceObjectAtIndex:[finderPatterns indexOfObject:pattern] withObject:pattern];
            }
        }
    }
    
    if (imgGrayBGRA != nil) {
        cvReleaseImage(&imgGrayBGRA);
    }
    imgGrayBGRA = cvCreateImage(cvGetSize(imgIpl), IPL_DEPTH_8U, 4);
    cvCvtColor(imgGray, imgGrayBGRA, CV_GRAY2BGRA);
    
    imgThresholdUI = [self createUIImageFromIplImage:imgGrayBGRA];
    
    cvReleaseImage(&imgGray);
    return numberOfFinderPatterns;
}

- (int)checkFinderRatioFor:(int[5])stateCount {
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

#pragma mark - UIImage <--> IplImage functions

//Create a IplImage from sample buffer data
- (void)createIplImageFromCMSampleBuffer:(CMSampleBufferRef)buffer
{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(buffer);
    CVPixelBufferLockBaseAddress(imageBuffer,0); //Lock the image buffer 
    
    //Get information of the image
    void *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    CvSize size = cvSize(width,height);
    
    //Create IplImage
    if (imgIpl != nil) cvReleaseImage(&imgIpl);
    imgIpl = cvCreateImageHeader(size, IPL_DEPTH_8U, 4);
    imgIpl->widthStep = bytesPerRow;
    imgIpl->imageSize = bytesPerRow * height;
    cvCreateData(imgIpl);
    memcpy(imgIpl->imageData, baseAddress, height * bytesPerRow);
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
}

//Convert IplImage (standard OpenCV image format) to UIImage (standard Obj-C image format)
- (UIImage*)createUIImageFromIplImage:(IplImage *)image
{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    NSData *data = [[NSData alloc] initWithBytesNoCopy:image->imageData length:image->imageSize freeWhenDone:NO];
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    CGImageRef imageRef = CGImageCreate(image->width, image->height,
                                        image->depth, image->depth * image->nChannels, image->widthStep,
                                        colorSpace, kCGImageAlphaPremultipliedLast|kCGBitmapByteOrderDefault,
                                        provider, NULL, false, kCGRenderingIntentDefault);
    
    UIImage *imageUI = [UIImage imageWithCGImage:imageRef];
    
    CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(provider);
    CGImageRelease(imageRef);
    
    return imageUI;
}

//Convert UIImage to IplImage
- (IplImage*)createIplImageFromUIImage:(UIImage*)image;
{
    CGImageRef imageRef = [image CGImage];
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    IplImage *imageIpl = cvCreateImage(cvSize(image.size.width,image.size.height), IPL_DEPTH_8U, 4);
    
    CGContextRef contextRef = CGBitmapContextCreate(imageIpl->imageData, imageIpl->width, imageIpl->height,
                                                    imageIpl->depth, imageIpl->widthStep,
                                                    colorSpace, kCGImageAlphaPremultipliedLast|kCGBitmapByteOrderDefault);
    
    CGContextDrawImage(contextRef,CGRectMake(0, 0, image.size.width, image.size.height),imageRef);

    CGColorSpaceRelease(colorSpace);
    CGContextRelease(contextRef);
    
    return imageIpl;
}
@end

# pragma mark - LineSegment2D implementation

@implementation LineSegment2D

- (LineSegment2D*)initStartTo:(CvPoint)startPoint andEndTo:(CvPoint)endPoint {
    self = [super init];
    start = startPoint;
    end = endPoint;
    
    return self;
}

- (CvPoint)getStart {
    return start;
}

- (CvPoint)getEnd {
    return end;
}

@end

#pragma mark - FinderPattern implementation

@implementation FinderPattern

@synthesize segments;
@synthesize modifiedFlag;

- (id)init {
    self = [super init];
    segments = [[NSMutableArray alloc] init];
    modifiedFlag = false;
    
    return self;
}

@end

# pragma mark - ThresholdRange implementation

@implementation ThresholdRange

- (ThresholdRange*)initMinTo:(CvScalar)minimum andMaxTo:(CvScalar)maximum
{
    self = [super init];
    min = minimum;
    max = maximum;
    
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