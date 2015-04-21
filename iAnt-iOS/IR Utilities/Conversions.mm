#import "Conversions.h"

@implementation Conversions

@synthesize imgThresholdUI;
@synthesize imgIpl;
@synthesize imgData;


//Rotate a UIImage about center by input radians
+ (UIImage*)rotateUIImage:(UIImage*)image customRadians:(float)radians
{
    //Get image size
    CGSize size = [image size];
    
    //Create new image context
    UIGraphicsBeginImageContext(size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    //Translate and rotate about center
    CGContextTranslateCTM(context, 0.5f * size.width, 0.5f * size.height ) ;
    CGContextRotateCTM(context, radians);
    
    //Draw new image
    [image drawInRect:CGRectMake(-size.width * 0.5f, -size.height * 0.5f, size.width, size.height)];
    UIImage *rotatedImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return rotatedImage;
}


#pragma mark - CoreFoundation --> IplImage, UIImage

//Create a IplImage from sample buffer data
- (void)createIplImageFromCMSampleBuffer:(CMSampleBufferRef)buffer
{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(buffer);
    CVPixelBufferLockBaseAddress(imageBuffer,0); //Lock the image buffer
    
    //Get information of the image
    void *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    //Setup IplImage
    imgIpl->widthStep = (int)bytesPerRow;
    imgIpl->imageSize = (int)(bytesPerRow * height);
    
    //Ensure original buffer and new IplImage container are equal in size
    if (imgIpl->imageSize == height * bytesPerRow) {
        memmove(imgIpl->imageData, baseAddress, height * bytesPerRow);
    }
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
}

//Create a UIImage from sample buffer data
+ (UIImage*)createUIImageFromCMSampleBuffer:(CMSampleBufferRef)buffer {
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(buffer);
    CVPixelBufferLockBaseAddress(imageBuffer,0); // Lock the image buffer
    
    //Get information of the image
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGContextRef newContext = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGImageRef newImage = CGBitmapContextCreateImage(newContext);
    CGContextRelease(newContext);
    
    UIImage *outputImage = [UIImage imageWithCGImage:newImage];
    
    CGColorSpaceRelease(colorSpace);
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    CGImageRelease(newImage);
    
    return outputImage;
}


#pragma mark - UIImage <--> IplImage functions

//Convert IplImage (standard OpenCV image format) to UIImage (standard Obj-C image format)
- (void)createUIImageFromIplImage:(IplImage*)image
{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    [imgData replaceBytesInRange:NSMakeRange(0, image->imageSize) withBytes:image->imageData];
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef) imgData);
    CGImageRef imageRef = CGImageCreate(image->width, image->height,
                                        image->depth, image->depth * image->nChannels, image->widthStep,
                                        colorSpace, kCGImageAlphaPremultipliedFirst|kCGBitmapByteOrder32Little,
                                        provider, NULL, false, kCGRenderingIntentDefault);
    
    imgThresholdUI = [UIImage imageWithCGImage:imageRef];
    
    CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(provider);
    CGImageRelease(imageRef);
}

//Convert UIImage to IplImage
- (IplImage*)createIplImageFromUIImage:(UIImage*)image;
{
    CGImageRef imageRef = [image CGImage];
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    IplImage *imageIpl = cvCreateImage(cvSize([image size].width,[image size].height), IPL_DEPTH_8U, 4);
    CGContextRef contextRef = CGBitmapContextCreate(imageIpl->imageData, imageIpl->width, imageIpl->height,
                                                    imageIpl->depth, imageIpl->widthStep,
                                                    colorSpace, kCGImageAlphaPremultipliedFirst|kCGBitmapByteOrder32Little);
    
    CGContextDrawImage(contextRef,CGRectMake(0, 0, [image size].width, [image size].height),imageRef);
    CGColorSpaceRelease(colorSpace);
    CGContextRelease(contextRef);
    
    return imageIpl;
}

@end
