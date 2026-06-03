# Improve Face Verification Stability

Lower False Rejection Rate (FRR) by optimizing quantization, using median embeddings, and filtering low-quality frames.

## Proposed Changes

### [FuzzyExtractorService](file:///C:/Ukaaa/Projects/biovault_id/lib/services/fuzzy_extractor_service.dart)

- Lower quantization gain from `7.0` to `3.5` to reduce noise sensitivity.
- Update `_calculateDistance` and `_quantizeEmbedding` to use the new gain.
- Improve `VerificationResult` to distinguish between RS failure and real distance mismatch.
- Add `medianEmbedding` static utility.

### [FaceRecognitionService](file:///C:/Ukaaa/Projects/biovault_id/lib/services/face_recognition_service.dart)

- Add a method `estimateQuality` to detect blurry or poorly lit images using Laplacian variance.

### [CameraScreen](file:///C:/Ukaaa/Projects/biovault_id/lib/ui/screens/camera_screen.dart)

- Update `_handleEnroll` and `_handleVerify` to:
    - Capture frames and filter them using `estimateQuality`.
    - Use `medianEmbedding` instead of averaging.
- Update UI to show more descriptive error messages when RS decoding fails (e.g., "Too much noise, please use better lighting").

## Verification Plan

### Automated Tests
- I will add a unit test `test/services/fuzzy_extractor_test.dart` to verify that lowering gain improves stability against small noise.
- I will run `flutter test test/services/fuzzy_extractor_test.dart`.

### Manual Verification
- Since I cannot run the app on a physical device with a camera, I will rely on simulated inputs in unit tests to verify the logic.
- I will use `adb shell` if available to check logs if I had a device, but for now, unit tests are the primary way.
