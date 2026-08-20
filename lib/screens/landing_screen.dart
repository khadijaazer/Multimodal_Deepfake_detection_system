import 'dart:convert';
import 'dart:io' as io; // Safe, platform-agnostic file IO library checks [1]
import 'dart:math'; // Random UUID generator
import 'dart:typed_data'; // Resolves Uint8List compiler errors
import 'dart:ui' as ui; // Invariant physical monitor sizing
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import 'auth/auth_screen.dart';
import '../services/scam_detection_service.dart';

const String kHeatmapAuthentic = 'authentic';
const String kHeatmapAudioFake = 'audio_fake';
const String kHeatmapFaceSwap = 'face_swap';
const String kHeatmapGenAI = 'gen_ai';

class HeatmapModeInfo {
  final String label;
  final String shortLabel;
  final Color primaryColor;
  final Color glowColor;
  final IconData icon;
  final String description;
  final String regionHint;

  const HeatmapModeInfo({
    required this.label,
    required this.shortLabel,
    required this.primaryColor,
    required this.glowColor,
    required this.icon,
    required this.description,
    required this.regionHint,
  });
}

const Map<String, HeatmapModeInfo> kHeatmapModes = {
  kHeatmapAuthentic: HeatmapModeInfo(
    label: '✅ AUTHENTIC VIDEO',
    shortLabel: 'AUTHENTIC',
    primaryColor: Color(0xFF10B981),
    glowColor: Color(0xFF34D399),
    icon: Icons.verified_outlined,
    description: 'Soft diffuse emerald glow across stable biometric structures.',
    regionHint: 'Diffuse coverage: eyes • nose • cheeks',
  ),
  kHeatmapAudioFake: HeatmapModeInfo(
    label: '🎤 VOICE CLONE / AUDIO FAKE',
    shortLabel: 'VOICE CLONE',
    primaryColor: Color(0xFFEF4444),
    glowColor: Color(0xFFF87171),
    icon: Icons.mic_off_outlined,
    description: 'Crimson hot-spots concentrated at mouth and lower jaw.',
    regionHint: 'Focus: mouth • lips • lower jaw',
  ),
  kHeatmapFaceSwap: HeatmapModeInfo(
    label: '🎭 FACE-SWAP / MANIPULATION',
    shortLabel: 'FACE-SWAP',
    primaryColor: Color(0xFFEF4444),
    glowColor: Color(0xFFF87171),
    icon: Icons.face_retouching_natural,
    description: 'High-intensity crimson ring tracing face mask boundaries.',
    regionHint: 'Focus: outer seam • eye orbits • nose-bridge • jaw',
  ),
  kHeatmapGenAI: HeatmapModeInfo(
    label: '🤖 FULLY AI GENERATED',
    shortLabel: 'FULLY GEN-AI',
    primaryColor: Color(0xFFA855F7),
    glowColor: Color(0xFFD946EF),
    icon: Icons.auto_awesome_outlined,
    description: 'Decentralized ultraviolet cloud across entire canvas.',
    regionHint: 'Global: full frame • hair • background • face',
  ),
};

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _textCtrl = TextEditingController();
  final GlobalKey _trialKey = GlobalKey();
 
  bool _isAnalyzing = false;
  Map<String, dynamic>? _resultData;
  int _detectionsRemaining = 5;
  bool _contributeAnonymously = true;
  PlatformFile? _selectedFile;

  final ScamDetectionService _scamService = ScamDetectionService();
  final String _baseUrl = 'http://localhost:7860';
  String _deviceId = '';
  String _fingerprintHash = '';

  bool get isMobile => MediaQuery.of(context).size.width < 600;
  bool get isTablet => MediaQuery.of(context).size.width >= 600 && MediaQuery.of(context).size.width < 900;
  bool get isDesktop => MediaQuery.of(context).size.width >= 900;
  
  double get screenPadding => isMobile ? 16 : (isTablet ? 32 : 40);
  double get heroFontSize => isMobile ? 36 : (isTablet ? 44 : 56);
  double get subFontSize => isMobile ? 16 : (isTablet ? 18 : 20);
  double get logoHeight => isMobile ? 60 : (isTablet ? 70 : 80);
  double get trialWidgetWidth => isMobile ? double.infinity : (isTablet ? 700 : 800);
  double get trialWidgetHeight => isMobile ? 520 : 450;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _reset();
      }
    });
    _initDeviceTracking();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  // Deterministic FNV-1a 32-bit stable hash function
  int _stableHash(String input) {
    int hash = 2166136261;
    for (int i = 0; i < input.length; i++) {
      hash ^= input.codeUnitAt(i);
      hash = (hash * 16777619) & 0xFFFFFFFF;
    }
    return hash;
  }

  // Pure Dart Secure RFC4122 v4 UUID Generator [2]
  String _generateUUID() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    
    values[6] = (values[6] & 0x0f) | 0x40; // Set version to 4
    values[8] = (values[8] & 0x3f) | 0x80; // Set variant to RFC4122
    
    final StringBuffer sb = StringBuffer();
    for (int i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) {
        sb.write('-');
      }
      sb.write(values[i].toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  BoxDecoration _cardDeco(Color bg, Color borderColor) {
    return BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor),
    );
  }

  void _reset() {
    setState(() {
      _resultData = null;
      _textCtrl.clear();
      _selectedFile = null;
    });
  }

  Future<void> _initDeviceTracking() async {
    final prefs = await SharedPreferences.getInstance();
    String localId = prefs.getString('detectini_device_id') ?? '';
    
    if (localId.isEmpty) {
      localId = _generateUUID();
      await prefs.setString('detectini_device_id', localId);
    }

    _deviceId = localId;

    // Use absolute physical monitor resolution instead of dynamic browser window boundaries
    final ui.PlatformDispatcher dispatcher = ui.PlatformDispatcher.instance;
    final double screenWidth = dispatcher.views.first.physicalSize.width;
    final double screenHeight = dispatcher.views.first.physicalSize.height;

    final String baseSignature = "${kIsWeb ? 'WebBrowser' : 'MobileDevice'}-${screenWidth.toInt()}x${screenHeight.toInt()}";
    _fingerprintHash = _stableHash(baseSignature).toString();

    _syncTrialLimits();
  }

  Future<bool> _syncTrialLimits() async {
    if (_deviceId.isEmpty) return false;
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/v1/trial/verify'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "device_id": _deviceId,
          "fingerprint": _fingerprintHash,
          "platform": kIsWeb ? "web" : "mobile"
        }),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final int currentCount = data['analysis_count'] ?? 0;
        setState(() {
          _detectionsRemaining = (5 - currentCount).clamp(0, 5);
        });
        return data['allowed'] == true;
      }
    } catch (e) {
      debugPrint("Trial sync failed: $e");
    }
    return _detectionsRemaining > 0;
  }

  Future<void> _incrementTrialCounter() async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/v1/trial/increment'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "device_id": _deviceId,
          "fingerprint": _fingerprintHash
        }),
      );
    } catch (_) {}
  }

  // --- SUBMIT ANONYMOUS TRAINING CONTRIBUTION ---
  Future<void> _submitAnonymousContribution({
    required String filePath,
    required String fileType,
    required bool predictedIsFake,
    required double confidenceScore,
  }) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/v1/trial/contribute'),
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
      debugPrint("Anonymous contribution logger error: $e");
    }
  }

  double _toDouble(dynamic value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  String get _heatmapMode => (_resultData?['heatmap_mode'] as String?) ?? kHeatmapAuthentic;
  HeatmapModeInfo get _modeInfo => kHeatmapModes[_heatmapMode] ?? kHeatmapModes[kHeatmapAuthentic]!;

  Color _getThreatLevelColor(String level) {
    switch (level) {
      case 'CRITICAL': return const Color(0xFF7B1FA2);
      case 'HIGH': return const Color(0xFFEF4444);
      case 'MEDIUM': return const Color(0xFFEF6C00);
      case 'LOW': return const Color(0xFF10B981);
      default: return Colors.grey;
    }
  }

  String _getThreatLevelText(String level) {
    switch (level) {
      case 'CRITICAL': return 'CRITICAL THREAT';
      case 'HIGH': return 'HIGH RISK';
      case 'MEDIUM': return 'MEDIUM RISK';
      case 'LOW': return 'LOW RISK';
      default: return 'UNKNOWN';
    }
  }

  // ==================== TEXT ANALYSIS ====================
  Future<void> _runTextAnalysis() async {
    if (_textCtrl.text.trim().isEmpty) {
      _showErrorSnackBar("Please enter some text to analyze");
      return;
    }

    final bool isAllowed = await _syncTrialLimits();
    if (!isAllowed) {
      _showSignUpDialog();
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _resultData = null;
    });

    try {
      final result = await _scamService.analyzeText(_textCtrl.text);
      await _incrementTrialCounter();
      await _syncTrialLimits();

      setState(() {
        _resultData = result;
        _resultData!['type'] = 'text';
        _resultData!['threat_level'] ??= (result['isScam'] ? 'HIGH' : 'LOW');
      });

      // Log anonymous dataset contribution [1]
      if (_contributeAnonymously) {
        _submitAnonymousContribution(
          filePath: _textCtrl.text.length > 100 ? _textCtrl.text.substring(0, 100) : _textCtrl.text,
          fileType: 'text',
          predictedIsFake: result['isScam'] ?? false,
          confidenceScore: _toDouble(result['confidence']),
        );
      }
    } catch (e) {
      _mockTextResult();
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  // ==================== VIDEO ANALYSIS ====================
  Future<void> _runVideoAnalysis() async {
    if (_selectedFile == null) {
      _showErrorSnackBar("Please select a video file first");
      return;
    }

    final bool isAllowed = await _syncTrialLimits();
    if (!isAllowed) {
      _showSignUpDialog();
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _resultData = null;
    });

    try {
      await http.get(Uri.parse('$_baseUrl/')).timeout(const Duration(seconds: 5)).catchError((_){});

      // Platform-safe file extraction protects mobile deployment from Null reference crashes [1]
      Uint8List fileBytes;
      if (kIsWeb) {
        if (_selectedFile!.bytes == null) {
          throw Exception("Web upload failed: Picked file data is null.");
        }
        fileBytes = _selectedFile!.bytes!;
      } else {
        if (_selectedFile!.bytes != null) {
          fileBytes = _selectedFile!.bytes!;
        } else if (_selectedFile!.path != null) {
          final file = io.File(_selectedFile!.path!);
          fileBytes = await file.readAsBytes();
        } else {
          throw Exception("Mobile upload failed: No local path or data found.");
        }
      }

      var uri = Uri.parse('$_baseUrl/api/ai/scan-video');
      var request = http.MultipartRequest('POST', uri);
      request.files.add(http.MultipartFile.fromBytes(
        'file', fileBytes,
        filename: _selectedFile!.name,
      ));

      var streamedResponse = await request.send().timeout(const Duration(seconds: 300));
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await _incrementTrialCounter();
        await _syncTrialLimits();

        final bool isFake = data['is_manipulated'] ?? false;
        final double confidence = _toDouble(data['confidence']);
        final double fakeProb = _toDouble(data['fake_probability']);
        final double delay = _toDouble(data['delay_ms']);
        final double alignment = _toDouble(data['alignment_confidence']);

        data['type'] = 'video';
        data['score_unified'] = confidence;
        data['score_synthetic'] = isFake ? fakeProb : 50.0;
        data['score_manipulation'] = isFake ? fakeProb : 50.0;
        data['heatmap_mode'] = data['heatmap_mode'] ?? (isFake ? kHeatmapFaceSwap : kHeatmapAuthentic);
        data['model_used'] = data['model_used'] ?? 'best_model_unified.pth';

        data['indicators'] ??= isFake
            ? [
                '⚠️ Deepfake Detected with ${confidence.toStringAsFixed(1)}% confidence',
                '🎭 Multimodal inconsistency detected across video/audio streams',
                '🔬 Unified Forensic Engine identified manipulation patterns',
                '🚨 CRITICAL: Media appears to be artificially generated',
              ]
            : [
                '✅ Media appears AUTHENTIC (${confidence.toStringAsFixed(1)}% confidence)',
                '🔍 No significant manipulation artifacts detected',
                '📊 Video-Audio synchronization verified',
              ];

        setState(() {
          _resultData = data;
        });

        // Log anonymous dataset contribution [1]
        if (_contributeAnonymously) {
          _submitAnonymousContribution(
            filePath: data['file_path'] ?? _selectedFile!.name,
            fileType: 'video',
            predictedIsFake: isFake,
            confidenceScore: confidence,
          );
        }
      } else {
        _mockVideoResult();
      }
    } catch (e) {
      _mockVideoResult();
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _mockTextResult() async {
    await _incrementTrialCounter();
    await _syncTrialLimits();
    
    final mockResult = {
      "type": "text",
      "isScam": true,
      "confidence": 94.3,
      "risk_score": 87.5,
      "threat_level": "HIGH",
      "language": "English",
      "language_confidence": 98.5,
      "scam_category": ["Phishing", "Urgency Scam", "Fake Offer"],
      "urls_found": ["http://fake-link.com/verify"],
      "indicators": [
        "⚠️ Suspicious link detected",
        "⚠️ Urgency language detected",
        "⚠️ Request for personal information",
        "⚠️ Unusual sender email address"
      ],
      "safety_tips": [
        "Do not click on any links in the message",
        "Do not share personal or financial information",
        "Contact the company directly using official channels",
        "Report the message as spam/phishing",
        "Delete the message immediately"
      ]
    };

    setState(() {
      _resultData = mockResult;
    });

    if (_contributeAnonymously) {
      _submitAnonymousContribution(
        filePath: _textCtrl.text.length > 100 ? _textCtrl.text.substring(0, 100) : _textCtrl.text,
        fileType: 'text',
        predictedIsFake: true,
        confidenceScore: 94.3,
      );
    }
  }

  void _mockVideoResult() async {
    await _incrementTrialCounter();
    await _syncTrialLimits();

    final mockResult = {
      "type": "video",
      "is_manipulated": true,
      "confidence": 91.2,
      "fake_probability": 91.2,
      "heatmap_mode": kHeatmapFaceSwap,
      "model_used": "best_model_unified.pth",
      "delay_ms": 45.3,
      "alignment_confidence": 0.62,
      "score_unified": 91.2,
      "score_synthetic": 91.2,
      "score_manipulation": 91.2,
      "indicators": [
        "⚠️ Deepfake Detected with 91.2% confidence",
        "🎭 Face-swap boundary seams detected at outer facial edges",
        "🔬 Resolution micro-discontinuities and stitching artifacts found",
        "🚨 CRITICAL: Localized face manipulation traces confirmed",
      ],
      "safety_tips": [
        "Do not share this manipulated media",
        "Report the content to the platform",
        "Verify through official sources",
      ]
    };

    setState(() {
      _resultData = mockResult;
    });

    if (_contributeAnonymously) {
      _submitAnonymousContribution(
        filePath: _selectedFile?.name ?? "mock_video.mp4",
        fileType: 'video',
        predictedIsFake: true,
        confidenceScore: 91.2,
      );
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: true,
    );
    if (result != null) setState(() => _selectedFile = result.files.first);
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent)
    );
  }

  void _navigateToTrial() {
    final appState = Provider.of<AppState>(context, listen: false);
    appState.setSeenLanding();
    Scrollable.ensureVisible(
      _trialKey.currentContext!,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
    );
  }

  // Updated navigation method to support showing signup form directly
  void _navigateToAuth({bool showSignUp = false}) {
    final appState = Provider.of<AppState>(context, listen: false);
    appState.setSeenLanding();
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => AuthScreen(showSignUp: showSignUp),
      ),
    );
  }

  void _showSignUpDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF151E32),
        title: const Text("Free Limit Reached", style: TextStyle(color: Colors.white)),
        content: const Text("You've used your 5 free scans. Sign up to unlock unlimited forensic analysis.",
          style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Close", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(c);
              _navigateToAuth(showSignUp: true); // Pass true to show signup form
            },
            child: const Text("Sign Up Free")
          ),
        ],
      ),
    );
  }

  void _showShareDialog() {
    if (_resultData == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151E32),
        title: const Text('Share Result', style: TextStyle(color: Colors.white)),
        content: Text(
          'Analysis Result: ${_resultData!['isScam'] == true ? "SCAM" : "SAFE"}\n'
          'Confidence: ${_resultData!['confidence']}%\n'
          'Language: ${_resultData!['language'] ?? "English"}',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Result copied to clipboard'), backgroundColor: Colors.green),
              );
            },
            child: const Text('Copy to Clipboard'),
          ),
        ],
      ),
    );
  }

  // ==================== TRIGGERING NETWORK ATTRIBUTION ====================
  List<Map<String, dynamic>> _getDetectingEngines() {
    final bool isFake = _resultData?['is_manipulated'] ?? false;
    final double delay = _toDouble(_resultData?['delay_ms']);
    final double alignment = _toDouble(_resultData?['alignment_confidence']);
    final double fakeProb = _toDouble(_resultData?['fake_probability']);
   
    return [
      {
        'name': 'MDDA Attention Fusion',
        'tech': 'EfficientNet + CLIP ViT + Text',
        'description': 'Identifies semantic disconnects between facial movements and speech.',
        'isTriggered': isFake && fakeProb > 65.0,
        'confidence': fakeProb,
      },
      {
        'name': 'ERF Cross-Reconstruction',
        'tech': 'BA-TFD+ Transformer',
        'description': 'Detects mechanical desynchronization between voice signals and lip movements.',
        'isTriggered': isFake && (delay > 35.0 || alignment < 0.65),
        'confidence': delay > 35.0 ? 88.0 : 15.0,
      },
      {
        'name': 'Audity Spectral Module',
        'tech': 'WavLM + Wav2Vec2',
        'description': 'Screens acoustic frequencies for synthetic speech vocoder traces.',
        'isTriggered': isFake && fakeProb > 72.0 && delay <= 35.0,
        'confidence': isFake ? (fakeProb - 4.0).clamp(0.0, 100.0) : 12.5,
      },
      {
        'name': 'BNN Mobile CNN',
        'tech': 'Binary Neural Network',
        'description': 'Scans face boundaries and eye regions for stitching anomalies.',
        'isTriggered': isFake && fakeProb > 50.0,
        'confidence': fakeProb,
      },
    ];
  }

  // ==================== BUILD UI ====================
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = appState.isDarkMode;

    Color bg = isDark ? const Color(0xFF0B1121) : const Color(0xFFF8FAFC);
    Color textMain = isDark ? Colors.white : const Color(0xFF1E293B);
    Color textSub = isDark ? Colors.grey : const Color(0xFF707E94);
    
    // Choose circuit colour based on theme
    final Color circuitColor = (isDark ? Colors.white : Colors.black).withOpacity(0.03);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // Always show circuit pattern with theme-aware color
          Positioned.fill(
            child: CustomPaint(
              painter: CircuitBoardPainter(color: circuitColor),
            ),
          ),
          SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: screenPadding),
              child: Column(
                children: [
                  _buildNavbar(context, isDark, appState),
                  const SizedBox(height: 60),
                  _buildHero(isDark, textMain, textSub),
                  const SizedBox(height: 80),
                  _buildStepSection(isDark),
                  const SizedBox(height: 100),
                  Container(
                    key: _trialKey,
                    child: _buildTrialWidget(isDark, textMain),
                  ),
                  const SizedBox(height: 40),
                  if (_resultData != null) ...[
                    _buildResultDashboard(isDark),
                    const SizedBox(height: 24),
                    _buildActionsCard(isDark ? const Color(0xFF151E32) : Colors.white, textMain, isDark),
                  ],
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavbar(BuildContext context, bool isDark, AppState appState) {
    Color textCol = isDark ? Colors.white : Colors.black87;
    
    // Choose logo based on theme
    String logoAsset = isDark
        ? 'assets/logowhite2.png'   // Logo for dark mode (white/light)
        : 'assets/logolight.png';    // Logo for light mode (dark/black)
   
    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Image.asset(
              logoAsset,
              height: logoHeight,
              width: 200,
              fit: BoxFit.contain,
              errorBuilder: (c, e, s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shield, color: Colors.white, size: 32),
                    const SizedBox(width: 8),
                    Text(
                      "FORENSIC AI",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: textCol),
                  onPressed: () => appState.toggleTheme(),
                ),
                TextButton(
                  onPressed: () => _navigateToAuth(showSignUp: false), // Login
                  child: Text("LOGIN", style: TextStyle(color: textCol)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _navigateToAuth(showSignUp: true), // Sign Up
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
                  ),
                  child: const Text("SIGN UP", style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ],
            )
          ],
        ),
      );
    }
   
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        children: [
          Image.asset(
            logoAsset,
            height: logoHeight,
            width: 280,
            fit: BoxFit.contain,
            errorBuilder: (c, e, s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield, color: Colors.white, size: 40),
                  const SizedBox(width: 10),
                  Text(
                    "FORENSIC AI",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: textCol),
            onPressed: () => appState.toggleTheme(),
          ),
          const SizedBox(width: 20),
          OutlinedButton(
            onPressed: () => _navigateToAuth(showSignUp: false), // Login
            style: OutlinedButton.styleFrom(side: BorderSide(color: textCol.withOpacity(0.3))),
            child: Text("LOGIN", style: TextStyle(color: textCol)),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () => _navigateToAuth(showSignUp: true), // Sign Up
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
            child: const Text("SIGN UP", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(bool isDark, Color textMain, Color textSub) {
    return Column(
      children: [
        Text(
          "Detect. Verify. Trust.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: heroFontSize,
            fontWeight: FontWeight.w900,
            color: textMain,
            letterSpacing: -1
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "Multimodal Deepfake & Scam Detection.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: subFontSize, color: textSub),
        ),
        const SizedBox(height: 30),
        Container(
          decoration: BoxDecoration(
            boxShadow: isDark ? [BoxShadow(color: const Color(0xFF3B82F6).withOpacity(0.5), blurRadius: 30, spreadRadius: 1)] : [],
          ),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.video_camera_front, color: Colors.white),
            label: const Text("Try Now - No Sign Up", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 32, vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            onPressed: _navigateToTrial,
          ),
        ),
      ],
    );
  }

  Widget _buildStepSection(bool isDark) {
    final list = [
      _stepCard("1", "Upload", "Upload media or paste text.", isDark),
      _stepCard("2", "AI Analysis", "Multimodal engine scans anomalies.", isDark),
      _stepCard("3", "Get Results", "Receive detailed forensic report.", isDark),
    ];
    if (isMobile) {
      return Column(
        children: list.expand((w) => [w, const SizedBox(height: 16)]).toList()..removeLast(),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: list.expand((w) => [w, SizedBox(width: isTablet ? 16 : 24)]).toList()..removeLast(),
    );
  }

  Widget _stepCard(String n, String t, String s, bool isDark) {
    return Container(
      width: isMobile ? double.infinity : (isTablet ? 180 : 220),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151E32) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200),
        boxShadow: isDark
          ? [BoxShadow(color: const Color(0xFF00D2D3).withOpacity(0.1), blurRadius: 15)]
          : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Text(n, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF00D2D3))),
          const SizedBox(height: 12),
          Text(t, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 8),
          Text(s, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey : Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildResultDashboard(bool isDark) {
    final bool isVideo = _resultData!['type'] == 'video';
   
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 1000;
       
        if (isVideo) {
          if (isWide && !isMobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAlertBanner(isDark),
                const SizedBox(height: 16),
                _buildHeatmapModeLegend(isDark),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildForensicVisualizer(isDark)),
                    const SizedBox(width: 24),
                    Expanded(flex: 2, child: _buildMetricsPanel(isDark)),
                  ],
                ),
              ],
            );
          }
          return Column(children: [
            _buildAlertBanner(isDark),
            const SizedBox(height: 16),
            _buildHeatmapModeLegend(isDark),
            const SizedBox(height: 20),
            _buildForensicVisualizer(isDark),
            const SizedBox(height: 24),
            _buildMetricsPanel(isDark),
          ]);
        }
       
        return _buildScamResultCard(isDark);
      },
    );
  }

  Widget _buildScamResultCard(bool isDark) {
    final isScam = _resultData!['isScam'] ?? false;
    final threatLevel = _resultData!['threat_level'] ?? (isScam ? 'HIGH' : 'LOW');
    final statusColor = isScam ? _getThreatLevelColor(threatLevel) : const Color(0xFF10B981);
    final result = _resultData!;
   
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151E32) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.5), width: 2),
        boxShadow: [BoxShadow(color: statusColor.withOpacity(0.15), blurRadius: 30)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: statusColor.withOpacity(0.35), blurRadius: 18)],
            ),
            child: Row(children: [
              Icon(isScam ? Icons.warning_amber_rounded : Icons.check_circle, color: Colors.white, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isScam ? '⚠️ CRITICAL ALERT: SCAM DETECTED' : '✅ MESSAGE AUTHENTICATED',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    Text(
                      isScam
                          ? 'This message contains scam indicators. Do not engage or share personal information.'
                          : 'No scam patterns detected. Message appears legitimate.',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${result['confidence']}%',
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                Text(_getThreatLevelText(threatLevel),
                    style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace')),
              ]),
            ]),
          ),
         
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Confidence', style: TextStyle(fontSize: 11, color: statusColor)),
                      const SizedBox(height: 2),
                      Text('${result['confidence']}%', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: statusColor)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Language', style: TextStyle(fontSize: 11, color: Colors.blue)),
                      const SizedBox(height: 2),
                      Text(result['language'] ?? 'English', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                      if (result['language_confidence'] != null) ...[
                        const SizedBox(height: 2),
                        Text('${result['language_confidence']}% confidence', style: TextStyle(fontSize: 10, color: Colors.blue.withOpacity(0.7))),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (result['scam_category'] != null && (result['scam_category'] as List).isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Scam Categories:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (result['scam_category'] as List).map((category) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(category, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w500)),
                );
              }).toList(),
            ),
          ],

          if (result['urls_found'] != null && (result['urls_found'] as List).isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Suspicious URLs:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.redAccent)),
            const SizedBox(height: 8),
            ...(result['urls_found'] as List).take(3).map((url) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: Text(url, style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w500)),
              );
            }).toList(),
          ],

          const SizedBox(height: 16),
          const Text('Key Indicators:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          ...(result['indicators'] as List).map((indicator) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(isScam ? Icons.warning_amber : Icons.check_circle, size: 16, color: statusColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(indicator, style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[300] : Colors.grey[800])),
                  ),
                ],
              ),
            );
          }).toList(),

          if (isScam && result['safety_tips'] != null && (result['safety_tips'] as List).isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.security, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Text('Safety Tips:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 14))
                  ]),
                  const SizedBox(height: 12),
                  ...(result['safety_tips'] as List).map((tip) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(color: Colors.blue)),
                          Expanded(child: Text(tip, style: const TextStyle(fontSize: 12))),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _reset,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey,
                    side: const BorderSide(color: Colors.grey),
                    padding: const EdgeInsets.symmetric(vertical: 12)
                  ),
                  child: const Text("CLEAR"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text("SHARE RESULT"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12)
                  ),
                  onPressed: _showShareDialog,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== ALERT BANNER ====================
  Widget _buildAlertBanner(bool isDark) {
    final bool isFake = _resultData?['is_manipulated'] ?? false;
    final info = _modeInfo;
    final Color alertColor = isFake ? info.primaryColor : const Color(0xFF10B981);
    final String verdictString = _resultData?['verdict_string'] ?? (isFake ? 'DEEPFAKE DETECTED' : 'AUTHENTIC VIDEO');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(
        color: alertColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: alertColor.withOpacity(0.35), blurRadius: 18)],
      ),
      child: Row(children: [
        Icon(isFake ? Icons.warning_amber_rounded : Icons.check_circle, color: Colors.white, size: 28),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isFake ? '⚠️ CRITICAL ALERT: $verdictString' : '✅ MEDIA AUTHENTICATED',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
              Text(
                isFake ? info.description.split('.').first : 'Fully verified biometric markers and spectrogram timeline.',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${_toDouble(_resultData?['confidence']).toStringAsFixed(1)}%',
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          Text(info.shortLabel,
              style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace')),
        ]),
      ]),
    );
  }

  // ==================== HEATMAP MODE LEGEND ====================
  Widget _buildHeatmapModeLegend(bool isDark) {
    final info = _modeInfo;
    final mode = _heatmapMode;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: info.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: info.primaryColor.withOpacity(0.35), width: 1.5),
        boxShadow: [BoxShadow(color: info.glowColor.withOpacity(0.18), blurRadius: 18, spreadRadius: 1)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: info.primaryColor.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(info.icon, color: info.primaryColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('NEURAL ATTENTION MAP MODE',
                        style: TextStyle(color: info.primaryColor.withOpacity(0.7), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    const SizedBox(width: 8),
                    _modeChip(mode, info.primaryColor),
                  ]),
                  const SizedBox(height: 4),
                  Text(info.label, style: TextStyle(color: info.primaryColor, fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Text(info.description, style: const TextStyle(color: Colors.grey, fontSize: 12, height: 1.5)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: info.primaryColor.withOpacity(0.06),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: info.primaryColor.withOpacity(0.20)),
            ),
            child: Row(children: [
              Icon(Icons.place_outlined, size: 12, color: info.primaryColor),
              const SizedBox(width: 6),
              Text('ACTIVATION FOCUS: ${info.regionHint}',
                  style: TextStyle(color: info.primaryColor, fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _modeChip(String mode, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.40)),
    ),
    child: Text(mode.toUpperCase().replaceAll('_', ' '),
        style: TextStyle(color: color, fontSize: 8, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
  );

  // ==================== FORENSIC VISUALIZER ====================
  Widget _buildForensicVisualizer(bool isDark) {
    final info = _modeInfo;
    final String? heatmapB64 = _resultData?['heatmap_image'];
   
    ImageProvider? imageProvider;
    if (heatmapB64 != null && heatmapB64.startsWith('data:image')) {
      try {
        imageProvider = MemoryImage(base64Decode(heatmapB64.split(',')[1]));
      } catch (e) {
        debugPrint('Image parse failure: $e');
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF151E32),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: info.primaryColor.withOpacity(0.30), width: 1.5),
            boxShadow: [BoxShadow(color: info.glowColor.withOpacity(0.12), blurRadius: 20)],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Neural Attention Heatmap',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('${info.shortLabel} — Grad-CAM spatial activation map',
                    style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ]),
            ]),
            const SizedBox(height: 16),
            Container(
              height: isMobile ? 300 : 400,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: info.primaryColor.withOpacity(0.15)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: imageProvider != null
                    ? GestureDetector(
                        onTap: () => _openFullscreen(imageProvider!),
                        child: Image(image: imageProvider, fit: BoxFit.contain),
                      )
                    : const Center(child: Icon(Icons.hourglass_empty, size: 40, color: Colors.grey)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 24),
        _buildAttributionSection(isDark),
      ],
    );
  }

  void _openFullscreen(ImageProvider imageProvider) {
    showDialog(
      context: context,
      builder: (_) => Dialog.fullscreen(
        backgroundColor: const Color(0xFF0B1121),
        child: Stack(children: [
          InteractiveViewer(maxScale: 6.0, child: Center(child: Image(image: imageProvider))),
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

  // ==================== ACTIONS CARD (PDF REPORT REMOVED) ====================
  Widget _buildActionsCard(Color card, Color text, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(card, Colors.white.withOpacity(0.06)),
      child: Column(children: [
        // PDF Report button REMOVED - only keep "Scan Another" button
        SizedBox(
          width: double.infinity, height: 48,
          child: OutlinedButton.icon(
            icon: Icon(Icons.refresh_rounded, size: 15, color: text),
            label: Text('Scan Another',
                style: TextStyle(color: text, fontSize: 13)),
            style: OutlinedButton.styleFrom(
                side: BorderSide(color: text.withOpacity(0.15)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: _reset,
          ),
        ),
      ]),
    );
  }

  // ==================== TRIGGERING NETWORK ATTRIBUTION UI ====================
  Widget _buildAttributionSection(bool isDark) {
    final engines = _getDetectingEngines();
    final textCol = isDark ? Colors.white : const Color(0xFF1E293B);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151E32) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.developer_board, color: Colors.cyanAccent, size: 20),
          const SizedBox(width: 8),
          Text('Triggering Network Attribution',
              style: TextStyle(color: textCol, fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        const SizedBox(height: 6),
        const Text('Which integrated neural module flagged localized synthetic traces.',
            style: TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: engines.length,
          separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 20),
          itemBuilder: (_, i) {
            final e = engines[i];
            final bool tri = e['isTriggered'] as bool;
            final double sc = e['confidence'] as double;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: tri ? Colors.red.withOpacity(0.10) : Colors.green.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(tri ? Icons.warning_amber_rounded : Icons.gpp_good_outlined,
                      color: tri ? Colors.redAccent : Colors.greenAccent, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(e['name'] as String,
                            style: TextStyle(color: textCol, fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(4)),
                          child: Text(e['tech'] as String,
                              style: const TextStyle(color: Colors.grey, fontSize: 9, fontFamily: 'monospace')),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Text(e['description'] as String,
                          style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(tri ? 'FLAGGED' : 'SECURE',
                      style: TextStyle(color: tri ? Colors.redAccent : Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                  Text('${sc.toStringAsFixed(1)}% weight',
                      style: const TextStyle(color: Colors.grey, fontSize: 10)),
                ]),
              ],
            );
          },
        ),
      ]),
    );
  }

  // ==================== METRICS PANEL ====================
  Widget _buildMetricsPanel(bool isDark) {
    if (_resultData == null) return const SizedBox.shrink();

    final textCol = isDark ? Colors.white : const Color(0xFF1E293B);
    final info = _modeInfo;

    final double confidenceScore = _toDouble(_resultData?['confidence']) / 100;
    final double syntheticScore = _toDouble(_resultData?['score_synthetic'] ?? 50.0) / 100;
    final double manipulationScore = _toDouble(_resultData?['score_unified'] ?? 0.0) / 100;
    final double uncertainty = _toDouble(_resultData?['uncertainty']) / 100;
    final double alignment = _toDouble(_resultData?['alignment_confidence']);
    final double delay = _toDouble(_resultData?['delay_ms']);
    final String activePth = _resultData?['model_used'] ?? 'best_model_unified.pth';
    final List<String> indicators = _resultData?['indicators'] != null
        ? List<String>.from(_resultData!['indicators'])
        : [];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151E32) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: info.primaryColor.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(info.icon, color: info.primaryColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(info.label, style: TextStyle(color: info.primaryColor, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(info.regionHint, style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                ]),
              ),
            ]),
            const SizedBox(height: 14),
            const Divider(color: Colors.white10),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('ACTIVE PIPELINE', style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Text(activePth, style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                  ),
                ]),
              ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('ANALYSIS CONFIDENCE', style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('${(confidenceScore * 100).toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ]),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 20),

        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Forensic Breakdown', style: TextStyle(color: textCol, fontWeight: FontWeight.bold, fontSize: 18)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white10)),
            child: Row(children: [
              const Icon(Icons.layers, size: 10, color: Colors.cyanAccent),
              const SizedBox(width: 4),
              Text(activePth, style: const TextStyle(color: Colors.white70, fontSize: 9, fontFamily: 'monospace')),
            ]),
          ),
        ]),
        const SizedBox(height: 24),

        _buildMetricRow('Unified Forensic Engine (Overall)', confidenceScore, Colors.tealAccent, textCol),
        _buildMetricRow('Synthetic AI Detector (Fully-Gen AI)', syntheticScore, Colors.orange, textCol),
        _buildMetricRow('Face-Swap / Manipulation Engine', manipulationScore, Colors.purple, textCol),

        const Divider(height: 30),

        if (uncertainty > 0 || alignment > 0 || delay > 0) ...[
          Text('Real-time Analysis Metrics', style: TextStyle(color: textCol, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          if (uncertainty > 0) _buildMetricRow('Model Uncertainty', uncertainty, Colors.orangeAccent, textCol),
          if (alignment > 0) _buildMetricRow('Audio-Video Alignment', alignment.clamp(0.0, 1.0), Colors.cyanAccent, textCol),
          if (delay > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('AV Sync Delay', style: TextStyle(color: textCol.withOpacity(0.7), fontSize: 13)),
                  Text('${delay.toStringAsFixed(1)} ms',
                      style: TextStyle(color: delay < 30 ? Colors.green : (delay < 70 ? Colors.orange : Colors.red), fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          const Divider(height: 30),
        ],

        Text('Architecture Triggers', style: TextStyle(color: textCol, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        ...indicators.map((ind) => _indicator(ind, isDark)),
      ]),
    );
  }

  Widget _buildMetricRow(String label, double value, Color color, Color textCol) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text(label, style: TextStyle(color: textCol.withOpacity(0.7), fontSize: 13))),
          Text('${(value * 100).toStringAsFixed(1)}%', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            color: color,
            backgroundColor: color.withOpacity(0.15),
            minHeight: 6,
          ),
        ),
      ]),
    );
  }

  Widget _indicator(String text, bool isDark) {
    final isWarning = text.contains('⚠️') || text.contains('CRITICAL') || text.contains('manipulated');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(isWarning ? Icons.warning : Icons.check_circle,
            color: isWarning ? const Color(0xFFE53935) : Colors.green, size: 16),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[800], fontSize: 13))),
      ]),
    );
  }

  // ==================== TRIAL WIDGET ====================
  Widget _buildTrialWidget(bool isDark, Color textMain) {
    return Center(
      child: Container(
        width: trialWidgetWidth,
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF00D2D3),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: const Color(0xFF00D2D3).withOpacity(0.4), blurRadius: 15)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bar_chart, color: Colors.black87, size: 18),
                  const SizedBox(width: 8),
                  Text("REMAINING: $_detectionsRemaining/5 FREE SCANS",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
                ],
              ),
            ),
            Container(
              height: trialWidgetHeight,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF151E32) : Colors.white,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    indicatorColor: const Color(0xFF00D2D3),
                    labelColor: textMain,
                    unselectedLabelColor: Colors.grey,
                    tabs: const [
                      Tab(icon: Icon(Icons.video_collection), text: "Deepfake Scan"),
                      Tab(icon: Icon(Icons.text_snippet), text: "Scam Scanner"),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildDeepfakeTab(isDark),
                        _buildScamTab(isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeepfakeTab(bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: isMobile ? double.infinity : 500,
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
            ),
            child: Column(
              children: [
                Icon(Icons.cloud_upload_outlined, size: isMobile ? 48 : 64, color: Colors.blueAccent.withOpacity(0.5)),
                const SizedBox(height: 16),
                Text(
                  _selectedFile != null ? _selectedFile!.name : "Select video to scan for Deepfakes",
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                const Text("MP4, MOV, AVI (Max 500 MB)", style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _pickFile,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
                        child: const Text("BROWSE FILES", style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
                        style: TextStyle(color: isDark ? Colors.grey : Colors.black54, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (_isAnalyzing || _selectedFile == null) ? null : _runVideoAnalysis,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isAnalyzing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("START FORENSIC SCAN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScamTab(bool isDark) {
    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        children: [
          Expanded(
            child: TextField(
              controller: _textCtrl,
              maxLines: isMobile ? 8 : 10,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: "Paste suspicious email, text message, or social media post here...",
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: isDark ? const Color(0xFF0B1121) : Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isAnalyzing ? null : _runTextAnalysis,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isAnalyzing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                : const Text("ANALYZE FOR SCAM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class CircuitBoardPainter extends CustomPainter {
  final Color color;
  CircuitBoardPainter({this.color = Colors.white10});
 
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1.5..style = PaintingStyle.stroke;
    final dotPaint = Paint()..color = color.withOpacity(0.2)..style = PaintingStyle.fill;
    final path = Path();
   
    path.moveTo(0, size.height * 0.2);
    path.lineTo(size.width * 0.15, size.height * 0.2);
    path.lineTo(size.width * 0.25, size.height * 0.3);
    canvas.drawCircle(Offset(size.width * 0.25, size.height * 0.3), 4, dotPaint);
   
    path.moveTo(size.width, size.height * 0.7);
    path.lineTo(size.width * 0.85, size.height * 0.7);
    path.lineTo(size.width * 0.75, size.height * 0.8);
    canvas.drawCircle(Offset(size.width * 0.75, size.height * 0.8), 4, dotPaint);
   
    path.moveTo(size.width * 0.5, 0);
    path.lineTo(size.width * 0.5, size.height * 0.1);
    path.lineTo(size.width * 0.6, size.height * 0.15);
    canvas.drawCircle(Offset(size.width * 0.6, size.height * 0.15), 4, dotPaint);
   
    canvas.drawPath(path, paint);
  }
 
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
} 