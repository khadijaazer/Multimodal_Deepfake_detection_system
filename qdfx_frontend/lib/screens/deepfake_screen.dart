import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart' as fp;
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../services/pdf_service.dart';
import '../l10n/translations.dart';
import '../layout/responsive_layout.dart';
import '../screens/landing_screen.dart';

const String kHeatmapAuthentic = 'authentic';
const String kHeatmapAudioFake = 'audio_fake';
const String kHeatmapFaceSwap  = 'face_swap';
const String kHeatmapGenAI     = 'gen_ai';
const String kHeatmapMulti     = 'multi_manipulation';

class HeatmapModeInfo {
  final String    label;
  final String    shortLabel;
  final Color     primaryColor;
  final Color     dimColor;
  final IconData  icon;
  final String    regionHint;
  final String    description;

  const HeatmapModeInfo({
    required this.label,
    required this.shortLabel,
    required this.primaryColor,
    required this.dimColor,
    required this.icon,
    required this.regionHint,
    required this.description,
  });
}

const Map<String, HeatmapModeInfo> kHeatmapModes = {
  kHeatmapAuthentic: HeatmapModeInfo(
    label: 'Authentic Video', shortLabel: 'AUTHENTIC',
    primaryColor: Color(0xFF10B981), dimColor: Color(0xFF064E3B),
    icon: Icons.verified_outlined,
    regionHint: 'Eyes · Nose · Cheeks (diffuse)',
    description: 'Soft diffuse emerald glow across stable biometric structures. No anomaly spikes detected.',
  ),
  kHeatmapAudioFake: HeatmapModeInfo(
    label: 'Voice Clone / Audio Fake', shortLabel: 'VOICE CLONE',
    primaryColor: Color(0xFFEF4444), dimColor: Color(0xFF7F1D1D),
    icon: Icons.mic_off_outlined,
    regionHint: 'Mouth · Lips · Lower Jaw',
    description: 'Crimson spikes at mouth and jaw. ERF module detected phoneme/viseme mismatch — cloned audio suspected.',
  ),
  kHeatmapFaceSwap: HeatmapModeInfo(
    label: 'Face-Swap / Manipulation', shortLabel: 'FACE-SWAP',
    primaryColor: Color(0xFFEF4444), dimColor: Color(0xFF7F1D1D),
    icon: Icons.face_retouching_natural,
    regionHint: 'Outer seam · Eye orbits · Nose-bridge · Jaw',
    description: 'High-intensity crimson ring tracing face mask boundaries. Stitching seams confirmed.',
  ),
  kHeatmapGenAI: HeatmapModeInfo(
    label: 'Fully AI Generated', shortLabel: 'GEN-AI',
    primaryColor: Color(0xFFA855F7), dimColor: Color(0xFF4C1D95),
    icon: Icons.auto_awesome_outlined,
    regionHint: 'Full frame · Hair · Background',
    description: 'Decentralized UV-purple cloud covers entire canvas. Global texture anomalies — no real base footage.',
  ),
  kHeatmapMulti: HeatmapModeInfo(
    label: 'Multi-Manipulation', shortLabel: 'MULTI',
    primaryColor: Color(0xFFFF8C00), dimColor: Color(0xFF663300),
    icon: Icons.warning_amber_rounded,
    regionHint: 'Face boundaries + Mouth region (combined)',
    description: 'ORANGE ALERT: Both face-swap AND voice clone detected in same media.',
  ),
};

class DeepfakeScreen extends StatefulWidget {
  const DeepfakeScreen({super.key});

  @override
  State<DeepfakeScreen> createState() => _DeepfakeScreenState();
}

class _DeepfakeScreenState extends State<DeepfakeScreen>
    with TickerProviderStateMixin {
  int     _phase      = 0;
  String  _loadingMsg = 'Waking up forensic server…';
  String? _errorMessage;
  fp.PlatformFile?      _selectedFile;
  Map<String, dynamic>? _resultData;
  bool _contributeAnonymously = true;

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  //static const String _backendBase = 'http://localhost:7860';
  static const String _backendBase = 'https://khadidjaabderrahmane-detectini-backend.hf.space';

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  String t(BuildContext context, String key) {
    final appState = Provider.of<AppState>(context, listen: false);
    return AppTranslations.get(appState.currentLocale.languageCode, key);
  }

  double _dbl(dynamic v, {double fb = 0.0}) {
    if (v == null) return fb;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fb;
    return fb;
  }

  String _normalizeHeatmapMode(String? backendMode) {
    switch (backendMode) {
      case 'face_swap_audio':
      case 'multi_manipulation':
        return kHeatmapMulti;
      case 'audio_fake':
        return kHeatmapAudioFake;
      case 'face_swap':
        return kHeatmapFaceSwap;
      case 'gen_ai':
        return kHeatmapGenAI;
      case 'authentic':
        return kHeatmapAuthentic;
      default:
        return kHeatmapAuthentic;
    }
  }

  String get _mode => _normalizeHeatmapMode(_resultData?['heatmap_mode'] as String?);
  HeatmapModeInfo get _modeInfo => kHeatmapModes[_mode] ?? kHeatmapModes[kHeatmapAuthentic]!;
  bool get _isFake => _resultData?['is_manipulated'] ?? false;
  bool get _isMultiManipulated => _resultData?['is_multi_manipulated'] ?? false;
  List<dynamic> get _detectedModes => _resultData?['detected_modes'] ?? [];
  Map<String, dynamic> get _manipulationScores => _resultData?['manipulation_scores'] ?? {};

  String _getMediaType() {
    if (_selectedFile == null) return 'video';
    final ext = _selectedFile!.extension?.toLowerCase() ?? '';
    if (['jpg', 'jpeg', 'png', 'webp', 'bmp', 'gif', 'heic'].contains(ext)) return 'image';
    if (['mp3', 'wav', 'm4a', 'flac', 'aac', 'ogg', 'opus'].contains(ext)) return 'audio';
    return 'video';
  }

  Future<void> _pickFile() async {
    try {
      final result = await fp.FilePicker.platform.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: ['mp4', 'mov', 'avi', 'mkv', 'webm', 'jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
     
      if (result != null && result.files.first.bytes != null) {
        final file = result.files.first;
        final ext = file.extension?.toLowerCase() ?? '';
        
        if (['mp3', 'wav', 'm4a', 'flac', 'aac', 'ogg', 'opus'].contains(ext)) {
          _showErrorSnackBar("Audio files are not supported. Please select a video or image file.");
          return;
        }
        
        setState(() => _selectedFile = file);
        debugPrint("File selected: ${file.name} (${_getMediaType()})");
      } else {
        _showErrorSnackBar("Failed to load file. Please try another file.");
      }
    } catch (e) {
      debugPrint("File picker error: $e");
      _showErrorSnackBar("File picker error. Please check app permissions.");
    }
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _reset() => setState(() {
        _phase        = 0;
        _selectedFile = null;
        _resultData   = null;
        _errorMessage = null;
        _loadingMsg   = t(context, 'wakingServer');
      });

  Future<void> _submitAnonymousContribution({
    required String filePath,
    required String fileType,
    required bool predictedIsFake,
    required double confidenceScore,
  }) async {
    try {
      await http.post(
        Uri.parse('$_backendBase/api/v1/trial/contribute'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "file_path": filePath,
          "file_type": fileType,
          "predicted_is_fake": predictedIsFake,
          "confidence_score": confidenceScore,
          "consent_granted": true
        }),
      );
    } catch (e) {
      debugPrint("Anonymous dataset logging failed: $e");
    }
  }

  double _calculateUploadCost(int sizeInBytes) {
    double totalGb = sizeInBytes / (1024 * 1024 * 1024);
    double freeAllowanceGb = 0.05;
    if (totalGb <= freeAllowanceGb) return 0.0;

    double billableGb = totalGb - freeAllowanceGb;
    double totalCost = 0.0;
    double remainingGb = billableGb;

    double tier1Limit = 1.0 - freeAllowanceGb;
    if (remainingGb > 0) {
      double b = remainingGb > tier1Limit ? tier1Limit : remainingGb;
      totalCost += b * 800.0;
      remainingGb -= b;
    }
    if (remainingGb > 0) {
      double b = remainingGb > 9.0 ? 9.0 : remainingGb;
      totalCost += b * 600.0;
      remainingGb -= b;
    }
    if (remainingGb > 0) {
      double b = remainingGb > 40.0 ? 40.0 : remainingGb;
      totalCost += b * 400.0;
      remainingGb -= b;
    }
    if (remainingGb > 0) {
      totalCost += remainingGb * 250.0;
    }
    return totalCost;
  }

  Future<bool> _showVolumeCostConfirmationDialog(double totalMb, double cost) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151E32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.payment_outlined, color: Colors.purpleAccent, size: 20),
            SizedBox(width: 8),
            Text(
              "Media Volume Confirmation",
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Your file size is ${totalMb.toStringAsFixed(1)} MB, which exceeds your 50 MB free allowance request threshold.",
              style: const TextStyle(color: Colors.grey, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purpleAccent.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Processing Fee:", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text(
                    "${cost.toStringAsFixed(0)} DZD",
                    style: const TextStyle(color: Colors.purpleAccent, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "*Proceeding will initiate secure upload and processing. Declining returns you to the upload tray without any cost.",
              style: TextStyle(color: Colors.grey, fontSize: 10, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Decline & Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Accept & Pay", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showUpgradePaywallDialog(AppState appState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151E32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.lock_outline_rounded, color: Colors.amber, size: 20),
          const SizedBox(width: 8),
          Text(t(context, 'paidFeatureRequired'),
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        content: Text(t(context, 'deepfakePaywallMessage'),
            style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t(context, 'cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
            onPressed: () { Navigator.pop(ctx); appState.setIndex(1); },
            icon: const Icon(Icons.star_rounded, color: Colors.white, size: 14),
            label: Text(t(context, 'upgradePlan'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showMonthlyLimitDialog(AppState appState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151E32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.lock_outline_rounded, color: Colors.amber, size: 20),
          const SizedBox(width: 8),
          const Text(
            "Monthly Limit Reached",
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ]),
        content: const Text(
          "You've used all free scans this month. Upgrade for unlimited forensic video analysis.",
          style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
            onPressed: () { Navigator.pop(ctx); appState.setIndex(1); },
            icon: const Icon(Icons.star_rounded, color: Colors.white, size: 14),
            label: const Text("Upgrade Plan",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _startAnalysis(AppState appState) async {
    if (_selectedFile == null) return;

    final String mediaType = _getMediaType();
    if (mediaType == 'audio') {
      _setError("Audio files (.wav, .mp3, etc.) are not supported.\n\nPlease select a video file (.mp4, .mov, .avi) or an image file (.jpg, .png).");
      _reset();
      return;
    }

    // Vérifier l'abonnement FIRST - Popup upgrade
    if (appState.subscriptionPlan.toLowerCase() == 'free') {
      _showUpgradePaywallDialog(appState);
      return;
    }
    
    // Vérifier le quota - Popup monthly limit
    if (!appState.canUpload) {
      _showMonthlyLimitDialog(appState);
      return;
    }

    final int fileSizeInBytes = _selectedFile!.size;
    final double totalMb = fileSizeInBytes / (1024 * 1024);
    if (totalMb > 50.0) {
      final double cost = _calculateUploadCost(fileSizeInBytes);
      final bool consentProceed = await _showVolumeCostConfirmationDialog(totalMb, cost);
      if (!consentProceed) return;
    }

    setState(() { _phase = 1; _loadingMsg = t(context, 'wakingServer'); _errorMessage = null; });

    try {
      await http.get(Uri.parse('$_backendBase/')).timeout(const Duration(seconds: 15));
    } catch (_) {}

    setState(() => _loadingMsg = t(context, 'uploadingVideo'));

    try {
      final uri = Uri.parse('$_backendBase/api/ai/scan-video');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(http.MultipartFile.fromBytes('file', _selectedFile!.bytes!, filename: _selectedFile!.name));

      setState(() => _loadingMsg = t(context, 'runningEngines'));
      final streamed = await request.send().timeout(const Duration(seconds: 600));
      setState(() => _loadingMsg = t(context, 'processingResults'));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final bool isFake = data['is_manipulated'] ?? false;
        final double conf = _dbl(data['confidence']);
        final double fakeProb = _dbl(data['fake_probability']);

        data['score_unified']   ??= conf;
        data['score_synthetic'] ??= isFake ? fakeProb : 50.0;
        data['media_type'] = mediaType;
        
        if (!data.containsKey('heatmap_mode') || data['heatmap_mode'] == null) {
          data['heatmap_mode'] = isFake ? kHeatmapFaceSwap : kHeatmapAuthentic;
          print("⚠️ Backend missing heatmap_mode, using fallback: ${data['heatmap_mode']}");
        } else {
          print("✅ Backend heatmap_mode: ${data['heatmap_mode']}");
        }
        
        final bool isMulti = data['is_multi_manipulated'] ?? false;
        final Map<String, dynamic> manipScores = data['manipulation_scores'] ?? {};
        
        if (isMulti && isFake) {
          List<String> multiIndicators = [
            '⚠️ MULTI-MANIPULATION DETECTED with ${conf.toStringAsFixed(1)}% confidence',
            '🎭🔊 Face-Swap AND Voice Clone detected in same media',
          ];
          
          if (manipScores.containsKey('face_swap')) {
            double fsScore = (manipScores['face_swap'] as num).toDouble();
            multiIndicators.add('   • Face-Swap confidence: ${(fsScore * 100).toStringAsFixed(0)}%');
          }
          if (manipScores.containsKey('voice_clone')) {
            double vcScore = (manipScores['voice_clone'] as num).toDouble();
            multiIndicators.add('   • Voice Clone confidence: ${(vcScore * 100).toStringAsFixed(0)}%');
          }
          if (manipScores.containsKey('gen_ai')) {
            double gaScore = (manipScores['gen_ai'] as num).toDouble();
            multiIndicators.add('   • Gen-AI confidence: ${(gaScore * 100).toStringAsFixed(0)}%');
          }
          
          multiIndicators.addAll([
            '🔬 Multiple forensic signatures confirmed',
            '🚨 CRITICAL: Media contains multiple manipulation types',
            '🟠 Heatmap Mode: Orange — Combined manipulation mapping',
          ]);
          data['indicators'] = multiIndicators;
        } else if (isFake) {
          data['indicators'] = [
            '⚠️ ${t(context, 'deepfakeDetectedText')} ${conf.toStringAsFixed(1)}% ${t(context, 'confidence').toLowerCase()}',
            '🎭 ${t(context, 'multimodalInconsistency')}',
            '🔬 ${t(context, 'unifiedEngineFlagged')}',
            '🚨 ${t(context, 'criticalMediaGenerated')}',
          ];
        } else {
          data['indicators'] = [
            '✅ ${t(context, 'mediaAuthentic')} ${conf.toStringAsFixed(1)}% ${t(context, 'confidence').toLowerCase()}',
            '🔍 ${t(context, 'noManipulationDetected')}',
            mediaType == 'audio' ? '📊 ${t(context, 'audioSpectrumVerified')}' : '📊 ${t(context, 'avSyncVerified')}',
          ];
        }

        try {
          final user = Supabase.instance.client.auth.currentUser;
          if (user != null) {
            await Supabase.instance.client.from('scans').insert({
              'user_id': user.id,
              'scan_type': mediaType,
              'file_name': _selectedFile!.name,
              'is_threat': isFake,
              'confidence_score': conf,
              'risk_score': isFake ? fakeProb : (100.0 - conf).clamp(0.0, 100.0),
            });
          }
        } catch (e) { debugPrint('Supabase insert failed: $e'); }

        if (_contributeAnonymously) {
          await _submitAnonymousContribution(
            filePath: data['file_path'] ?? _selectedFile!.name,
            fileType: mediaType,
            predictedIsFake: isFake,
            confidenceScore: conf,
          );
        }

        appState.recordScanUsage();
        setState(() { _resultData = data; _phase = 2; });
      } else {
        _setError('${t(context, 'serverReturned')} ${response.statusCode}.\n\n'
            '${response.body.length > 300 ? '${response.body.substring(0, 300)}…' : response.body}');
      }
    } on TimeoutException catch (e) {
      _setError("Analysis is taking too long. For large videos, please try:\n\n"
          "• Using a smaller file (under 50MB)\n"
          "• Converting to a more compressed format\n"
          "• Trying during off-peak hours\n\n"
          "Error: ${e.message}");
    } on Exception catch (e) {
      _setError(e.toString());
    }
  }

  void _setError(String msg) {
    debugPrint('Analysis failed: $msg');
    setState(() { _phase = 3; _errorMessage = msg; });
  }

  BoxDecoration _cardDeco(Color bg, Color borderColor) => BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
      );

  Widget _buildMultiManipulationBadge() {
    if (!_isMultiManipulated || !_isFake) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade900, Colors.orange.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orangeAccent, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "⚠️ MULTI-MANIPULATION DETECTED",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Face-Swap + Voice Clone in same media",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (_manipulationScores.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "${((_manipulationScores['face_swap'] ?? 0) * 100).toStringAsFixed(0)}% / ${((_manipulationScores['voice_clone'] ?? 0) * 100).toStringAsFixed(0)}%",
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark   = appState.isDarkMode;
    final lang     = appState.currentLocale.languageCode;
    String tr(String key) => AppTranslations.get(lang, key);

    final Color bg     = isDark ? const Color(0xFF060C18) : const Color(0xFFF0F4FA);
    final Color card   = isDark ? const Color(0xFF0D1526) : Colors.white;
    final Color text   = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B);
    final Color border = isDark ? const Color(0xFF1E2D45) : const Color(0xFFE2E8F0);
    final Color muted  = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

    final circuitColor = (isDark ? Colors.white : Colors.black).withOpacity(0.03);

    // SUPPRESSION de la carte de paywall - toujours afficher l'upload area
    final Widget desktopTabletBody = Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPageHeader(isDark, text, muted, appState, tr),
            const SizedBox(height: 28),
            if (_phase == 0)
              _buildUploadArea(isDark, card, text, border, appState, tr)
            else if (_phase == 1)
              _buildLoadingState(isDark, card, text, tr)
            else if (_phase == 3)
              _buildErrorState(card, text, border, appState, tr)
            else
              _buildResultDashboard(isDark, card, text, border, muted, appState, tr),
          ],
        ),
      ),
    );

    final Widget mobileBody = Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPageHeaderMobile(isDark, text, muted, appState, tr),
            const SizedBox(height: 20),
            if (_phase == 0)
              _buildUploadAreaMobile(isDark, card, text, border, appState, tr)
            else if (_phase == 1)
              _buildLoadingStateMobile(isDark, card, text, tr)
            else if (_phase == 3)
              _buildErrorStateMobile(card, text, border, appState, tr)
            else
              _buildResultDashboardMobile(isDark, card, text, border, muted, appState, tr),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: CircuitBoardPainter(color: circuitColor),
            ),
          ),
          ResponsiveLayout(
            useScaffold: false,
            mobileBody:  mobileBody,
            desktopBody: desktopTabletBody,
            tabletBody:  desktopTabletBody,
          ),
        ],
      ),
    );
  }

  Widget _buildPageHeader(bool isDark, Color text, Color muted, AppState appState, String Function(String) tr) {
    final mediaType = _selectedFile != null ? _getMediaType().toUpperCase() : '';
   
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: _phase == 1 ? Colors.amber : (_phase == 2 && _isFake) ? (_isMultiManipulated ? Colors.orange : Colors.redAccent) : Colors.greenAccent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _phase == 1 ? tr('scanning') : _phase == 2 ? tr('scanComplete') : tr('forensicSystem'),
              style: TextStyle(color: muted, fontSize: 11, fontFamily: 'monospace', letterSpacing: 1.5, fontWeight: FontWeight.bold),
            ),
          ]),
          const SizedBox(height: 6),
          Text(tr('deepfakeForensics'),
              style: TextStyle(color: text, fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            _resultData != null
                ? '${tr('activeModel')}: ${_resultData!["model_used"] ?? "best_model_unified.pth"} | ${tr('mediaType')}: ${_resultData!['media_type'] ?? mediaType}'
                : tr('dualEngineDescription'),
            style: TextStyle(color: muted, fontSize: 12, fontFamily: 'monospace'),
          ),
        ]),
        Row(children: [
          _buildUsageBadge(appState, tr),
          const SizedBox(width: 12),
          if (_phase == 2 || _phase == 3)
            OutlinedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh_rounded, size: 15),
              label: Text(tr('newScan'), style: const TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                  foregroundColor: text,
                  side: BorderSide(color: text.withOpacity(0.2)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
            ),
        ]),
      ],
    );
  }

  Widget _buildUsageBadge(AppState appState, String Function(String) tr) {
    final bool   ok    = appState.canUpload;
    final String label = appState.subscriptionPlan == 'free'
        ? '${appState.scansUsed}/${appState.maxScans} ${tr('scans').toLowerCase()}'
        : tr('unlimited');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: ok ? Colors.green.withOpacity(0.10) : Colors.red.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ok ? Colors.green.withOpacity(0.30) : Colors.red.withOpacity(0.30)),
      ),
      child: Row(children: [
        Icon(ok ? Icons.shield_outlined : Icons.lock_outline,
            size: 12, color: ok ? Colors.greenAccent : Colors.redAccent),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(color: ok ? Colors.greenAccent : Colors.redAccent,
                fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
      ]),
    );
  }

  // La fonction _buildPaywall est conservée mais plus utilisée dans le build
  Widget _buildPaywall(Color card, Color text, AppState appState, String Function(String) tr) =>
      Container(
        height: 480,
        decoration: _cardDeco(card, Colors.red.withOpacity(0.25)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), shape: BoxShape.circle),
            child: const Icon(Icons.lock_outline, size: 54, color: Colors.redAccent),
          ),
          const SizedBox(height: 22),
          Text(tr('monthlyLimitReached'),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: text)),
          const SizedBox(height: 10),
          Text(tr('monthlyLimitMessage'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 15, height: 1.6)),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            icon: const Icon(Icons.star_rounded, color: Colors.white, size: 16),
            label: Text(tr('viewPlans')),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16)),
            onPressed: () => appState.setIndex(1),
          ),
        ]),
      );

  Widget _buildUploadArea(bool isDark, Color card, Color text, Color border, AppState appState, String Function(String) tr) =>
      Container(
        decoration: _cardDeco(card, border),
        padding: const EdgeInsets.all(32),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _statusPill('EfficientNet-B2', Colors.cyanAccent),
            const SizedBox(width: 8),
            _statusPill('CLIP ViT', Colors.purpleAccent),
            const SizedBox(width: 8),
            _statusPill('WavLM + Wav2Vec2', Colors.greenAccent),
          ]),
          const SizedBox(height: 32),
          DottedBorder(
            color: AppTheme.primaryBlue.withOpacity(0.45),
            strokeWidth: 1.5,
            dashPattern: const [8, 5],
            borderType: BorderType.RRect,
            radius: const Radius.circular(16),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 660),
              padding: const EdgeInsets.symmetric(vertical: 52, horizontal: 24),
              decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(14)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, child) => Opacity(opacity: _phase == 0 ? _pulseAnim.value : 1.0, child: child),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: AppTheme.primaryBlue.withOpacity(0.10), shape: BoxShape.circle),
                    child: const Icon(Icons.video_file_outlined, size: 42, color: AppTheme.primaryBlue),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _selectedFile != null ? _selectedFile!.name : tr('dragDrop'),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: text),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(tr('formats'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Checkbox(
                      value: _contributeAnonymously,
                      onChanged: (val) => setState(() => _contributeAnonymously = val ?? true),
                      activeColor: const Color(0xFF3B82F6),
                    ),
                    Flexible(
                      child: Text(
                        "Contribute anonymously to improve AI",
                        style: TextStyle(color: text.withOpacity(0.8), fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  OutlinedButton(
                    onPressed: _pickFile,
                    style: OutlinedButton.styleFrom(
                        foregroundColor: text,
                        side: const BorderSide(color: AppTheme.primaryBlue, width: 1),
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14)),
                    child: Text(tr('browseFiles'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  if (_selectedFile != null) ...[
                    const SizedBox(width: 14),
                    ElevatedButton.icon(
                      onPressed: () => _startAnalysis(appState),
                      icon: const Icon(Icons.play_circle_outline, size: 18, color: Colors.white),
                      label: Text(tr('analyzeVideo'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14)),
                    ),
                  ],
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 28),
          _buildModeLegendGrid(text, tr),
        ]),
      );

  Widget _statusPill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.30)),
        ),
        child: Row(children: [
          Container(width: 5, height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
        ]),
      );

  Widget _buildModeLegendGrid(Color text, String Function(String) tr) {
    return Column(children: [
      Text(tr('detectionModes'),
          style: TextStyle(color: text.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
      const SizedBox(height: 12),
      Row(
        children: kHeatmapModes.entries.map((e) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: e.value.primaryColor.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: e.value.primaryColor.withOpacity(0.20)),
            ),
            child: Column(children: [
              Icon(e.value.icon, color: e.value.primaryColor, size: 20),
              const SizedBox(height: 6),
              Text(e.value.shortLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: e.value.primaryColor, fontSize: 8,
                      fontFamily: 'monospace', fontWeight: FontWeight.bold)),
            ]),
          ),
        )).toList(),
      ),
    ]);
  }

  Widget _buildLoadingState(bool isDark, Color card, Color text, String Function(String) tr) =>
      Container(
        height: 480,
        decoration: _cardDeco(card, AppTheme.primaryBlue.withOpacity(0.15)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 72, height: 72,
              child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: const AlwaysStoppedAnimation(AppTheme.primaryBlue),
                  backgroundColor: AppTheme.primaryBlue.withOpacity(0.15)),
            ),
            Icon(Icons.biotech_outlined, size: 28, color: AppTheme.primaryBlue.withOpacity(0.8)),
          ]),
          const SizedBox(height: 28),
          Text(_loadingMsg,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: text),
              textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(tr('loadingMessage'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, height: 1.7, fontSize: 13)),
          const SizedBox(height: 32),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _loadingStep(tr('upload'), true, tr),
            _loadingConnector(),
            _loadingStep(tr('encode'), _loadingMsg.contains(tr('dual')), tr),
            _loadingConnector(),
            _loadingStep(tr('analyze'), _loadingMsg.contains(tr('process')), tr),
            _loadingConnector(),
            _loadingStep(tr('report'), false, tr),
          ]),
        ]),
      );

  Widget _loadingStep(String label, bool active, String Function(String) tr) =>
      Column(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? AppTheme.primaryBlue.withOpacity(0.20) : Colors.white.withOpacity(0.05),
            border: Border.all(
                color: active ? AppTheme.primaryBlue : Colors.white.withOpacity(0.10), width: 1.5),
          ),
          child: active ? const Icon(Icons.check, size: 14, color: AppTheme.primaryBlue) : null,
        ),
        const SizedBox(height: 5),
        Text(label, style: TextStyle(color: active ? AppTheme.primaryBlue : Colors.grey, fontSize: 9, fontFamily: 'monospace')),
      ]);

  Widget _loadingConnector() =>
      Container(width: 40, height: 1.5, margin: const EdgeInsets.only(bottom: 20), color: Colors.white.withOpacity(0.08));

  Widget _buildErrorState(Color card, Color text, Color border, AppState appState, String Function(String) tr) =>
      Container(
        padding: const EdgeInsets.all(32),
        decoration: _cardDeco(card, Colors.red.withOpacity(0.25)),
        child: Column(children: [
          const Icon(Icons.error_outline_rounded, size: 52, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text(tr('analysisFailed'),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: text)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(0.20))),
            child: Text(_errorMessage ?? tr('unknownError'),
                style: const TextStyle(color: Colors.redAccent, fontFamily: 'monospace', fontSize: 11, height: 1.6)),
          ),
          const SizedBox(height: 20),
          Text(tr('troubleshooting'), style: const TextStyle(color: Colors.grey, height: 1.8, fontSize: 13)),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            OutlinedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.arrow_back_rounded, size: 15),
              label: Text(tr('goBack')),
              style: OutlinedButton.styleFrom(foregroundColor: text),
            ),
            const SizedBox(width: 14),
            ElevatedButton.icon(
              onPressed: () {
                setState(() { _phase = 0; _errorMessage = null; });
                if (_selectedFile != null) _startAnalysis(Provider.of<AppState>(context, listen: false));
              },
              icon: const Icon(Icons.refresh_rounded, size: 15),
              label: Text(tr('retryAnalysis')),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue, foregroundColor: Colors.white),
            ),
          ]),
        ]),
      );

  Widget _buildResultDashboard(bool isDark, Color card, Color text,
      Color border, Color muted, AppState appState, String Function(String) tr) {
    final mediaType = _resultData?['media_type'] ?? _getMediaType();
   
    return LayoutBuilder(builder: (ctx, constraints) {
      final wide = constraints.maxWidth > 1080;
      final left  = _buildLeftPanel(isDark, card, text, border, muted, wide, tr, mediaType);
      final right = _buildRightPanel(isDark, card, text, border, muted, appState, tr, mediaType);
      if (wide) {
        return Column(children: [
          _buildMultiManipulationBadge(),
          _buildVerdictBanner(tr, mediaType),
          const SizedBox(height: 20),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 6, child: left),
            const SizedBox(width: 20),
            Expanded(flex: 4, child: right),
          ]),
        ]);
      }
      return Column(children: [
        _buildMultiManipulationBadge(),
        _buildVerdictBanner(tr, mediaType),
        const SizedBox(height: 20),
        left,
        const SizedBox(height: 20),
        right,
      ]);
    });
  }

  Widget _buildVerdictBanner(String Function(String) tr, String mediaType) {
    final info  = _modeInfo;
    final Color accent = _isFake 
        ? (_isMultiManipulated ? const Color(0xFFFF8C00) : info.primaryColor)
        : const Color(0xFF10B981);
    final double conf  = _dbl(_resultData?['confidence']);
    
    String verb;
    if (_isFake && _isMultiManipulated) {
      verb = '⚠ MULTI-MANIPULATION — FACE-SWAP + VOICE CLONE';
    } else if (_isFake) {
      verb = '⚠ ${tr('deepfakeDetected')} — ${info.label.toUpperCase()}';
    } else {
      verb = '✓ ${tr('mediaAuthenticated')}';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.35), width: 1.5),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: accent.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(_isFake ? Icons.warning_amber_rounded : Icons.verified_rounded, color: accent, size: 26),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(verb, style: TextStyle(color: accent, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            const SizedBox(height: 3),
            Text('${info.description} | ${tr('mediaType')}: ${mediaType.toUpperCase()}',
                style: const TextStyle(color: Colors.grey, fontSize: 12, height: 1.4)),
          ]),
        ),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${conf.toStringAsFixed(1)}%',
              style: TextStyle(color: accent, fontSize: 26, fontWeight: FontWeight.bold)),
          Text(tr('confidence'),
              style: TextStyle(color: accent.withOpacity(0.6), fontSize: 10, fontFamily: 'monospace')),
        ]),
      ]),
    );
  }

  Widget _buildLeftPanel(bool isDark, Color card, Color text,
      Color border, Color muted, bool isWide, String Function(String) tr, String mediaType) {
    return Column(children: [
      if (mediaType != 'audio')
        _buildHeatmapCard(isDark, card, border, text, tr),
      if (mediaType != 'audio') const SizedBox(height: 20),
      _buildModeBadgeCard(card, border, text, muted, tr),
    ]);
  }

  Widget _buildHeatmapCard(bool isDark, Color card, Color border, Color text, String Function(String) tr) {
    final info     = _modeInfo;
    final String? b64 = _resultData?['heatmap_image'] as String?;
    ImageProvider? img;
    if (b64 != null && b64.contains(',')) {
      try { img = MemoryImage(base64Decode(b64.split(',')[1])); } catch (_) {}
    }

    return Container(
      decoration: BoxDecoration(
        color: card, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: info.primaryColor.withOpacity(0.30), width: 1.5),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.biotech_outlined, color: info.primaryColor, size: 18),
          const SizedBox(width: 8),
          Text(tr('neuralAttentionMap'),
              style: TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.bold)),
          const Spacer(),
          _modePill(info),
        ]),
        const SizedBox(height: 4),
        Text('Grad-CAM ${tr('spatialActivation')}  ·  ${info.regionHint}',
            style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 16),
        Container(
          height: 400,
          decoration: BoxDecoration(
            color: Colors.black, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: info.primaryColor.withOpacity(0.15)),
          ),
          child: Stack(children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: img != null
                    ? GestureDetector(onTap: () => _openFullscreen(img!), child: Image(image: img, fit: BoxFit.contain))
                    : Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.image_not_supported_outlined, size: 40, color: Colors.grey[700]),
                        const SizedBox(height: 8),
                        Text(tr('heatmapUnavailable'), style: const TextStyle(color: Colors.grey)),
                      ])),
              ),
            ),
            Positioned(top: 12, left: 12, child: _scanBadge(tr('forensicScan'), info.primaryColor)),
            Positioned(top: 12, right: 12, child: _scanBadge(info.shortLabel, info.primaryColor)),
            if (_isMultiManipulated)
              Positioned(
                bottom: 12, left: 12,
                child: _scanBadge("MULTI", const Color(0xFFFF8C00)),
              ),
            if (img != null)
              Positioned(
                bottom: 12, left: 0, right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.zoom_in, size: 12, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(tr('tapToZoom'), style: const TextStyle(color: Colors.white70, fontSize: 10)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _modePill(HeatmapModeInfo info) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: info.primaryColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: info.primaryColor.withOpacity(0.35)),
        ),
        child: Row(children: [
          Icon(info.icon, size: 12, color: info.primaryColor),
          const SizedBox(width: 5),
          Text(info.shortLabel,
              style: TextStyle(color: info.primaryColor, fontSize: 9,
                  fontFamily: 'monospace', fontWeight: FontWeight.bold)),
        ]),
      );

  Widget _scanBadge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: Colors.black54, borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withOpacity(0.35))),
        child: Text(label,
            style: TextStyle(color: color, fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
      );

  void _openFullscreen(ImageProvider img) {
    showDialog(
      context: context,
      builder: (_) => Dialog.fullscreen(
        backgroundColor: const Color(0xFF060C18),
        child: Stack(children: [
          InteractiveViewer(maxScale: 6.0, child: Center(child: Image(image: img))),
          Positioned(
            top: 40, right: 20,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildModeBadgeCard(Color card, Color border, Color text, Color muted, String Function(String) tr) {
    final info = _modeInfo;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDeco(card, info.primaryColor.withOpacity(0.20)),
      child: Column(children: [
        Row(
          children: kHeatmapModes.entries.map((e) {
            final bool active = e.key == _mode;
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: active ? e.value.primaryColor.withOpacity(0.18) : Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: active ? e.value.primaryColor.withOpacity(0.55) : Colors.white.withOpacity(0.08),
                    width: active ? 1.5 : 1,
                  ),
                ),
                child: Column(children: [
                  Icon(e.value.icon, size: 16, color: active ? e.value.primaryColor : Colors.grey.shade600),
                  const SizedBox(height: 4),
                  Text(e.value.shortLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: active ? e.value.primaryColor : Colors.grey.shade600,
                        fontSize: 8, fontFamily: 'monospace',
                        fontWeight: active ? FontWeight.bold : FontWeight.normal,
                      )),
                ]),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Icon(Icons.place_outlined, size: 12, color: info.primaryColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text('${tr('activationFocus')}: ${info.regionHint}',
                style: TextStyle(color: info.primaryColor, fontSize: 10,
                    fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          ),
        ]),
      ]),
    );
  }

  Widget _buildRightPanel(bool isDark, Color card, Color text,
      Color border, Color muted, AppState appState, String Function(String) tr, String mediaType) {
    return Column(children: [
      _buildKpiRow(text, border, tr, mediaType),
      const SizedBox(height: 20),
      _buildScoreCard(card, border, text, tr, mediaType),
      const SizedBox(height: 20),
      _buildIndicatorsCard(card, border, text, isDark, tr),
      const SizedBox(height: 20),
      _buildActionsCard(card, text, isDark, appState, tr, mediaType),
    ]);
  }

  Widget _buildKpiRow(Color text, Color border, String Function(String) tr, String mediaType) {
    final double conf     = _dbl(_resultData?['confidence']);
    final double fakeProb = _dbl(_resultData?['fake_probability']);
    final double delay    = _dbl(_resultData?['delay_ms']);
   
    if (mediaType == 'audio') {
      return Row(children: [
        _kpi(tr('confidence'), '${conf.toStringAsFixed(1)}%',
            _isFake ? _modeInfo.primaryColor : Colors.greenAccent, text, border),
        const SizedBox(width: 12),
        _kpi(tr('fakeProb'), '${fakeProb.toStringAsFixed(1)}%', Colors.redAccent, text, border),
        const SizedBox(width: 12),
        _kpi(tr('audioQuality'), '${(100 - (delay / 10).clamp(0, 100)).toStringAsFixed(0)}%',
            delay < 30 ? Colors.greenAccent : delay < 70 ? Colors.amber : Colors.redAccent, text, border),
      ]);
    }
   
    return Row(children: [
      _kpi(tr('confidence'), '${conf.toStringAsFixed(1)}%',
          _isFake ? (_isMultiManipulated ? const Color(0xFFFF8C00) : _modeInfo.primaryColor) : Colors.greenAccent, text, border),
      const SizedBox(width: 12),
      _kpi(tr('fakeProb'), '${fakeProb.toStringAsFixed(1)}%', Colors.redAccent, text, border),
      const SizedBox(width: 12),
      _kpi(tr('avDelay'), '${delay.toStringAsFixed(0)}ms',
          delay < 30 ? Colors.greenAccent : delay < 70 ? Colors.amber : Colors.redAccent, text, border),
    ]);
  }

  Widget _kpi(String label, String value, Color color, Color text, Color border) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06), borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label.toUpperCase(),
                style: TextStyle(color: color.withOpacity(0.7), fontSize: 9,
                    fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 0.8)),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          ]),
        ),
      );

  Widget _buildScoreCard(Color card, Color border, Color text, String Function(String) tr, String mediaType) {
    final double conf    = _dbl(_resultData?['confidence'])      / 100;
    final double synth   = _dbl(_resultData?['score_synthetic']) / 100;
    final double unified = _dbl(_resultData?['score_unified'])   / 100;
    final double uncert  = _dbl(_resultData?['uncertainty'])     / 100;
    final double align   = _dbl(_resultData?['alignment_confidence']);
    final String model   = _resultData?['model_used'] ?? '—';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(card, border),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.analytics_outlined, color: Colors.cyanAccent, size: 16),
          const SizedBox(width: 8),
          Text(tr('forensicScores'),
              style: TextStyle(color: text, fontSize: 15, fontWeight: FontWeight.bold)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white.withOpacity(0.08))),
            child: Text(model, style: const TextStyle(color: Colors.cyanAccent, fontSize: 8, fontFamily: 'monospace')),
          ),
        ]),
        const SizedBox(height: 18),
        _scoreBar(tr('unifiedEngine'),    conf,    Colors.tealAccent,   text),
        _scoreBar(tr('genAiDetector'),    synth,   Colors.purpleAccent, text),
        _scoreBar(tr('faceSwapEngine'),   unified, Colors.orangeAccent, text),
        _scoreBar(tr('modelUncertainty'), uncert,  Colors.amberAccent,  text),
        const Divider(color: Colors.white10, height: 20),
        if (mediaType != 'audio')
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(tr('avAlignment'), style: TextStyle(color: text.withOpacity(0.6), fontSize: 12)),
            Text('${(align * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                    color: align > 0.7 ? Colors.greenAccent : align > 0.5 ? Colors.amber : Colors.redAccent,
                    fontWeight: FontWeight.bold)),
          ]),
        if (mediaType == 'audio')
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(tr('audioSpectrumQuality'), style: TextStyle(color: text.withOpacity(0.6), fontSize: 12)),
            Text('${(align * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: align > 0.7 ? Colors.greenAccent : Colors.green, fontWeight: FontWeight.bold)),
          ]),
      ]),
    );
  }

  Widget _scoreBar(String label, double value, Color color, Color text) =>
      Padding(
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label, style: TextStyle(color: text.withOpacity(0.65), fontSize: 12)),
            Text('${(value * 100).toStringAsFixed(1)}%',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
                value: value.clamp(0.0, 1.0), color: color,
                backgroundColor: color.withOpacity(0.12), minHeight: 5),
          ),
        ]),
        padding: const EdgeInsets.only(bottom: 14),
      );

  Widget _buildIndicatorsCard(Color card, Color border, Color text, bool isDark, String Function(String) tr) {
    final List<String> inds = _resultData?['indicators'] != null
        ? List<String>.from(_resultData!['indicators']) : [];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(card, border),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.list_alt_outlined, color: Colors.cyanAccent, size: 16),
          const SizedBox(width: 8),
          Text(tr('architectureTriggers'),
              style: TextStyle(color: text, fontSize: 15, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 14),
        ...inds.map((ind) => _indicator(ind, isDark)),
      ]),
    );
  }

  Widget _indicator(String ind, bool isDark) {
    final bool warn = ind.contains('⚠️') || ind.contains('CRITICAL') || ind.contains('Deepfake') || ind.contains('MULTI');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(warn ? Icons.warning_amber_rounded : Icons.check_circle_outline,
              color: warn ? Colors.orangeAccent : Colors.greenAccent, size: 15),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(ind,
            style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 12, height: 1.45))),
      ]),
    );
  }

  Widget _buildActionsCard(Color card, Color text, bool isDark, AppState appState, String Function(String) tr, String mediaType) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(card, Colors.white.withOpacity(0.06)),
      child: Column(children: [
        SizedBox(
          width: double.infinity, height: 48,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 17, color: Colors.white),
            label: Text(tr('downloadReport'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              if (_resultData == null) return;
              try {
                await PdfService.generateAndDownloadReport(
                  fileName: _selectedFile?.name ?? 'Report.mp4',
                  mediaType: mediaType,
                  analysisData: {
                    'is_manipulated':       _resultData!['is_manipulated'] ?? false,
                    'confidence':           _resultData!['confidence'] ?? 0.0,
                    'fake_probability':     _resultData!['fake_probability'] ?? 0.0,
                    'real_probability':     _resultData!['real_probability'] ?? 0.0,
                    'delay_ms':             _resultData!['delay_ms'] ?? 0.0,
                    'alignment_confidence': _resultData!['alignment_confidence'] ?? 0.0,
                    'score_unified':        _resultData!['score_unified'] ?? 0.0,
                    'score_synthetic':      _resultData!['score_synthetic'] ?? 0.0,
                    'heatmap_mode':         _resultData!['heatmap_mode'] ?? 'authentic',
                    'heatmap_image':        _resultData!['heatmap_image'] as String?,
                    'is_multi_manipulated': _resultData!['is_multi_manipulated'] ?? false,
                    'detected_modes':       _resultData!['detected_modes'] ?? [],
                  },
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('${tr('pdfExportFailed')}: $e',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                  backgroundColor: Colors.red.shade800,
                  duration: const Duration(seconds: 6),
                  action: SnackBarAction(label: tr('ok'), textColor: Colors.white, onPressed: () {}),
                ));
              }
            },
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity, height: 44,
          child: OutlinedButton.icon(
            icon: Icon(Icons.refresh_rounded, size: 15, color: text),
            label: Text(tr('scanAnotherVideo'), style: TextStyle(color: text, fontSize: 13)),
            style: OutlinedButton.styleFrom(
                side: BorderSide(color: text.withOpacity(0.15)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: _reset,
          ),
        ),
      ]),
    );
  }

  // MOBILE WIDGETS (simplifiés pour garder la structure, voir le reste du code ci-dessus)
  Widget _buildPageHeaderMobile(bool isDark, Color text, Color muted, AppState appState, String Function(String) tr) {
    final mediaType = _selectedFile != null ? _getMediaType().toUpperCase() : '';
   
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: _phase == 1 ? Colors.amber : (_phase == 2 && _isFake) ? (_isMultiManipulated ? Colors.orange : Colors.redAccent) : Colors.greenAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _phase == 1 ? tr('scanning') : _phase == 2 ? tr('scanComplete') : tr('forensicSystem'),
            style: TextStyle(color: muted, fontSize: 10, fontFamily: 'monospace', letterSpacing: 1.2, fontWeight: FontWeight.bold),
          ),
        ]),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(tr('deepfakeForensics'),
                  style: TextStyle(color: text, fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            _buildUsageBadge(appState, tr),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _resultData != null
              ? '${tr('activeModel')}: ${_resultData!["model_used"] ?? "best_model_unified.pth"} | ${tr('mediaType')}: ${_resultData!['media_type'] ?? mediaType}'
              : tr('dualEngineDescription'),
          style: TextStyle(color: muted, fontSize: 11, fontFamily: 'monospace'),
        ),
        if (_phase == 2 || _phase == 3) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: Text(tr('newScan'), style: const TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                  foregroundColor: text,
                  side: BorderSide(color: text.withOpacity(0.2)),
                  padding: const EdgeInsets.symmetric(vertical: 10)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildUploadAreaMobile(bool isDark, Color card, Color text, Color border, AppState appState, String Function(String) tr) {
    return Container(
      decoration: _cardDeco(card, border),
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6, runSpacing: 6,
          children: [
            _statusPill('EfficientNet-B2', Colors.cyanAccent),
            _statusPill('CLIP ViT', Colors.purpleAccent),
            _statusPill('WavLM + Wav2Vec2', Colors.greenAccent),
          ],
        ),
        const SizedBox(height: 20),
        DottedBorder(
          color: AppTheme.primaryBlue.withOpacity(0.45),
          strokeWidth: 1.5,
          dashPattern: const [8, 5],
          borderType: BorderType.RRect,
          radius: const Radius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.04),
                borderRadius: BorderRadius.circular(14)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, child) => Opacity(opacity: _phase == 0 ? _pulseAnim.value : 1.0, child: child),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: AppTheme.primaryBlue.withOpacity(0.10), shape: BoxShape.circle),
                  child: const Icon(Icons.video_file_outlined, size: 42, color: AppTheme.primaryBlue),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _selectedFile != null ? _selectedFile!.name : tr('dragDrop'),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: text),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(tr('formats'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Checkbox(
                    value: _contributeAnonymously,
                    onChanged: (val) => setState(() => _contributeAnonymously = val ?? true),
                    activeColor: const Color(0xFF3B82F6),
                  ),
                  Flexible(
                    child: Text(
                      "Contribute anonymously to improve AI",
                      style: TextStyle(color: text.withOpacity(0.8), fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                OutlinedButton(
                  onPressed: _pickFile,
                  style: OutlinedButton.styleFrom(
                      foregroundColor: text,
                      side: const BorderSide(color: AppTheme.primaryBlue, width: 1),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14)),
                  child: Text(tr('browseFiles'), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                if (_selectedFile != null) ...[
                  const SizedBox(width: 14),
                  ElevatedButton.icon(
                    onPressed: () => _startAnalysis(appState),
                    icon: const Icon(Icons.play_circle_outline, size: 18, color: Colors.white),
                    label: Text(tr('analyzeVideo'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14)),
                  ),
                ],
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 20),
        _buildModeLegendGridMobile(text, tr),
      ]),
    );
  }

  Widget _buildModeLegendGridMobile(Color text, String Function(String) tr) {
    final entries = kHeatmapModes.entries.toList();
    return Column(children: [
      Text(tr('detectionModes'),
          style: TextStyle(color: text.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _modeLegendTile(entries[0])),
        const SizedBox(width: 8),
        Expanded(child: _modeLegendTile(entries[1])),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _modeLegendTile(entries[2])),
        const SizedBox(width: 8),
        Expanded(child: _modeLegendTile(entries[3])),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _modeLegendTile(entries[4])),
      ]),
    ]);
  }

  Widget _modeLegendTile(MapEntry<String, HeatmapModeInfo> e) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: e.value.primaryColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: e.value.primaryColor.withOpacity(0.20)),
        ),
        child: Column(children: [
          Icon(e.value.icon, color: e.value.primaryColor, size: 20),
          const SizedBox(height: 6),
          Text(e.value.shortLabel,
              textAlign: TextAlign.center,
              style: TextStyle(color: e.value.primaryColor, fontSize: 8,
                  fontFamily: 'monospace', fontWeight: FontWeight.bold)),
        ]),
      );

  Widget _buildLoadingStateMobile(bool isDark, Color card, Color text, String Function(String) tr) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
        decoration: _cardDeco(card, AppTheme.primaryBlue.withOpacity(0.15)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 64, height: 64,
              child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: const AlwaysStoppedAnimation(AppTheme.primaryBlue),
                  backgroundColor: AppTheme.primaryBlue.withOpacity(0.15)),
            ),
            Icon(Icons.biotech_outlined, size: 26, color: AppTheme.primaryBlue.withOpacity(0.8)),
          ]),
          const SizedBox(height: 24),
          Text(_loadingMsg,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: text),
              textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(tr('loadingMessage'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, height: 1.7, fontSize: 12)),
          const SizedBox(height: 28),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _loadingStep(tr('upload'), true, tr),
              _loadingConnector(),
              _loadingStep(tr('encode'), _loadingMsg.contains(tr('dual')), tr),
              _loadingConnector(),
              _loadingStep(tr('analyze'), _loadingMsg.contains(tr('process')), tr),
              _loadingConnector(),
              _loadingStep(tr('report'), false, tr),
            ]),
          ),
        ]),
      );

  Widget _buildErrorStateMobile(Color card, Color text, Color border, AppState appState, String Function(String) tr) =>
      Container(
        padding: const EdgeInsets.all(20),
        decoration: _cardDeco(card, Colors.red.withOpacity(0.25)),
        child: Column(children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
          const SizedBox(height: 14),
          Text(tr('analysisFailed'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: text)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(0.20))),
            child: Text(_errorMessage ?? tr('unknownError'),
                style: const TextStyle(color: Colors.redAccent, fontFamily: 'monospace', fontSize: 11, height: 1.6)),
          ),
          const SizedBox(height: 16),
          Text(tr('troubleshooting'), style: const TextStyle(color: Colors.grey, height: 1.8, fontSize: 12)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.arrow_back_rounded, size: 15),
              label: Text(tr('goBack')),
              style: OutlinedButton.styleFrom(foregroundColor: text),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() { _phase = 0; _errorMessage = null; });
                if (_selectedFile != null) _startAnalysis(Provider.of<AppState>(context, listen: false));
              },
              icon: const Icon(Icons.refresh_rounded, size: 15),
              label: Text(tr('retryAnalysis')),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue, foregroundColor: Colors.white),
            ),
          ),
        ]),
      );

  Widget _buildResultDashboardMobile(bool isDark, Color card, Color text,
      Color border, Color muted, AppState appState, String Function(String) tr) {
    final mediaType = _resultData?['media_type'] ?? _getMediaType();
   
    return Column(children: [
      _buildMultiManipulationBadge(),
      _buildVerdictBannerMobile(tr, mediaType),
      const SizedBox(height: 16),
      _buildKpiRowMobile(text, border, tr, mediaType),
      const SizedBox(height: 16),
      if (mediaType != 'audio')
        _buildHeatmapCardMobile(isDark, card, border, text, tr),
      if (mediaType != 'audio') const SizedBox(height: 16),
      _buildModeBadgeCard(card, border, text, muted, tr),
      const SizedBox(height: 16),
      _buildScoreCard(card, border, text, tr, mediaType),
      const SizedBox(height: 16),
      _buildIndicatorsCard(card, border, text, isDark, tr),
      const SizedBox(height: 16),
      _buildActionsCard(card, text, isDark, appState, tr, mediaType),
    ]);
  }

  Widget _buildVerdictBannerMobile(String Function(String) tr, String mediaType) {
    final info   = _modeInfo;
    final Color accent = _isFake 
        ? (_isMultiManipulated ? const Color(0xFFFF8C00) : info.primaryColor)
        : const Color(0xFF10B981);
    final double conf  = _dbl(_resultData?['confidence']);
    
    String verb;
    if (_isFake && _isMultiManipulated) {
      verb = '⚠ MULTI-MANIPULATION — FACE-SWAP + VOICE CLONE';
    } else if (_isFake) {
      verb = '⚠ ${tr('deepfakeDetected')} — ${info.label.toUpperCase()}';
    } else {
      verb = '✓ ${tr('mediaAuthenticated')}';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.35), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: accent.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(_isFake ? Icons.warning_amber_rounded : Icons.verified_rounded, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(verb,
                style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
          ),
          Text('${conf.toStringAsFixed(1)}%',
              style: TextStyle(color: accent, fontSize: 22, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 8),
        Text('${info.description} | ${tr('mediaType')}: ${mediaType.toUpperCase()}',
            style: const TextStyle(color: Colors.grey, fontSize: 11, height: 1.4)),
      ]),
    );
  }

  Widget _buildKpiRowMobile(Color text, Color border, String Function(String) tr, String mediaType) {
    final double conf     = _dbl(_resultData?['confidence']);
    final double fakeProb = _dbl(_resultData?['fake_probability']);
    final double delay    = _dbl(_resultData?['delay_ms']);
    final delayColor      = delay < 30 ? Colors.greenAccent : delay < 70 ? Colors.amber : Colors.redAccent;

    if (mediaType == 'audio') {
      return Column(children: [
        Row(children: [
          _kpi(tr('confidence'), '${conf.toStringAsFixed(1)}%',
              _isFake ? _modeInfo.primaryColor : Colors.greenAccent, text, border),
          const SizedBox(width: 10),
          _kpi(tr('fakeProb'), '${fakeProb.toStringAsFixed(1)}%', Colors.redAccent, text, border),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _kpi(tr('audioQuality'), '${(100 - (delay / 10).clamp(0, 100)).toStringAsFixed(0)}%', delayColor, text, border),
        ]),
      ]);
    }
   
    return Column(children: [
      Row(children: [
        _kpi(tr('confidence'), '${conf.toStringAsFixed(1)}%',
            _isFake ? (_isMultiManipulated ? const Color(0xFFFF8C00) : _modeInfo.primaryColor) : Colors.greenAccent, text, border),
        const SizedBox(width: 10),
        _kpi(tr('fakeProb'), '${fakeProb.toStringAsFixed(1)}%', Colors.redAccent, text, border),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        _kpi(tr('avDelay'), '${delay.toStringAsFixed(0)}ms', delayColor, text, border),
      ]),
    ]);
  }

  Widget _buildHeatmapCardMobile(bool isDark, Color card, Color border, Color text, String Function(String) tr) {
    final info     = _modeInfo;
    final String? b64 = _resultData?['heatmap_image'] as String?;
    ImageProvider? img;
    if (b64 != null && b64.contains(',')) {
      try { img = MemoryImage(base64Decode(b64.split(',')[1])); } catch (_) {}
    }

    return Container(
      decoration: BoxDecoration(
        color: card, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: info.primaryColor.withOpacity(0.30), width: 1.5),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.biotech_outlined, color: info.primaryColor, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(tr('neuralAttentionMap'),
                style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          _modePill(info),
        ]),
        const SizedBox(height: 4),
        Text('Grad-CAM · ${info.regionHint}', style: const TextStyle(color: Colors.grey, fontSize: 10)),
        const SizedBox(height: 12),
        Container(
          height: 240,
          decoration: BoxDecoration(
            color: Colors.black, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: info.primaryColor.withOpacity(0.15)),
          ),
          child: Stack(children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: img != null
                    ? GestureDetector(onTap: () => _openFullscreen(img!), child: Image(image: img, fit: BoxFit.contain))
                    : Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.image_not_supported_outlined, size: 36, color: Colors.grey[700]),
                        const SizedBox(height: 8),
                        Text(tr('heatmapUnavailable'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ])),
              ),
            ),
            Positioned(top: 10, left: 10, child: _scanBadge(tr('forensicScan'), info.primaryColor)),
            Positioned(top: 10, right: 10, child: _scanBadge(info.shortLabel, info.primaryColor)),
            if (_isMultiManipulated)
              Positioned(
                bottom: 10, left: 10,
                child: _scanBadge("MULTI", const Color(0xFFFF8C00)),
              ),
            if (img != null)
              Positioned(
                bottom: 10, left: 0, right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.zoom_in, size: 12, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(tr('tapToZoom'), style: const TextStyle(color: Colors.white70, fontSize: 10)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

class CircuitBoardPainter extends CustomPainter {
  final Color color;
  CircuitBoardPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    
    final random = math.Random(42);
    for (int i = 0; i < 150; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), 1.0, paint);
    }
    
    for (int i = 0; i < 60; i++) {
      final x1 = random.nextDouble() * size.width;
      final y1 = random.nextDouble() * size.height;
      final x2 = x1 + (random.nextDouble() - 0.5) * 80;
      final y2 = y1 + (random.nextDouble() - 0.5) * 80;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}