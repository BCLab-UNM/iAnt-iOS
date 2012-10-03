//
//  ImageRecognition.mm
//  AntBot
//
//  Created by Joshua Hecker on 3/27/12.
//  Moses Lab, Department of Computer Science, University of New Mexico
//

#import "ImageRecognition.h"

#pragma mark - ImageRecognition interface

@implementation ImageRecognition

- (id)initResolutionTo:(int)vertical by:(int)horizontal {
    self = [super init];
    
    converter = [Conversions new];
    
    //Load mask for forward-facing camera
    UIImage *maskUI = [UIImage imageNamed:@"mask"];
    maskIpl = [converter createIplImageFromUIImage:maskUI];
    
    //Setup image containers
    [converter setImgIpl:cvCreateImage(cvSize(vertical, horizontal), IPL_DEPTH_8U, 4)];
    [converter setImgData:[NSMutableData new]];
    imgGray = cvCreateImage(cvSize(vertical, horizontal), IPL_DEPTH_8U, 1);
    imgGrayBGRA = cvCreateImage(cvSize(vertical, horizontal), IPL_DEPTH_8U, 4);
    
    return self;
}

- (UIImage*)getImgThresholdUI {
    return [converter imgThresholdUI];
}

#pragma mark - Higher-level vision functions

- (NSMutableArray*)findColorCentroidIn:(CMSampleBufferRef)buffer usingThreshold:(NSArray*)ranges {
    //convert CMSampleBuffer to IplImage
    [converter createIplImageFromCMSampleBuffer:buffer];
    
    //Make copy of original image and wipe it (set all pixels to black)
    IplImage *temp = cvCreateImage(cvGetSize([converter imgIpl]), IPL_DEPTH_8U, 4);
    cvCopy([converter imgIpl], temp);
    cvSet([converter imgIpl], CV_RGB(0, 0, 0));
    
    //Apply mask to copy to generate final image
    cvCopy(temp, [converter imgIpl], maskIpl);
    cvReleaseImage(&temp);
    
    //convert BGRA to BGR format
    IplImage* imgBGR = cvCreateImage(cvGetSize([converter imgIpl]), IPL_DEPTH_8U, 3);
    cvCvtColor([converter imgIpl], imgBGR, CV_BGRA2BGR);
    
    //convert BGR to HSV format
    IplImage* imgHSV = cvCreateImage(cvGetSize([converter imgIpl]), IPL_DEPTH_8U, 3);
    cvCvtColor(imgBGR, imgHSV, CV_BGR2HSV);
    
    //Union of all thresholded images produced using the provided ranges
    IplImage* imgThresholdUnion = cvCreateImage(cvGetSize([converter imgIpl]), IPL_DEPTH_8U, 1);

    //Do for all range pairs in ranges
    for (int index=0; index<[ranges count]; index++) {
        //Get range at current index
        ThresholdRange *range = [ranges objectAtIndex:index];
        
        //Threshold image
        IplImage* imgThreshold = cvCreateImage(cvGetSize([converter imgIpl]), IPL_DEPTH_8U, 1);
        cvInRangeS(imgHSV, [range getMin], [range getMax], imgThreshold);
        
        //Create negative of thresholded image
        IplImage* imgThresholdInverse = cvCreateImage(cvGetSize([converter imgIpl]), IPL_DEPTH_8U, 1);
        cvNot(imgThresholdUnion, imgThresholdInverse);
        
        //Merge into final thresholded image
        //We use the inverse as a mask to ensure that the white pixels are not overwritten
        cvCopy(imgThreshold, imgThresholdUnion, imgThresholdInverse);
        
        //Free memory
        cvReleaseImage(&imgThreshold);
        cvReleaseImage(&imgThresholdInverse);
    }
    
    //convert thresholded image back to BGRA for display (see captureOutput callback in MainController)
    if (imgGrayBGRA != nil) {
        cvReleaseImage(&imgGrayBGRA);
    }
    imgGrayBGRA = cvCreateImage(cvGetSize([converter imgIpl]), IPL_DEPTH_8U, 4);
    cvCvtColor(imgThresholdUnion, imgGrayBGRA, CV_GRAY2BGRA);
    
    //convert IplImage to UIImage and store
    [converter createUIImageFromIplImage:imgGrayBGRA];
    
    //Calculate centroid of thresholded image
    NSMutableArray *centroidList = nil;
    CvMoments* moments = (CvMoments*)malloc(sizeof(CvMoments)); 
    cvMoments(imgThresholdUnion, moments, 1);
    //If zeroth moment is greater than 0 (i.e. if any white pixels are found in sample image)
    if (cvGetSpatialMoment(moments, 0, 0) > 0) {
        //Calculate centroid
        int x = cvGetSpatialMoment(moments, 1, 0) / cvGetSpatialMoment(moments, 0, 0);
        int y = cvGetSpatialMoment(moments, 0, 1) / cvGetSpatialMoment(moments, 0, 0);
        
        //Locate contours
        CvSeq *contour = 0;
        CvMemStorage *storage = cvCreateMemStorage(0);
        cvFindContours(imgThresholdUnion, storage, &contour, sizeof(CvContour), CV_RETR_EXTERNAL, CV_CHAIN_APPROX_NONE);
        
        //Find largest contour
        double largestArea = 0;
        CvSeq *largestContour = nil;
        for (; contour != 0; contour = contour->h_next) {
            double contourArea = cvContourArea(contour);
            if (contourArea > largestArea) {
                largestArea = contourArea;
                largestContour = contour;
            }
        }
        
        Rect2D *c = nil;
        //If largest contour exists
        if (largestContour != nil) {
            //Calculate bounding box for largest contour
            CvRect boundingBox = cvBoundingRect(largestContour);
            
            //Create centroid structure
            c = [[Rect2D alloc] initXTo:x yTo:y widthTo:boundingBox.width heightTo:boundingBox.height];
        }
        
        else {
            c = [[Rect2D alloc] initXTo:x andYTo:y];
        }
        
        //And add it to the array for output
        centroidList = [[NSMutableArray alloc] initWithObjects:c, nil];
        
        //Free memory
        cvReleaseMemStorage(&storage);
    }
    
    //Free memory
    cvReleaseImage(&imgBGR);
    cvReleaseImage(&imgHSV);
    cvReleaseImage(&imgThresholdUnion);    
    free(moments);
    
    return centroidList;
}

- (NSMutableArray*)locateQRFinderPatternsIn:(CMSampleBufferRef)buffer {
    //Wrap all instructions in autoreleasepool
    //This ensures release of objects from background thread
    @autoreleasepool {
        //converter CMSampleBuffer to IplImage
        [converter createIplImageFromCMSampleBuffer:buffer];
       
        //converter to grayscale
        cvCvtColor([converter imgIpl], imgGray, CV_BGRA2GRAY);
        
        //converter to bi-level (i.e. binary)
        cvThreshold(imgGray, imgGray, 128, 255, CV_THRESH_BINARY);
        //cvAdaptiveThreshold(imgGray, imgGray, 255, CV_ADAPTIVE_THRESH_MEAN_C, CV_THRESH_BINARY, 101);
        
        cvCvtColor(imgGray, imgGrayBGRA, CV_GRAY2BGRA);
        [converter createUIImageFromIplImage:imgGrayBGRA];
        
        //Create storage variables for finder pattern search
        int stateCount[5]; //counters for each of five regions in the finder pattern
        int currentState; //holds current state
        NSMutableArray *finderPatterns = [NSMutableArray new]; //array of discovered finder patterns
        NSMutableArray* centroidList = [NSMutableArray new]; //array of (x,y) pairs denoting pattern centers
        
        //Perform pixel-by-pixel nested loop search through image
        for (int row = 0; row < imgGray->height; row++) {
            //Erase storage
            currentState = 0;
            memset(stateCount, 0, sizeof(stateCount));
            
            for(int col = 0; col < imgGray->width; col++) {
                uchar *ptr = (uchar*)(imgGray->imageData + row*imgGray->widthStep + col);
                //If pixel is black
                if (ptr[0] == 0) {
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
                            if (int finderSize = [FinderPattern checkFinderRatioFor:stateCount]) {
                                //Create line segment
                                Rect2D *end = [[Rect2D alloc] initXTo:row andYTo:col];
                                Rect2D *start = [[Rect2D alloc] initXTo:row andYTo:col - finderSize];
                                LineSegment2D *line = [[LineSegment2D alloc] initStartTo:start andEndTo:end];
                                
                                //Create block object for creating and storing a new pattern
                                void (^createPattern)(LineSegment2D*) = ^(LineSegment2D *line) {
                                    //If not, create new pattern array and store line segment
                                    FinderPattern *pattern = [FinderPattern new];
                                    if ([pattern segments] != nil) {
                                        [[pattern segments] addObject:line];
                                    }
                                    //Clear count of columns since last modification
                                    [pattern setColumnsSinceLastModified:0];
                                    //Initialize patterns array with new pattern
                                    if (finderPatterns != nil) {
                                        [finderPatterns addObject:pattern];
                                    }
                                };
                                
                                //Check to see if any patterns have been recorded
                                if ([finderPatterns count] > 0) {
                                    int counter = 0;
                                    //Enumerate through patterns
                                    for (; counter < [finderPatterns count]; counter++) {
                                        //Load pattern
                                        FinderPattern *pattern = [finderPatterns objectAtIndex:counter];
                                        //Retrieve newest segment (segment found on the last iteration of for loop)
                                        LineSegment2D *mostRecentSegment = [[pattern segments] lastObject];
                                        
                                        //If center of the new segment lies above the most recently found segment
                                        if (([[line getStart] getY] + finderSize/2) <
                                                [[mostRecentSegment getStart] getY]) {
                                            //Create a new pattern and store the new segment in it
                                            createPattern(line);
                                            //And exit the pattern search
                                            break;
                                        }
                                        //If center of new segment lies within previous segment
                                        else if (([[line getStart] getY] + finderSize/2) <
                                                 [[mostRecentSegment getEnd] getY]) {
                                            //Append new segment to current pattern
                                            if ([pattern segments] != nil) {
                                                [[pattern segments] addObject:line];
                                            }
                                            //Clear count of columns since last modification
                                            [pattern setColumnsSinceLastModified:0];
                                            //Quit pattern search
                                            break;
                                        }                                    
                                    }
                                    
                                    //If all patterns have been checked, the new segment must be below patterns
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
            int segmentThreshold = 2;
            int modifiedThreshold = 2;
            
            for (int counter = 0; counter < [finderPatterns count]; counter++) {
                FinderPattern *pattern = nil;
                //Load pattern if available
                if ([finderPatterns count] > counter) {
                    pattern = [finderPatterns objectAtIndex:counter];
                }
                //Otherwise, exit loop
                else {
                    break;
                }
                //If pattern has not been modified after modifiedThreshold columns
                if ([pattern columnsSinceLastModified] > modifiedThreshold) {
                    //Remove pattern from array
                    int index = [finderPatterns indexOfObject:pattern];
                    if ([finderPatterns count] > index) {
                        [finderPatterns removeObjectAtIndex:index];
                    }
                    else {
                        break;
                    }
                    
                    //If the number of segments found for the pattern is above a defined threshold
                    if ([[pattern segments] count] > segmentThreshold) {
                        //Then calculate centroid for pattern and store
                        int xsum = 0;
                        int ysum = 0;
                        for (int i = 0; i < [[pattern segments] count]; i++) {
                            xsum += (([[[[pattern segments] objectAtIndex:i] getEnd] getX] -
                                      [[[[pattern segments] objectAtIndex:i] getStart] getX]) / 2) +
                            [[[[pattern segments] objectAtIndex:i] getStart] getX];
                            ysum += (([[[[pattern segments] objectAtIndex:i] getEnd] getY] -
                                      [[[[pattern segments] objectAtIndex:i] getStart] getY]) / 2) +
                                        [[[[pattern segments] objectAtIndex:i] getStart] getY];
                        }
                        Rect2D *c = [[Rect2D alloc] initXTo:xsum / [[pattern segments] count]
                                                     andYTo:ysum / [[pattern segments] count]];
                        
                        if (centroidList != nil) {
                            [centroidList addObject:c];
                        }
                    }
                }
                //If pattern was not modified in the last iteration of the loop
                else if ([pattern columnsSinceLastModified] >= 0) {
                    //Increment the counter
                    [pattern setColumnsSinceLastModified:([pattern columnsSinceLastModified] + 1)];
                }
                //Otherwise, it was modified in the last iteration, so we leave it alone
            }
        }

        return centroidList;
    }
}

@end