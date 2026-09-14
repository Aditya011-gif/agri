import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../services/blockchain_service.dart';
import '../../services/gemini_crop_assay_service.dart';
import '../../services/crop_image_validator_service.dart';
import '../../models/crop_benchmark_model.dart';
import '../../widgets/enhanced_app_bar.dart';
import '../../models/crop.dart';
import '../../utils/crop_image_helper.dart';

enum CropAction { sell }

class AddCropScreen extends StatefulWidget {
  const AddCropScreen({super.key});

  @override
  State<AddCropScreen> createState() => _AddCropScreenState();
}

class _AddCropScreenState extends State<AddCropScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController(text: '100 kg');
  final _priceController = TextEditingController();
  final _locationController = TextEditingController(text: 'Karnal Cluster, Haryana');

  String? _selectedImagePath;
  XFile? _cropImageFile;
  XFile? _signatureImage;
  bool _isUploading = false;
  DateTime _harvestDate = DateTime.now();

  // Dynamic crop selection fields (auto-populated by AI image assaying or user dropdown)
  CropType? _selectedCropType;
  CropCategory? _selectedCategory;
  QualityGrade _selectedQualityGrade = QualityGrade.premium;
  final List<CertificationType> _selectedCertifications = [CertificationType.organic];
  CropPricing? _currentPricing;

  // AI Quality Assaying State
  bool _isAnalyzingWithAi = false;
  GeminiCropAssayResult? _aiAssayResult;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _selectImage() async {
    final ImagePicker picker = ImagePicker();
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Upload Crop Sample Photo',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGreen,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Take a photo of your harvested grain or choose an existing photo from gallery for AI assaying.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(ctx, ImageSource.camera),
                      icon: const Icon(Icons.camera_alt, color: Color(0xFF1B5E20)),
                      label: const Text('Camera', style: TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: Color(0xFF1B5E20)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
                      icon: const Icon(Icons.photo_library, color: Colors.white),
                      label: const Text('Gallery', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0xFF1B5E20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    try {
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();

        setState(() {
          _cropImageFile = image;
          _selectedImagePath = image.path;
          _isAnalyzingWithAi = true;
          _aiAssayResult = null;
        });

        // Run Multimodal Google Gemini 2.5 Flash Vision Assaying
        final inspection = await GeminiCropAssayService().inspectAndAssayProduce(
          imageBytes: bytes,
          fileName: image.name,
        );

        if (!inspection.isValidProduce) {
          if (mounted) {
            setState(() {
              _isAnalyzingWithAi = false;
              _cropImageFile = null;
              _selectedImagePath = null;
              _aiAssayResult = null;
            });
            _showInvalidCropImageDialog(
              CropValidationResult.invalid(
                reason: inspection.rejectionReason ?? 'Non-crop image detected.',
                hindiReason: inspection.hindiRejectionReason ?? 'यह फोटो फसल की नहीं लग रही है।',
                detectedSubject: inspection.cropName,
              ),
            );
          }
          return;
        }

        // STRICT QUALITY GATE: Block produce with quality / purity < 50%
        if (inspection.purityScore < 50.0 || inspection.hasRotOrSpoilage) {
          if (mounted) {
            setState(() {
              _isAnalyzingWithAi = false;
              _cropImageFile = null;
              _selectedImagePath = null;
              _aiAssayResult = null;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '⚠️ AI जांच: पहचानी गई फसल (${inspection.cropName}) की गुणवत्ता केवल ${inspection.purityScore.toStringAsFixed(1)}% है (न्यूनतम 50% अनिवार्य)',
                ),
                backgroundColor: Colors.red.shade900,
                duration: const Duration(seconds: 5),
              ),
            );
            _showLowQualityRejectionDialog(
              purityScore: inspection.purityScore,
              cropName: inspection.cropName,
              reason: inspection.assessmentSummary,
            );
          }
          return;
        }

        if (mounted) {
          final assayResult = inspection.toAssayResult();
          final isSpoiled = inspection.hasRotOrSpoilage;

          setState(() {
            _aiAssayResult = assayResult;
            _isAnalyzingWithAi = false;

            // Automatically sync form to the crop detected by Gemini Vision
            _selectedCropType = inspection.detectedCropType;
            _selectedCategory = inspection.detectedCategory;
            _nameController.text = inspection.cropName;
            _descriptionController.text = inspection.description;
            _selectedQualityGrade = inspection.qualityGrade;

            _currentPricing = CropDataHelper.getPricingForCropType(inspection.detectedCropType);
            if (_currentPricing != null && _currentPricing!.marketPrice > 0) {
              _priceController.text = (_currentPricing!.marketPrice / 100).toStringAsFixed(2);
            } else {
              final bm = CropBenchmark.findByName(inspection.cropName);
              if (bm != null && bm.mandiAvgPrice > 0) {
                _priceController.text = (bm.mandiAvgPrice / 100).toStringAsFixed(2);
              }
            }
            if (_quantityController.text.isEmpty) {
              _quantityController.text = '100 kg';
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isSpoiled
                  ? '⚠️ Gemini Vision: सड़े/खराब लक्षण पाए गए (${inspection.agmarkGrade})'
                  : '✅ Gemini Vision: ${inspection.cropName} (${inspection.agmarkGrade}) सत्यापित!'),
              backgroundColor: isSpoiled ? Colors.red.shade800 : AppTheme.primaryGreen,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking crop image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick crop image: $e')),
        );
      }
    }
  }

  void _showInvalidCropImageDialog(CropValidationResult res) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cancel_outlined, color: Colors.red, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'अमान्य फोटो / Image Rejected',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade900,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    res.hindiMessage,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF991B1B),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    res.message,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '⚠️ जरूरी नियम (Produce Photo Rules):',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text('• केवल खेत की कटी फसल या बोरियों के दानों का खुला सैंपल दिखाएं।',
                style: TextStyle(fontSize: 11.5, color: Colors.black87)),
            const Text('• किसी व्यक्ति, गाड़ी, चेहरे, स्क्रीनशॉट या सादे कागज़ की फोटो स्वीकार नहीं होगी।',
                style: TextStyle(fontSize: 11.5, color: Colors.black87)),
            const Text('• फोटो साफ और पर्याप्त रोशनी में खींची होनी चाहिए।',
                style: TextStyle(fontSize: 11.5, color: Colors.black87)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('समझ गया (Understood)'),
          ),
        ],
      ),
    );
  }

  void _showLowQualityRejectionDialog({
    required double purityScore,
    required String cropName,
    required String reason,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '🌾 $cropName: गुणवत्ता 50% से कम',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade900,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Prominent Detected Crop Header
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF87171)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.eco, color: Color(0xFFB91C1C), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'पहचानी गई फसल (Detected Crop): $cropName',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFB91C1C),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'गुणवत्ता स्कोर (Purity):',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade900,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${purityScore.toStringAsFixed(1)}% / 100%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (purityScore / 100.0).clamp(0.0, 1.0),
                    backgroundColor: Colors.red.shade100,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '⚠️ AI Vision ने इस फोटो में "$cropName" की पहचान की है, लेकिन इसमें अत्यधिक फंगल सड़ांध (Fungal Rot / Mold) व खराबी पाई गई है।\n\nAgriChain नियमों के अनुसार 50% से कम शुद्धता वाली फसल ($cropName) को डिजिटल मंडी पर लिस्ट नहीं किया जा सकता।',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF991B1B),
                      height: 1.4,
                    ),
                  ),
                  if (reason.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      reason,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey.shade800,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '💡 किसान के लिए सुधार सलाह (Quality Tips):',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text('• दानों को अच्छी तरह छानकर धूल, खरपतवार और मिट्टी अलग करें।',
                style: TextStyle(fontSize: 11.5, color: Colors.black87)),
            const Text('• धूप में सुखाकर नमी की मात्रा 12% से नीचे लाएं।',
                style: TextStyle(fontSize: 11.5, color: Colors.black87)),
            const Text('• सड़े या दागदार दानों को अलग करने के बाद नई फोटो अपलोड करें।',
                style: TextStyle(fontSize: 11.5, color: Colors.black87)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('समझ गया (Understood)'),
          ),
        ],
      ),
    );
  }

  void _showAutoAiAssayPromptDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: AppTheme.primaryGreen),
            const SizedBox(width: 8),
            Text(
              'Automated AI Crop Assaying',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Grain sample photo captured! AI will now automatically analyze your crop sample for:',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade800, height: 1.4),
            ),
            const SizedBox(height: 10),
            _buildAssayPoint('Moisture % (Optimal ≤ 12.0%)'),
            _buildAssayPoint('Broken Grain % (Grade A ≤ 3.0%)'),
            _buildAssayPoint('Foreign Matter & Seed Purity Index'),
            _buildAssayPoint('AGMARK Quality Grade Certification'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
              ),
              child: Text(
                '🔒 Listing Gate: You can publish your crop only after AI assay verification is complete.',
                style: GoogleFonts.inter(fontSize: 11, color: AppTheme.darkGreen, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _runAiAssaying();
            },
            icon: const Icon(Icons.flash_on, size: 16),
            label: const Text('Start Auto AI Assaying'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssayPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppTheme.primaryGreen, size: 15),
          const SizedBox(width: 6),
          Text(text, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade800)),
        ],
      ),
    );
  }

  Future<void> _runAiAssaying() async {
    if (_cropImageFile == null) return;

    setState(() => _isAnalyzingWithAi = true);

    try {
      final bytes = await _cropImageFile!.readAsBytes();
      final inspection = await GeminiCropAssayService().inspectAndAssayProduce(
        imageBytes: bytes,
        fileName: _cropImageFile!.name,
      );

      if (!inspection.isValidProduce) {
        throw CropValidationException(
          message: inspection.rejectionReason ?? 'Non-crop image detected.',
          hindiMessage: inspection.hindiRejectionReason ?? 'यह फोटो फसल की नहीं लग रही है।',
          title: 'अमान्य फोटो / Image Rejected',
        );
      }

      // STRICT QUALITY THRESHOLD GATE (< 50% PURITY)
      if (inspection.purityScore < 50.0 || inspection.hasRotOrSpoilage) {
        throw CropValidationException(
          message: 'Crop purity/quality score is ${inspection.purityScore.toStringAsFixed(1)}%, which is below the minimum required 50% threshold.',
          hindiMessage: 'फसल की गुणवत्ता व शुद्धता केवल ${inspection.purityScore.toStringAsFixed(1)}% है (न्यूनतम 50% आवश्यक)। 50% से कम गुणवत्ता वाली फसल AgriChain पर लिस्ट नहीं की जा सकती।',
          title: 'गुणवत्ता 50% से कम / Quality Below 50%',
        );
      }

      final result = inspection.toAssayResult();

      if (mounted) {
        final bool isSpoiled = inspection.hasRotOrSpoilage;

        setState(() {
          _aiAssayResult = result;
          _isAnalyzingWithAi = false;
          _selectedCropType = inspection.detectedCropType;
          _selectedCategory = inspection.detectedCategory;
          _nameController.text = inspection.cropName;
          _descriptionController.text = inspection.description;
          _selectedQualityGrade = inspection.qualityGrade;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isSpoiled
                ? '⚠️ Gemini Vision: सड़े/खराब लक्षण पाए गए (${result.agmarkGrade})'
                : '✅ Gemini Vision: ${inspection.cropName} (${result.agmarkGrade}) सत्यापित!'),
            backgroundColor: isSpoiled ? Colors.red.shade800 : AppTheme.primaryGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint('AI Assaying error: $e');
      if (mounted) {
        setState(() {
          _isAnalyzingWithAi = false;
          _cropImageFile = null;
          _selectedImagePath = null;
          _aiAssayResult = null;
        });

        if (e is CropValidationException) {
          _showInvalidCropImageDialog(
            CropValidationResult.invalid(
              reason: e.message,
              hindiReason: e.hindiMessage,
              detectedSubject: 'Non-crop / Document Detected',
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('AI Assaying error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _pickSignatureImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1024,
      );

      if (image != null) {
        setState(() {
          _signatureImage = image;
        });
      }
    } catch (e) {
      debugPrint('Error picking signature image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _selectHarvestDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _harvestDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryGreen,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _harvestDate) {
      setState(() {
        _harvestDate = picked;
      });
    }
  }

  void _onCropTypeChanged(CropType? cropType) {
    setState(() {
      _selectedCropType = cropType;
      if (cropType != null) {
        _selectedCategory = CropDataHelper.getCategoryForCropType(cropType);
        _currentPricing = CropDataHelper.getPricingForCropType(cropType);
        if (_nameController.text.isEmpty) {
          _nameController.text = CropDataHelper.getCropDisplayName(cropType);
        }
      } else {
        _selectedCategory = null;
        _currentPricing = null;
      }
    });
  }

  void _toggleCertification(CertificationType certification) {
    setState(() {
      if (_selectedCertifications.contains(certification)) {
        _selectedCertifications.remove(certification);
      } else {
        _selectedCertifications.add(certification);
      }
    });
  }

  Widget _buildPricingInfo() {
    final cropText = _nameController.text.trim();
    final bm = CropBenchmark.findByName(cropText.isNotEmpty ? cropText : (_selectedCropType?.name ?? 'wheat'));

    if (bm == null && _currentPricing == null) return const SizedBox.shrink();

    final msp = bm?.mspPerQtl ?? _currentPricing?.msp.toDouble() ?? 2275.0;
    final mandiMin = bm?.mandiMinPrice ?? (msp * 1.05);
    final mandiMax = bm?.mandiMaxPrice ?? (msp * 1.25);
    final mandiAvg = bm?.mandiAvgPrice ?? (msp * 1.15);
    final hindi = bm?.hindiName ?? 'फसल';

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.price_check, color: AppTheme.darkGreen, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'सरकारी समर्थन मूल्य (MSP) व मंडी भाव • $hindi',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkGreen,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: const Text(
                  'MSP 2024-25',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Govt MSP Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Govt. MSP (न्यूनतम भाव):', style: TextStyle(fontSize: 11, color: Color(0xFF065F46))),
                      const SizedBox(height: 2),
                      Text(
                        '₹${msp.toInt()} / क्विंटल',
                        style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF047857)),
                      ),
                      Text('≈ ₹${(msp / 100).toStringAsFixed(1)} / किलो', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Mandi Average
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('मंडी औसत (Market Avg):', style: TextStyle(fontSize: 11, color: Color(0xFF9A3412))),
                      const SizedBox(height: 2),
                      Text(
                        '₹${mandiAvg.toInt()} / क्विंटल',
                        style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFFC2410C)),
                      ),
                      Text('रेंज: ₹${mandiMin.toInt()} - ₹${mandiMax.toInt()}', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline, size: 14, color: Color(0xFFB45309)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '💡 किसान सलाह: अपनी फसल को सरकारी MSP से कम दाम पर कभी लिस्ट न करें।',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF92400E)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadCrop() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedImagePath == null || _cropImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ फसल का फोटो लगाना अनिवार्य है (Crop photo is compulsory). बिना फोटो के फसल लिस्ट नहीं की जा सकती।'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    if (_aiAssayResult == null) {
      _showAutoAiAssayPromptDialog();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ AI Assaying Required: Please run automated AI quality assay first.'),
          backgroundColor: Colors.deepOrange,
        ),
      );
      return;
    }

    // STRICT QUALITY GATE: Cannot list produce with quality / purity < 50%
    if (_aiAssayResult!.purityScore < 50.0) {
      _showLowQualityRejectionDialog(
        purityScore: _aiAssayResult!.purityScore,
        cropName: _nameController.text.isNotEmpty ? _nameController.text : 'Crop',
        reason: _aiAssayResult!.assessmentSummary,
      );
      return;
    }

    final isSpoiled = _aiAssayResult != null &&
        (_aiAssayResult!.agmarkGrade.contains('REJECTED') ||
         _aiAssayResult!.agmarkGrade.contains('SUB-STANDARD') ||
         !_aiAssayResult!.isMspCompliant);

    if (isSpoiled && _selectedQualityGrade == QualityGrade.premium) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ गुणवत्ता त्रुटि: सड़े/खराब माल को प्रीमियम ग्रेड में लिस्ट नहीं किया जा सकता। कृपया ग्रेड को "Sub-standard" चुनें।'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final blockchainService = BlockchainService();

      // Step 1: Upload image to IPFS
      final ipfsHash = await blockchainService.uploadImageToIPFS(
        _selectedImagePath ?? 'ipfs_hash_default',
      );

      // Step 2: Mint NFT for the crop
      final nftTokenId = await blockchainService.mintNFT(
        appState.currentUser?.name ?? 'Ramesh Kumar',
        _nameController.text,
        _descriptionController.text,
        ipfsHash,
      );

      String? cropSignatureUrl;
      if (_signatureImage != null) {
        try {
          final bytes = await _signatureImage!.readAsBytes();
          final base64String = base64Encode(bytes);
          cropSignatureUrl = 'data:image/jpeg;base64,$base64String';
        } catch (e) {
          debugPrint('Error converting crop signature: $e');
        }
      }

      String cropImageUrl = _selectedImagePath ?? '';
      if (_cropImageFile != null) {
        try {
          final bytes = await _cropImageFile!.readAsBytes();
          final base64String = base64Encode(bytes);
          cropImageUrl = 'data:image/jpeg;base64,$base64String';
        } catch (e) {
          debugPrint('Error converting crop image: $e');
        }
      }
      if (cropImageUrl.isEmpty) {
        cropImageUrl = CropImageHelper.getContextualCropImageUrl(_nameController.text);
      }

      // Step 3: Create crop using AppState
      final success = await appState.createCrop(
        name: _nameController.text,
        location: _locationController.text.isEmpty
            ? appState.currentUser?.location ?? 'Karnal Cluster, Haryana'
            : _locationController.text,
        price: double.parse(_priceController.text),
        quantity: _quantityController.text,
        harvestDate: _harvestDate,
        imageUrl: cropImageUrl,
        description: _descriptionController.text,
        cropType: _selectedCropType ?? CropType.wheat,
        category: _selectedCategory ?? CropCategory.grains,
        qualityGrade: _selectedQualityGrade,
        isNFT: true,
        biddingType: BiddingType.fixedPrice,
        signatureUrl: cropSignatureUrl,
      );

      if (success) {
        debugPrint('✅ Crop created successfully');
        final cropId = DateTime.now().millisecondsSinceEpoch.toString();
        await blockchainService.createSellOrder(
          cropId,
          double.parse(_priceController.text),
          _quantityController.text,
          nftTokenId,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🌾 Crop listing published successfully! Live in buyer marketplace.'),
            backgroundColor: Color(0xFF1B5E20),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAssayVerified = _aiAssayResult != null && _cropImageFile != null && _aiAssayResult!.purityScore >= 50.0;

    return Scaffold(
      appBar: const EnhancedAppBar(
        title: 'Add New Crop',
        subtitle: 'List your crop for sale on AgriChain',
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sell Type Selection
              const Text(
                'How would you like to sell?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkGreen,
                ),
              ),
              const SizedBox(height: 16),
              _buildSellTypeCard(
                title: 'Fixed Price',
                subtitle: 'Set a fixed price for your crop',
                icon: Icons.local_offer,
              ),
              const SizedBox(height: 24),

              // Image Upload
              const Text(
                'Crop Image',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkGreen,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _selectImage,
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: _selectedImagePath == null
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo,
                              size: 48,
                              color: AppTheme.grey,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Tap to select crop sample image',
                              style: TextStyle(
                                color: AppTheme.grey,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        )
                      : Stack(
                          children: [
                            Container(
                              width: double.infinity,
                              height: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: AppTheme.primaryGreen.withValues(
                                  alpha: 0.1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: _cropImageFile != null
                                    ? (kIsWeb
                                        ? Image.network(
                                            _cropImageFile!.path,
                                            fit: BoxFit.cover,
                                          )
                                        : Image.file(
                                            File(_cropImageFile!.path),
                                            fit: BoxFit.cover,
                                          ))
                                    : const Icon(
                                        Icons.image,
                                        size: 64,
                                        color: AppTheme.primaryGreen,
                                      ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: isAssayVerified ? AppTheme.primaryGreen : Colors.orange,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isAssayVerified ? Icons.check : Icons.auto_awesome,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              // AI ASSAYING SCANNER / RESULT CARD
              if (_isAnalyzingWithAi) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF81C784)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'AI Assaying analyzing moisture %, broken grains %, foreign matter & AGMARK grade...',
                          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.darkGreen, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_aiAssayResult != null && !_isAnalyzingWithAi) ...[
                const SizedBox(height: 14),
                Builder(builder: (context) {
                  final isRejected = _aiAssayResult!.agmarkGrade.contains('REJECTED') ||
                      _aiAssayResult!.agmarkGrade.contains('SUB-STANDARD') ||
                      !_aiAssayResult!.isMspCompliant;

                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isRejected
                                ? const [Color(0xFF450A0A), Color(0xFF7F1D1D)]
                                : const [Color(0xFF0F381E), Color(0xFF1B5E20)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: (isRejected ? Colors.red : const Color(0xFF1B5E20)).withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isRejected ? Icons.warning_amber_rounded : Icons.auto_awesome,
                                      color: isRejected ? const Color(0xFFFCA5A5) : const Color(0xFF69F0AE),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'AI Crop Assaying Results',
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isRejected ? const Color(0xFFF87171) : const Color(0xFF69F0AE),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _aiAssayResult!.agmarkGrade,
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: isRejected ? Colors.white : const Color(0xFF0F381E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _buildAssayMetricCol(
                                  isRejected ? 'Moisture/Decay' : 'Moisture',
                                  '${_aiAssayResult!.moisturePercentage}%',
                                  isRejected ? 'Critical Rot' : 'Optimal <12%',
                                ),
                                _buildAssayMetricCol(
                                  isRejected ? 'Defect/Rot %' : 'Broken Grain',
                                  '${_aiAssayResult!.brokenGrainPercentage}%',
                                  isRejected ? 'Severe Decay' : 'Grade A <3%',
                                ),
                                _buildAssayMetricCol(
                                  isRejected ? 'Fungal Residue' : 'Foreign Matter',
                                  '${_aiAssayResult!.foreignMatterPercentage}%',
                                  isRejected ? 'Mold Infested' : 'Clean <0.5%',
                                ),
                                _buildAssayMetricCol(
                                  'AI Purity',
                                  '${_aiAssayResult!.purityScore}%',
                                  isRejected ? 'Failed Standard' : 'High Purity',
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _aiAssayResult!.assessmentSummary,
                              style: GoogleFonts.inter(fontSize: 10, color: Colors.white70, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                      if (isRejected) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.cancel, color: Colors.red, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '⚠️ गुणवत्ता चेतावनी (Quality Warning): फोटो में सड़ी/खराब फसल (Fungal Rot & Decay) पाई गई है। ऐसी फसल प्रीमियम में नहीं बिक सकती और इसका ग्रेड "Sub-standard / Rejected" कर दिया गया है।',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.red.shade900,
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                }),
              ],
              const SizedBox(height: 24),

              // Crop Details
              const Text(
                'Crop Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkGreen,
                ),
              ),
              const SizedBox(height: 16),

              // Crop Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Crop Name',
                  hintText: 'e.g., Organic Wheat',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryGreen,
                      width: 2,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter crop name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Crop Type Dropdown
              DropdownButtonFormField<CropType>(
                value: _selectedCropType,
                decoration: InputDecoration(
                  labelText: 'Crop Type',
                  hintText: 'Select crop type',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryGreen,
                      width: 2,
                    ),
                  ),
                ),
                items: CropDataHelper.cropCategories.entries
                    .expand(
                      (categoryEntry) => [
                        DropdownMenuItem<CropType>(
                          enabled: false,
                          value: null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              CropDataHelper.getCategoryDisplayName(
                                categoryEntry.key,
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkGreen,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        ...categoryEntry.value.map(
                          (cropType) => DropdownMenuItem<CropType>(
                            value: cropType,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 16),
                              child: Text(
                                CropDataHelper.getCropDisplayName(cropType),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                    .toList(),
                onChanged: _onCropTypeChanged,
                validator: (value) {
                  if (value == null) {
                    return 'Please select a crop type';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Show pricing info if crop type is selected
              _buildPricingInfo(),

              // Quality Grade Dropdown
              DropdownButtonFormField<QualityGrade>(
                value: _selectedQualityGrade,
                decoration: InputDecoration(
                  labelText: 'Quality Grade',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryGreen,
                      width: 2,
                    ),
                  ),
                ),
                items: QualityGrade.values
                    .map(
                      (grade) => DropdownMenuItem<QualityGrade>(
                        value: grade,
                        child: Text(
                          CropDataHelper.getQualityGradeDisplayName(grade),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedQualityGrade = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Certifications
              const Text(
                'Certifications',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkGreen,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CertificationType.values.map((certification) {
                  final isSelected = _selectedCertifications.contains(
                    certification,
                  );
                  return FilterChip(
                    label: Text(
                      CropDataHelper.getCertificationDisplayName(certification),
                    ),
                    selected: isSelected,
                    onSelected: (_) => _toggleCertification(certification),
                    selectedColor: AppTheme.primaryGreen.withValues(alpha: 0.2),
                    checkmarkColor: AppTheme.primaryGreen,
                    backgroundColor: Colors.grey[100],
                    labelStyle: TextStyle(
                      color: isSelected ? AppTheme.primaryGreen : AppTheme.grey,
                      fontWeight: isSelected
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'Describe your crop quality, farming methods, etc.',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryGreen,
                      width: 2,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Quantity (in kg)
              TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(
                  labelText: 'Quantity (in kg)',
                  hintText: 'e.g., 500 kg',
                  helperText: 'Available harvest volume in kilograms',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryGreen,
                      width: 2,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Enter quantity';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Price Field (Price per kg)
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Price per kg (₹)',
                  hintText: 'e.g., 35.00',
                  helperText: 'Selling price per kilogram in Rupees',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryGreen,
                      width: 2,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Enter price';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Enter valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Location
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: 'Location (Optional)',
                  hintText: 'Farm location',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryGreen,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Harvest Date
              GestureDetector(
                onTap: _selectHarvestDate,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: AppTheme.grey),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Harvest Date',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.grey,
                            ),
                          ),
                          Text(
                            '${_harvestDate.day}/${_harvestDate.month}/${_harvestDate.year}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppTheme.darkGreen,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Signature Upload Section
              const Text(
                'Contract Document Signature',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkGreen,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    if (_signatureImage != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: kIsWeb
                            ? Image.network(
                                _signatureImage!.path,
                                height: 100,
                                width: double.infinity,
                                fit: BoxFit.contain,
                              )
                            : Image.file(
                                File(_signatureImage!.path),
                                height: 100,
                                width: double.infinity,
                                fit: BoxFit.contain,
                              ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _pickSignatureImage,
                        icon: const Icon(
                          Icons.edit,
                          color: AppTheme.primaryGreen,
                        ),
                        label: const Text('Change Signature'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryGreen,
                          side: const BorderSide(color: AppTheme.primaryGreen),
                        ),
                      ),
                    ] else ...[
                      const Icon(Icons.draw, size: 48, color: AppTheme.grey),
                      const SizedBox(height: 8),
                      const Text(
                        'Upload your signature for contracts associated with this crop',
                        style: TextStyle(color: AppTheme.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _pickSignatureImage,
                        icon: const Icon(
                          Icons.upload,
                          color: AppTheme.primaryGreen,
                        ),
                        label: const Text('Upload Signature'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryGreen,
                          side: const BorderSide(color: AppTheme.primaryGreen),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _uploadCrop,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAssayVerified ? AppTheme.primaryGreen : Colors.grey.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isUploading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Creating NFT & Processing...'),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(isAssayVerified ? Icons.verified : Icons.lock_outline, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              isAssayVerified
                                  ? 'List Crop for Sale (Verified)'
                                  : (_cropImageFile == null
                                      ? 'Add Crop Photo to List (Compulsory)'
                                      : 'Complete AI Assaying (≥50% Quality) to List'),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // NFT Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.security, color: AppTheme.primaryGreen),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your crop will be automatically converted to an NFT for blockchain verification and ownership proof.',
                        style: TextStyle(
                          color: AppTheme.darkGreen,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssayMetricCol(String title, String val, String sub) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 9, color: Colors.white60)),
          const SizedBox(height: 2),
          Text(val, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(sub, style: GoogleFonts.inter(fontSize: 8, color: const Color(0xFF69F0AE))),
        ],
      ),
    );
  }

  Widget _buildSellTypeCard({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.1),
        border: Border.all(color: AppTheme.primaryGreen, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28, color: AppTheme.primaryGreen),
          const SizedBox(height: 6),
          Flexible(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryGreen,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.primaryGreen,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
