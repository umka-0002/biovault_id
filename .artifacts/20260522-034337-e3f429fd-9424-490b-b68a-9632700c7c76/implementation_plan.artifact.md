# Fix Isolate Initialization and Camera Lifecycle Crashes

Address the `Binding has not yet been initialized` error in background isolates and the `FlutterJNI` detached crash during disposal.

## User Review Required

- **Isolate Architecture**: I will pass the model as a `Uint8List` byte array into the isolate instead of using `Interpreter.fromAsset` inside it. This avoids needing `WidgetsFlutterBinding` or asset resolution logic in the background isolate, which is the source of the "Binding" error.
- **Isolate Throttling**: I'll switch from `compute` (which creates a new isolate every time) to a long-lived worker isolate if necessary, but starting with `compute` + byte-buffer to fix the immediate crash.

## Proposed Changes

### [FaceRecognitionService](file:///C:/Ukaaa/Projects/biovault_id/lib/services/face_recognition_service.dart)

- **Model Loading**: Pre-load the model into a `Uint8List` in `loadModel`.
- **Inference Task**: Update `_inferenceTask` to accept the model bytes and use `Interpreter.fromBuffer`.
- **Binding Fix**: Ensure no Flutter-specific getters (like `ServicesBinding`) are accessed in the static task.

### [CameraScreen](file:///C:/Ukaaa/Projects/biovault_id/lib/ui/screens/camera_screen.dart)

- **Crash Fix**: Add an explicit `_cameraController?.dispose()` check and wrap the `startImageStream` callback in a try-catch to ignore post-disposal frames.
- **Processing Flag**: Ensure `_isBusy` is reset correctly even if an exception occurs.

### [main.dart](file:///C:/Ukaaa/Projects/biovault_id/lib/main.dart)

- **Binding Initialization**: Ensure `WidgetsFlutterBinding.ensureInitialized()` is at the top of `main`.

## Verification Plan

### Automated Tests
- `test/face_recognition_service_test.dart`: (If exists) Verify model buffer loading.

### Manual Verification
- **Build & Run**: Confirm the app starts and camera opens.
- **Enrollment**: Press "Enroll" and ensure no "Binding not initialized" dialog appears.
- **Disposal**: Open and close the camera screen rapidly to verify no `FlutterJNI` crash occurs.
