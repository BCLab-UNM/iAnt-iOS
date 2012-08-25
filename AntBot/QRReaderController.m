//
//  QRReaderController.m
//  AntBot
//
//  Created by Joshua Hecker on 6/8/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "QRReaderController.h"

@implementation QRReaderController


//@synthesize readerView;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    //for (AVCaptureDevice *d in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo])
        //if ([d position] == AVCaptureDevicePositionFront) [readerView setDevice:d];
    
//    [readerView setReaderDelegate:self];
//    [readerView setTorchMode:0];
//    [[readerView scanner] setSymbology:0 config: ZBAR_CFG_ENABLE to:0];
//    [[readerView scanner] setSymbology:ZBAR_QRCODE config:ZBAR_CFG_ENABLE to:1];
//    [[readerView scanner] setSymbology:0 config:ZBAR_CFG_X_DENSITY to:4];
//    [[readerView scanner] setSymbology:0 config:ZBAR_CFG_X_DENSITY to:4];
//    [readerView setShowsFPS:YES];
//    [readerView setPreviewTransform:CGAffineTransformMakeRotation(M_PI/4)];
//    
//    for (AVCaptureOutput *d in [[readerView session] outputs])
//    
//    cblMgr = [CableManager cableManager];
//    [cblMgr setDelegate:self];
//    
//    [ZBarReaderView class];
}

- (void)viewDidUnload
{
    infoBox = nil;
    [super viewDidUnload];
    
//    [readerView setReaderDelegate:nil];
//    readerView = nil;
}

- (void) viewDidAppear: (BOOL) animated
{
    //[readerView start];
    //[cblMgr send:@"tag on"];
    [infoBox setText:@"TAG ON"];
}

- (void) viewWillDisappear: (BOOL) animated
{
    //[cblMgr send:@"tag off"];
    [infoBox setText:@"TAG OFF"];
    
    //[readerView stop];
}

#pragma mark - ZBarReaderViewDelegate methods

//- (void) readerView:(ZBarReaderView *)view didReadSymbols:(ZBarSymbolSet *)syms fromImage:(UIImage *)img
//{
//    for(ZBarSymbol *sym in syms)
//    {
//        [infoBox setText:sym.data];
//        [cblMgr send:@"s"];
//        break;
//    }
//}

#pragma mark - RscMgrDelegate methods

- (void)readBytesAvailable:(UInt32)numBytes
{
    NSString *data;
    
    data = [cblMgr receive:numBytes];
    
    if ([data isEqualToString:@"tag off\r\n"])
    {
        [self performSegueWithIdentifier:@"CameraSegue" sender:self];
    }
    
    else
    {
        NSLog(@"Error - The command \"%@\" is not recognized",data);
    }
}

- (void) cableConnected:(NSString *)protocol
{
    [cblMgr setBaud:9600];
	[cblMgr open];
}

- (void)cableDisconnected
{
    exit(0);
}

- (void)portStatusChanged {}

@end
