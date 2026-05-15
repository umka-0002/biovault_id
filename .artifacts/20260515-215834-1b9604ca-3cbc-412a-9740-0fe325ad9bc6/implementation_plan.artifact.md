# Implementation Plan: Camera Integration and Face Detection

Implement real-time face detection using the device camera to extract face crops for the `FaceRecognitionService`.

## User Review Required

> [!IMPORTANT]
> This implementation requires the `camera` and `google_mlkit_face_detection` packages, which have been added to `pubspec.yaml`.

## Proposed Changes

### 1. Camera and ML Kit Infrastructure

#### [NEW] [face_detector_painter.dart](file:///C:/Ukaaa/Projects/biovault_id/lib/ui/widgets/face_detector_painter.dart)
- Custom painter to draw face bounding boxes over the camera preview for visual feedback.

#### [camera_screen.dart](file:///C:/Ukaaa/Projects/biovault_id/lib/ui/screens/camera_screen.dart)
- Initialize the camera controller.
- Implement real-time image stream processing.
- Integrate `Google ML Kit Face Detection`.
- Show bounding boxes on top of the preview.
- Provide buttons for "Enroll" and "Verify" which will navigate to respective screens with the captured face.

### 2. Service Enhancements

#### [face_recognition_service.dart](file:///C:/Ukaaa/Projects/biovault_id/lib/services/face_recognition_service.dart)
- Add a utility method to crop a `Face` from a `CameraImage`.
- Ensure it handles rotation and format conversion (YUV420 to RGB).

## Verification Plan

### Automated Tests
- No automated UI tests planned for this phase due to hardware dependency (camera).
- Unit tests for image cropping logic if possible.

### Manual Verification
1. Launch the app on a physical device (Android/iOS).
2. Open the Camera screen.
3. Verify that the camera preview is visible.
4. Verify that a bounding box appears around detected faces.
5. Verify that the "Capture" flow triggers face cropping.
