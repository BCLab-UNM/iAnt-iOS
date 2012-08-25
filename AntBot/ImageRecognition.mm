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

@synthesize center;
@synthesize imgThresholdUI;
@synthesize imgIpl;
@synthesize imgGrayBGRA;
@synthesize maskIpl;

- (ImageRecognition*)imageRecognition {
    ImageRecognition* imgRecog = [[ImageRecognition alloc] init];
    return imgRecog;
}

#pragma mark - Higher-level vision functions

- (Cartesian2D)findColorCentroidIn:(CMSampleBufferRef)buffer usingThreshold:(NSArray*)ranges {    
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
    Cartesian2D c;
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

- (BOOL)locateQRFinderPatternIn:(UIImage*)buffer
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
    cvThreshold(imgGray, imgGray, 180, 255, CV_THRESH_BINARY);
    
    int stateCount[5] = {0};
    int currentState = 0;
    for (int row=0; row<imgGray->height; row++) {
        stateCount[0] = 0;
        stateCount[1] = 0;
        stateCount[2] = 0;
        stateCount[3] = 0;
        stateCount[4] = 0;
        currentState = 0;
        
        for(int col=0; col<imgGray->width; col++) {
            uchar *ptr = (uchar*)(imgGray->imageData + row*imgGray->widthStep + col);
            if (ptr[0] < 128) {
                // We're at a black pixel
                if((currentState & 0x1)==1)
                {
                    // We were counting white pixels
                    // So change the state now
                    
                    // W->B transition
                    currentState++;
                }
                
                // Works for boths W->B and B->B
                stateCount[currentState]++;
            }
            else {
                // We got to a white pixel...
                if((currentState & 0x1)==1) {
                    // W->W change
                    stateCount[currentState]++;
                }
                else {
                    // ...but, we were counting black pixels
                    if(currentState==4) {
                        
                        // We found the 'white' area AFTER the finder patter
                        // Do processing for it here
                        if([self checkFinderRatioFor:stateCount]) {
                            NSLog(@"found");
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
                        stateCount[0] = 0;
                        stateCount[1] = 0;
                        stateCount[2] = 0;
                        stateCount[3] = 0;
                        stateCount[4] = 0;
                    }
                    else {
                        // We still haven't go 'out' of the finder pattern yet
                        // So increment the state
                        // B->W transition
                        currentState++;
                        stateCount[currentState]++;
                    }
                }
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
    return NO;
}

- (BOOL)checkFinderRatioFor:(int[5])stateCount {
    int totalFinderSize = 0;
    for(int i=0; i<5; i++)
    {
        int count = stateCount[i];
        totalFinderSize += count;
        if(count==0)
            return false;
    }
    
    if(totalFinderSize<7)
        return false;
    
    // Calculate the size of one module
    int moduleSize = ceil(totalFinderSize / 7.0);
    int maxVariance = moduleSize/2;
    
    bool retVal= ((abs(moduleSize - (stateCount[0])) < maxVariance) &&
                  (abs(moduleSize - (stateCount[1])) < maxVariance) &&
                  (abs(3*moduleSize - (stateCount[2])) < 3*maxVariance) &&
                  (abs(moduleSize - (stateCount[3])) < maxVariance) &&
                  (abs(moduleSize - (stateCount[4])) < maxVariance));
    
    return retVal;
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

# pragma mark - ThresholdRange interface

@implementation ThresholdRange

- (ThresholdRange*)initMinTo:(CvScalar)minimum andMaxTo:(CvScalar)maximum
{
    self = [super init];
    min = minimum;
    max = maximum;
    
    return self;
}

- (CvScalar) getMin;
{
    return min;
}

- (CvScalar) getMax;
{
    return max;
}

@end