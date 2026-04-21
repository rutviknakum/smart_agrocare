import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/services.dart';
import 'package:smart_agrocare/screens/history_screen.dart';
import '../models/scan_record.dart';
import '../theme/app_theme.dart';
import '../services/plant_detector.dart';

class ScanLeafScreen extends StatefulWidget {
  const ScanLeafScreen({super.key});

  @override
  State<ScanLeafScreen> createState() => _ScanLeafScreenState();
}

class _ScanLeafScreenState extends State<ScanLeafScreen>
    with TickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final PlantDetector _detector = PlantDetector();

  XFile? _selectedImage;
  Map<String, dynamic>? _aiResult; // ✅ USED IN _buildResultPreview()
  bool _isAnalyzing = false;
  bool _modelLoaded = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadModel();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadModel() async {
    try {
      await rootBundle.load('assets/models/plant_disease_model.tflite');
      await rootBundle.loadString('assets/categories.json');
      await _detector.loadModel();

      if (mounted) {
        setState(() {
          _modelLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _modelLoaded = false;
        });
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (!_modelLoaded) {
      _showSnackBar('Please wait for AI model to load', Colors.orange);
      return;
    }

    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image != null && mounted) {
        setState(() {
          _selectedImage = image;
          _aiResult = null;
        });
      }
    } catch (e) {
      _showSnackBar('Failed to pick image: $e', Colors.red);
    }
  }

  Future<void> _analyzeImage() async {
    if (_selectedImage == null) {
      _showSnackBar('Please select an image first', Colors.orange);
      return;
    }

    if (!_modelLoaded) {
      _showSnackBar('AI model not ready', Colors.orange);
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _aiResult = null;
    });

    try {
      final result = await _detector.predictImage(_selectedImage!.path);

      // Save to history
      final box = Hive.box<ScanRecord>('scan_records');
      await box.add(
        ScanRecord(
          imagePath: _selectedImage!.path,
          predictedDisease: result['disease'] ?? 'Unknown',
          confidence: result['confidence'] ?? 0.0,
          crop: result['disease']?.toString().split(' ')[0] ?? 'Unknown',
        ),
      );

      if (mounted) {
        setState(() => _aiResult = result);
        _showResultBottomSheet(result);
      }
    } catch (e) {
      _showSnackBar('Analysis failed: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildResultPreview() {
    // ✅ _aiResult is USED HERE - fixes unused_field warning
    if (_aiResult == null || _aiResult!.isEmpty) return const SizedBox.shrink();

    final disease = _aiResult!['disease']?.toString() ?? 'Unknown';
    final confidence = ((_aiResult!['confidence'] ?? 0.0) * 100)
        .toStringAsFixed(1);
    final isHealthy = disease.toLowerCase().contains('healthy');

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isHealthy
              ? [Colors.green.shade50, Colors.green.shade100]
              : [Colors.red.shade50, Colors.red.shade100],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHealthy ? Colors.green : Colors.red,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isHealthy ? Icons.check_circle : Icons.warning,
            color: isHealthy ? Colors.green : Colors.red,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  disease,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isHealthy
                        ? Colors.green.shade800
                        : Colors.red.shade800,
                  ),
                ),
                Text(
                  '$confidence% Confidence',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showResultBottomSheet(Map<String, dynamic> result) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: _ResultBottomSheet(result: result),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'AI Leaf Scanner',
          style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.primaryGreen,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryDarkGreen,
                AppTheme.primaryGreen.withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header with status
            _buildHeader(),

            const SizedBox(height: 16),

            // Image Preview + Result
            Expanded(child: _buildImagePreview()),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildActionButtons(),
                  const SizedBox(height: 16),
                  _buildAnalyzeButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryGreen,
                  AppTheme.primaryGreen.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryGreen.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.science, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Leaf Scanner',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  _modelLoaded
                      ? (_selectedImage != null
                            ? 'Image ready for analysis'
                            : 'Ready to scan')
                      : 'Loading AI model...',
                  style: TextStyle(
                    fontSize: 14,
                    color: _modelLoaded
                        ? (_selectedImage != null
                              ? Colors.green.shade600
                              : Colors.grey.shade600)
                        : Colors.orange.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (!_modelLoaded)
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppTheme.primaryGreen,
                strokeCap: StrokeCap.round,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Column(
      children: [
        // Image Container
        Container(
          height: 320,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _isAnalyzing
                  ? AppTheme.primaryGreen
                  : _selectedImage != null
                  ? Colors.green.shade300
                  : Colors.grey.shade300,
              width: _isAnalyzing ? 4 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Image or Placeholder
                _selectedImage == null
                    ? _buildEmptyState()
                    : Image.file(
                        File(_selectedImage!.path),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) =>
                            _buildEmptyState(),
                      ),

                // Analyzing overlay
                if (_isAnalyzing)
                  Container(
                    color: Colors.black54,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ScaleTransition(
                          scale: _pulseAnimation,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.analytics_outlined,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'AI Analyzing...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        // ✅ _aiResult PREVIEW - Makes field USED
        _buildResultPreview(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      color: Colors.grey.shade100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.grey.shade300, Colors.grey.shade100],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.camera_alt_outlined,
              size: 50,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Tap to select image',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Camera or Gallery',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.camera_alt_rounded,
            label: 'Camera',
            color: Colors.blue.shade500,
            onPressed: () => _pickImage(ImageSource.camera),
            isEnabled: _modelLoaded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            icon: Icons.photo_library_rounded,
            label: 'Gallery',
            color: Colors.purple.shade500,
            onPressed: () => _pickImage(ImageSource.gallery),
            isEnabled: _modelLoaded,
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyzeButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isAnalyzing || _selectedImage == null
            ? null
            : _analyzeImage,
        icon: _isAnalyzing
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.analytics_outlined, size: 24),
        label: Text(
          _isAnalyzing ? 'Analyzing...' : 'Analyze with AI',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryGreen,
          foregroundColor: Colors.white,
          elevation: _selectedImage != null ? 8 : 2,
          shadowColor: AppTheme.primaryGreen.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;
  final bool isEnabled;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    required this.isEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 56,
      child: ElevatedButton.icon(
        onPressed: isEnabled ? onPressed : null,
        icon: Icon(icon, size: 24),
        label: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled ? color : Colors.grey.shade200,
          foregroundColor: isEnabled ? Colors.white : Colors.grey.shade500,
          elevation: isEnabled ? 6 : 0,
          shadowColor: color.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

// ✅ IMPROVED _ResultBottomSheet with REAL DISEASE DATA
class _ResultBottomSheet extends StatelessWidget {
  final Map<String, dynamic> result;

  const _ResultBottomSheet({required this.result});

  @override
  Widget build(BuildContext context) {
    final diseaseName = result['disease']?.toString() ?? 'Unknown';
    final confidence = (result['confidence'] ?? 0.0) * 100;
    final isHealthy = diseaseName.toLowerCase().contains('healthy');

    // ✅ REAL DISEASE TREATMENTS
    final diseaseInfo = _getDiseaseInfo(diseaseName);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isHealthy
                        ? [Colors.green.shade400, Colors.green.shade600]
                        : [Colors.orange.shade400, Colors.orange.shade600],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: (isHealthy ? Colors.green : Colors.orange)
                          .withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  isHealthy ? Icons.check_circle : Icons.warning,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scan Complete!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      '${confidence.toStringAsFixed(1)}% Confidence',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // ✅ MAIN RESULT CARD
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isHealthy
                    ? [Colors.green.shade50, Colors.green.shade100]
                    : [Colors.red.shade50, Colors.red.shade100],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isHealthy ? Colors.green.shade400 : Colors.red.shade400,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isHealthy ? Colors.green : Colors.red).withOpacity(
                    0.15,
                  ),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  isHealthy
                      ? Icons.local_florist
                      : Icons.local_florist_outlined,
                  size: 64,
                  color: isHealthy
                      ? Colors.green.shade500
                      : Colors.red.shade500,
                ),
                const SizedBox(height: 16),
                Text(
                  diseaseName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: isHealthy
                        ? Colors.green.shade800
                        : Colors.red.shade800,
                    height: 1.2,
                  ),
                ),
                if (!isHealthy) ...[
                  const SizedBox(height: 12),
                  Text(
                    diseaseInfo['severity'] ?? '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ✅ TREATMENT & ADVICE SECTION
          if (!isHealthy) ...[
            _TreatmentAdviceSection(diseaseInfo: diseaseInfo),
            const SizedBox(height: 24),
          ],

          // ✅ SAVED CONFIRMATION
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200, width: 1),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green.shade600,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '✅ Scan saved to History automatically',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ✅ FIXED ACTION BUTTONS
          Row(
            children: [
              // ✅ DONE - Closes bottom sheet & returns to scan screen
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  label: const Text('Done'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                    foregroundColor: Colors.grey.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // ✅ VIEW HISTORY - Navigates to History screen
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close bottom sheet

                    // Navigate to HistoryScreen
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const HistoryScreen(),
                      ),
                    );
                  },

                  icon: const Icon(Icons.history, size: 20),
                  label: const Text('View History'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ✅ REAL DISEASE INFORMATION DATABASE
  Map<String, dynamic> _getDiseaseInfo(String diseaseName) {
    final lowerDisease = diseaseName.toLowerCase();

    // Common crop diseases with treatments
    final diseaseData = {
      // Rice diseases
      'bacterial_blight': {
        'severity': 'High Risk - Act Immediately',
        'treatment':
            'Copper-based bactericides (Kocide), Streptomycin, Remove infected plants',
        'prevention':
            'Clean water, Resistant varieties (Swarna), Seed treatment',
      },
      'brown_spot': {
        'severity': 'Moderate Risk',
        'treatment': 'Mancozeb, Propiconazole, Improve drainage',
        'prevention': 'Proper spacing, Balanced NPK fertilizer',
      },
      'leaf_blast': {
        'severity': 'High Risk',
        'treatment': 'Tricyclazole, Isoprothiolane, Silicon supplements',
        'prevention': 'Avoid excess N, Early planting',
      },
      // Tomato diseases
      'early_blight': {
        'severity': 'Moderate Risk',
        'treatment': 'Chlorothalonil, Mancozeb, Crop rotation',
        'prevention': 'Mulching, Stake plants',
      },
      'late_blight': {
        'severity': 'Very High Risk',
        'treatment': 'Mancozeb + Metalaxyl, Ridomil, Remove debris',
        'prevention': 'Good air circulation',
      },
      'leaf_mold': {
        'severity': 'Moderate Risk',
        'treatment': 'Fungicides, Improve ventilation',
        'prevention': 'Greenhouse humidity control',
      },
      // Potato diseases
      'early_blight_potato': {
        'severity': 'Moderate Risk',
        'treatment': 'Dithane M-45, Crop rotation',
        'prevention': 'Remove volunteers',
      },
      'late_blight_potato': {
        'severity': 'Very High Risk',
        'treatment': 'Ridomil Gold, Remove infected tubers',
        'prevention': 'Certified seeds',
      },
      // Default
      'unknown': {
        'severity': 'Consult expert',
        'treatment': 'Contact agricultural extension service',
        'prevention': 'Regular monitoring',
      },
    };

    return diseaseData[lowerDisease] ?? diseaseData['unknown']!;
  }
}

// ✅ NEW TREATMENT ADVICE SECTION
class _TreatmentAdviceSection extends StatelessWidget {
  final Map<String, dynamic> diseaseInfo;

  const _TreatmentAdviceSection({required this.diseaseInfo});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.local_hospital,
                color: Colors.orange.shade700,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Treatment & Prevention',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        _InfoCard(
          title: 'Severity',
          content: diseaseInfo['severity'] ?? '',
          icon: Icons.warning_amber_rounded,
          color: Colors.orange,
        ),
        const SizedBox(height: 12),
        _InfoCard(
          title: 'Immediate Treatment',
          content: diseaseInfo['treatment'] ?? '',
          icon: Icons.science,
          color: Colors.blue,
        ),
        const SizedBox(height: 12),
        _InfoCard(
          title: 'Prevention',
          content: diseaseInfo['prevention'] ?? '',
          icon: Icons.shield,
          color: Colors.green,
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String content;
  final IconData icon;
  final Color color;

  const _InfoCard({
    required this.title,
    required this.content,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
