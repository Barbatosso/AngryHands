// Copyright 2019 The MediaPipe Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "HandModule.h"

#import <UIKit/UIKit.h>

#import "mediapipe/objc/MPPGraph.h"
#import "mediapipe/objc/MPPCameraInputSource.h"
#import "mediapipe/objc/MPPLayerRenderer.h"
#include "mediapipe/framework/formats/landmark.pb.h"

static NSString* const kGraphName = @"hand_tracking_mobile_gpu";

static const char* kInputStream = "input_video";
static const char* kOutputStream = "output_video";
static const char* kVideoQueueLabel = "com.google.mediapipe.example.videoQueue";
static const char* kLandmarkOutputStream = "hand_landmarks";

@interface HandModule () <MPPGraphDelegate, MPPInputSourceDelegate>

// The MediaPipe graph currently in use. Initialized in viewDidLoad, started in viewWillAppear: and
// sent video frames on _videoQueue.
@property(nonatomic) MPPGraph* mediapipeGraph;

@end

@implementation HandModule {
  /// Render frames in a layer.
  MPPLayerRenderer* _renderer;

  /// Process camera frames on this queue.
  dispatch_queue_t _videoQueue;
    std::vector<mediapipe::NormalizedLandmark> landmarks;
}

#pragma mark - Cleanup methods

- (void)dealloc {
  self.mediapipeGraph.delegate = nil;
  [self.mediapipeGraph cancel];
  // Ignore errors since we're cleaning up.
  [self.mediapipeGraph closeAllInputStreamsWithError:nil];
  [self.mediapipeGraph waitUntilDoneWithError:nil];
}

#pragma mark - MediaPipe graph methods

+ (MPPGraph*)loadGraphFromResource:(NSString*)resource {
  // Load the graph config resource.
  NSError* configLoadError = nil;
  NSBundle* bundle = [NSBundle bundleForClass:[self class]];
  if (!resource || resource.length == 0) {
    return nil;
  }
  NSURL* graphURL = [bundle URLForResource:resource withExtension:@"binarypb"];
  NSData* data = [NSData dataWithContentsOfURL:graphURL options:0 error:&configLoadError];
  if (!data) {
    NSLog(@"Failed to load MediaPipe graph config: %@", configLoadError);
    return nil;
  }

  // Parse the graph config resource into mediapipe::CalculatorGraphConfig proto object.
  mediapipe::CalculatorGraphConfig config;
  config.ParseFromArray(data.bytes, data.length);

  // Create MediaPipe graph with mediapipe::CalculatorGraphConfig proto object.
  MPPGraph* newGraph = [[MPPGraph alloc] initWithGraphConfig:config];
  [newGraph addFrameOutputStream:kLandmarkOutputStream outputPacketType:MPPPacketTypeRaw];
  return newGraph;
}

#pragma mark - UIViewController methods

- (void)prepareInFrame:(CGRect)frame {

  _renderer = [[MPPLayerRenderer alloc] init];
  _renderer.layer.frame = frame;
    [_delegate inserLayer:_renderer.layer];
  _renderer.frameScaleMode = MPPFrameScaleModeFillAndCrop;
  // When using the front camera, mirror the input for a more natural look.
  _renderer.mirrored = YES;

  dispatch_queue_attr_t qosAttribute = dispatch_queue_attr_make_with_qos_class(
      DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, /*relative_priority=*/0);
  _videoQueue = dispatch_queue_create(kVideoQueueLabel, qosAttribute);

//  _cameraSource = [[MPPCameraInputSource alloc] init];
//  [_cameraSource setDelegate:self queue:_videoQueue];
//  _cameraSource.sessionPreset = AVCaptureSessionPresetHigh;
//  _cameraSource.cameraPosition = AVCaptureDevicePositionFront;
//  // The frame's native format is rotated with respect to the portrait orientation.
//  _cameraSource.orientation = AVCaptureVideoOrientationPortrait;

  self.mediapipeGraph = [[self class] loadGraphFromResource:kGraphName];
  self.mediapipeGraph.delegate = self;
  // Set maxFramesInFlight to a small value to avoid memory contention for real-time processing.
  self.mediapipeGraph.maxFramesInFlight = 2;
}

- (void)startGraphAndCamera {
  // Start running self.mediapipeGraph.
  NSError* error;
  if (![self.mediapipeGraph startWithError:&error]) {
    NSLog(@"Failed to start graph: %@", error);
  }
}

#pragma mark - MPPGraphDelegate methods

//// Receives CVPixelBufferRef from the MediaPipe graph. Invoked on a MediaPipe worker thread.
//- (void)mediapipeGraph:(MPPGraph*)graph
//    didOutputPixelBuffer:(CVPixelBufferRef)pixelBuffer
//              fromStream:(const std::string&)streamName {
//  if (streamName == kOutputStream) {
//    // Display the captured image on the screen.
//    CVPixelBufferRetain(pixelBuffer);
//    dispatch_async(dispatch_get_main_queue(), ^{
//      [_renderer renderPixelBuffer:pixelBuffer];
//      CVPixelBufferRelease(pixelBuffer);
//    });
//  }
//}

- (void)mediapipeGraph:(MPPGraph*)graph
       didOutputPacket:(const mediapipe::Packet&)packet
            fromStream:(const std::string&)streamName; {
    landmarks = packet.Get<std::vector<mediapipe::NormalizedLandmark>>();
    NSMutableArray *points = [NSMutableArray new];
    for (auto landmark : landmarks) {
        NSArray *array = @[@(landmark.x()), @(landmark.y()), @(landmark.z())];
        [points addObject:array];
    }
    [_delegate process:points];
}

#pragma mark - MPPInputSourceDelegate methods

// Must be invoked on _videoQueue.
- (void)processVideoFrame:(CVPixelBufferRef)imageBuffer
                timestamp:(CMTime)timestamp
               fromSource:(MPPInputSource*)source {
  [self.mediapipeGraph sendPixelBuffer:imageBuffer
                            intoStream:kInputStream
                            packetType:MPPPacketTypePixelBuffer];
}

@end
