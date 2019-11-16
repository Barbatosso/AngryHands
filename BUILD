MIN_IOS_VERSION = "10.0"

load( "@build_bazel_rules_apple//apple:ios.bzl", "ios_application")

# To use the 3D model instead of the default 2D model, add "--define 3D=true" to the
# bazel build command.
config_setting(
    name = "use_3d_model",
    define_values = {
        "3D": "true",
    },
)

genrule(
    name = "model",
    srcs = select({
        "//conditions:default": ["//mediapipe/models:hand_landmark.tflite"],
        ":use_3d_model": ["//mediapipe/models:hand_landmark_3d.tflite"],
    }),
    outs = ["hand_landmark.tflite"],
    cmd = "cp $< $@",
)

ios_application(
    name = "HandTrackingGpuApp",
    bundle_id = "com.prisma-ai.lensa-app",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = ["Info.plist"],
    minimum_os_version = MIN_IOS_VERSION,
    provisioning_profile = "//mediapipe/examples/ios:provisioning_profile",
    deps = [
        ":HandTrackingGpuAppLibrary",
        "@ios_opencv//:OpencvFramework",
    ],
)

objc_library(
    name = "HandTrackingGpuAppLibrary",
    srcs = [
        "AppDelegate.m",
        "ViewController.mm",
        "main.m"
    ],
    hdrs = [
        "AppDelegate.h",
        "ViewController.h"
    ],
    data = [
        "Base.lproj/LaunchScreen.storyboard",
        "Base.lproj/Main.storyboard",
        ":model",
        "//mediapipe/graphs/hand_tracking:hand_tracking_mobile_gpu_binary_graph",
        "//mediapipe/models:palm_detection.tflite",
        "//mediapipe/models:palm_detection_labelmap.txt",
    ],
    sdk_frameworks = [
        "AVFoundation",
        "CoreGraphics",
        "CoreMedia",
        "UIKit",
    ],
    deps = [
        "//mediapipe/objc:mediapipe_framework_ios",
        "//mediapipe/objc:mediapipe_input_sources_ios",
        "//mediapipe/objc:mediapipe_layer_renderer",
    ] + select({
        "//mediapipe:ios_i386": [],
        "//mediapipe:ios_x86_64": [],
        "//conditions:default": [
            "//mediapipe/graphs/hand_tracking:mobile_calculators",
        ],
    }),
)
