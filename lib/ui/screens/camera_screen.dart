import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:biovault_id/ui/widgets/face_detector_painter.dart';
import 'package:biovault_id/services/face_recognition_service.dart';
import 'package:biovault_id/services/fuzzy_extractor_service.dart';
import 'package:biovault_id/services/blockchain_service.dart';
import 'package:biovault_id/services/ipfs_service.dart';
import 'dart:io';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _cameraController;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false,
      enableClassification: false,
      performanceMode: FaceDetectorMode.fast,
    ),
  );
  bool _isBusy = false;
  CustomPaint? _customPaint;
  List<Face> _faces = [];
  CameraImage? _currentImage;
  DateTime _lastProcessTime = DateTime.now();
  static const int _processIntervalMs = 300; // Process every 300ms
  bool _isEnrolled = false;
  
  // Smoothing bounding box
  Rect? _stableBox;
  static const double _smoothingFactor = 0.7;

  void _updateStableBox(Rect newBox) {
    if (_stableBox == null) {
      _stableBox = newBox;
    } else {
      _stableBox = Rect.fromLTRB(
        _stableBox!.left * _smoothingFactor + newBox.left * (1 - _smoothingFactor),
        _stableBox!.top * _smoothingFactor + newBox.top * (1 - _smoothingFactor),
        _stableBox!.right * _smoothingFactor + newBox.right * (1 - _smoothingFactor),
        _stableBox!.bottom * _smoothingFactor + newBox.bottom * (1 - _smoothingFactor),
      );
    }
  }
  
  // Services
  final FaceRecognitionService _faceService = FaceRecognitionService();
  final FuzzyExtractorService _fuzzyService = FuzzyExtractorService();
  final BlockchainService _blockchainService = BlockchainService(testMode: true);
  final IpfsService _ipfsService = IpfsService(testMode: true);

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _faceService.loadModel();
    _blockchainService.initialize();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.yuv420
          : ImageFormatGroup.bgra8888,
    );

    await _cameraController?.initialize();
    if (!mounted) return;

    debugPrint('Camera initialized: ${_cameraController?.value.previewSize}');

    _cameraController?.startImageStream((image) {
      _currentImage = image;
      _processCameraImage(image);
    });
    setState(() {});
  }

  Future<void> _processCameraImage(CameraImage image) async {
    final now = DateTime.now();
    if (_isBusy || now.difference(_lastProcessTime).inMilliseconds < _processIntervalMs) {
      return;
    }
    _isBusy = true;
    _lastProcessTime = now;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        _isBusy = false;
        return;
      }

      final faces = await _faceDetector.processImage(inputImage);
      _faces = faces;
      
      if (faces.isNotEmpty) {
        _updateStableBox(faces.first.boundingBox);
        debugPrint('Faces found: ${faces.length}, stable box: $_stableBox');
      } else {
        if (now.second % 2 == 0) debugPrint('No faces detected in current frame');
      }

      if (mounted) {
        setState(() {
          if (faces.isEmpty) {
            _customPaint = null;
          } else {
            _customPaint = CustomPaint(
              painter: FaceDetectorPainter(
                faces,
                Size(image.width.toDouble(), image.height.toDouble()),
                inputImage.metadata!.rotation,
              ),
            );
          }
        });
      }
    } catch (e) {
      print("Error processing image: $e");
    } finally {
      _isBusy = false;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_cameraController == null) return null;

    final sensorOrientation = _cameraController!.description.sensorOrientation;
    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);

    if (Platform.isAndroid && image.format.raw == 35) {
      final int width = image.width;
      final int height = image.height;

      final Uint8List yPlane = image.planes[0].bytes;
      final Uint8List uPlane = image.planes[1].bytes;
      final Uint8List vPlane = image.planes[2].bytes;

      final WriteBuffer nv21 = WriteBuffer();
      nv21.putUint8List(yPlane);
      
      for (int i = 0; i < vPlane.length; i++) {
        nv21.putUint8(vPlane[i]);
        if (i < uPlane.length) {
          nv21.putUint8(uPlane[i]);
        }
      }
      
      final bytes = nv21.done().buffer.asUint8List();

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(width.toDouble(), height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    }

    if (format == null || image.planes.isEmpty) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<void> _handleEnroll() async {
    if (_faces.isEmpty || _currentImage == null) {
      _showMessage('No face detected');
      return;
    }

    if (_isEnrolled) {
      _showMessage('Already enrolled. Use Verify to login.');
      return;
    }

    if (_isBusy) return;
    setState(() => _isBusy = true);
    
    try {
      _showMessage('Enrollment: Averaging face samples...');
      final int sensorOrientation = _cameraController!.description.sensorOrientation;
      final embeddings = <List<double>>[];

      for (int i = 0; i < 5; i++) {
        if (_currentImage != null && _stableBox != null) {
          final faceImg = _faceService.cropFace(_currentImage!, _faces.first, sensorOrientation);
          if (faceImg != null) {
            embeddings.add(_faceService.predict(faceImg));
          }
        }
        await Future.delayed(const Duration(milliseconds: 200));
      }

      if (embeddings.length < 3) throw Exception("Failed to capture enough face samples");

      final avgEmbedding = List<double>.filled(512, 0.0);
      for (final emb in embeddings) {
        for (int j = 0; j < 512; j++) {
          avgEmbedding[j] += emb[j] / embeddings.length;
        }
      }
      final embedding = _faceService.l2Normalize(avgEmbedding);
      
      debugPrint('Enrollment: Fuzzy Extractor enrollment...');
      final fuzzyKey = await _fuzzyService.enroll(embedding);
      
      debugPrint('Enrollment: IPFS metadata upload...');
      final encryptedData = _ipfsService.encryptPayload(
        fuzzyKey.metadata.toBase64(), 
        fuzzyKey.privateKey
      );
      final cid = await _ipfsService.uploadEncryptedData(encryptedData);
      
      debugPrint('Enrollment: Blockchain registration...');
      final txHash = await _blockchainService.registerBio(fuzzyKey.publicSyndrome, cid);

      _isEnrolled = true;
      _showResultDialog(
        title: 'Enrollment Successful',
        content: 'Identity created and secured in Local Blockchain.\n\n'
                 'Blockchain Tx: ${txHash?.substring(0, 15)}...\n'
                 'IPFS CID: ${cid.substring(0, 15)}...\n'
                 'Fuzzy Syndrome: ${fuzzyKey.publicSyndrome.substring(0, 15)}...',
      );
    } catch (e) {
      _showError('Enrollment failed: $e');
    } finally {
      setState(() => _isBusy = false);
    }
  }

  Future<void> _handleVerify() async {
    if (_faces.isEmpty || _currentImage == null) {
      _showMessage('No face detected');
      return;
    }

    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      _showMessage('Verification: Matching with blockchain...');

      const mockAddress = "0x71C7656EC7ab88b098defB751B7401B5f6d8976F";
      final userData = await _blockchainService.getUserData(mockAddress);
      
      if (userData == null) {
        throw Exception("User not registered on blockchain");
      }

      final int sensorOrientation = _cameraController!.description.sensorOrientation;
      final embeddings = <List<double>>[];

      for (int i = 0; i < 5; i++) {
        if (_currentImage != null && _stableBox != null) {
          final faceImg = _faceService.cropFace(_currentImage!, _faces.first, sensorOrientation);
          if (faceImg != null) {
            embeddings.add(_faceService.predict(faceImg));
          }
        }
        await Future.delayed(const Duration(milliseconds: 150));
      }

      if (embeddings.length < 3) throw Exception("Failed to capture face samples");

      final avgEmbedding = List<double>.filled(512, 0.0);
      for (final emb in embeddings) {
        for (int j = 0; j < 512; j++) {
          avgEmbedding[j] += emb[j] / embeddings.length;
        }
      }
      final embedding = _faceService.l2Normalize(avgEmbedding);

      final result = await _fuzzyService.verify(embedding, userData['syndrome']);

      if (result.success) {
        await _blockchainService.verifyBio(userData['syndrome']);
        
        _showResultDialog(
          title: 'Verification Success',
          content: 'Identity confirmed via Blockchain.\n\n'
                   'Confidence (Distance): ${result.embeddingDistance.toStringAsFixed(3)}\n'
                   'Corrected Errors: ${result.correctedErrors}',
        );
      } else {
        _showError('Verification failed: Face mismatch\n'
                   'Distance: ${result.embeddingDistance.toStringAsFixed(3)}');
      }
    } catch (e) {
      _showError('Verification failed: $e');
    } finally {
      setState(() => _isBusy = false);
    }
  }

  void _showMessage(String message, {int duration = 2}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: Duration(seconds: duration)),
    );
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error', style: TextStyle(color: Colors.red)),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  void _showResultDialog({required String title, required String content}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _faceDetector.close();
    _faceService.dispose();
    _blockchainService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('BioVault: Decentralized ID'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_cameraController!),
          if (_customPaint != null) _customPaint!,
          if (_isBusy) 
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.person_add,
                  label: 'Enroll',
                  color: Colors.blue,
                  onPressed: (_isBusy || _isEnrolled) ? null : _handleEnroll,
                ),
                _buildActionButton(
                  icon: Icons.verified_user,
                  label: 'Verify',
                  color: Colors.green,
                  onPressed: _isBusy ? null : _handleVerify,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 24),
      label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 8,
      ),
    );
  }
}
