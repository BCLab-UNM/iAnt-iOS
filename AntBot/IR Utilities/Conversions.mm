//
//  Conversions.mm
//  AntBot-iOS
//
//  Created by Joshua Hecker on 8/29/12.
//
//

#import "Conversions.h"

@implementation Conversions

@synthesize imgThresholdUI;
@synthesize imgIpl;
@synthesize imgData;

#pragma mark - UIImage <--> IplImage functions

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
    imgIpl->widthStep = bytesPerRow;
    imgIpl->imageSize = bytesPerRow * height;
    memmove(imgIpl->imageData, baseAddress, height * bytesPerRow);
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

//Convert IplImage (standard OpenCV image format) to UIImage (standard Obj-C image format)
- (void)createUIImageFromIplImage:(IplImage*)image
{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    [imgData replaceBytesInRange:NSMakeRange(0, image->imageSize) withBytes:image->imageData];
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef) imgData);
    CGImageRef imageRef = CGImageCreate(image->width, image->height,
                                        image->depth, image->depth * image->nChannels, image->widthStep,
                                        colorSpace, kCGImageAlphaPremultipliedLast|kCGBitmapByteOrderDefault,
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
                                                    colorSpace, kCGImageAlphaPremultipliedLast|kCGBitmapByteOrderDefault);
    
    CGContextDrawImage(contextRef,CGRectMake(0, 0, [image size].width, [image size].height),imageRef);
    CGColorSpaceRelease(colorSpace);
    CGContextRelease(contextRef);
    
    return imageIpl;
}

@end
