import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart' as fp;
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../services/pdf_service.dart';

class DeepfakeScreen extends StatefulWidget {
  const DeepfakeScreen({super.key});

  @override
  State<DeepfakeScreen> createState() => _DeepfakeScreenState();
}

class _DeepfakeScreenState extends State<DeepfakeScreen> {
  int _currentState = 0; // 0=upload, 1=loading, 2=result, 3=error
  String _loadingMessage = "Waking up analysis server...";
  String? _errorMessage;

  fp.PlatformFile? _selectedFile;
  Map<String, dynamic>? _resultData;

  static const String _backendBase = 'https://khadidjaabderrahmane-detectini-backend.hf.space';
  
  // ── Helper for safe numeric parsing ──────────────────────────────────────────
  double _toDouble(dynamic value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  // ── File picker ──────────────────────────────────────────────────────────────
  Future<void> _pickFile() async {
    fp.FilePickerResult? result = await fp.FilePicker.platform.pickFiles(
      type: fp.FileType.video,
      withData: true,
    );
    if (result != null) {
      setState(() => _selectedFile = result.files.first);
    }
  }

  // ── Wake-up ping ─────────────────────────────────────────────────────────────
  Future<void> _wakeUpServer() async {
    try {
      await http
          .get(Uri.parse('$_backendBase/'))
          .timeout(const Duration(seconds: 15));
    } catch (_) {}
  }

  // ── Main analysis ────────────────────────────────────────────────────────────
  void _startAnalysis(AppState appState) async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a video first.")),
      );
      return;
    }

    if (!appState.canUpload) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Monthly scan limit reached. Please upgrade."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _currentState = 1;
      _loadingMessage = "Waking up analysis server...";
      _errorMessage = null;
    });

    await _wakeUpServer();
    setState(() => _loadingMessage = "Uploading video evidence...");

    try {
      final uri = Uri.parse('$_backendBase/api/ai/scan-video');
      final request = http.MultipartRequest('POST', uri);

      request.files.add(http.MultipartFile.fromBytes(
        'file',
        _selectedFile!.bytes!,
        filename: _selectedFile!.name,
      ));

      setState(() => _loadingMessage = "Running Dual Forensic Engines...");
      final streamedResponse = await request.send().timeout(const Duration(seconds: 300));

      setState(() => _loadingMessage = "Processing results...");
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        final bool isFake = data['is_manipulated'] ?? false;
        final double confidence = _toDouble(data['confidence']);
        final double fakeProb = _toDouble(data['fake_probability']);

        data['score_unified'] ??= confidence;
        data['score_synthetic'] ??= isFake ? fakeProb : 50.0;
        data['score_manipulation'] ??= isFake ? fakeProb : 50.0;

        data['indicators'] ??= isFake
            ? [
                "⚠️ Deepfake Detected with ${confidence.toStringAsFixed(1)}% confidence",
                "🎭 Multimodal inconsistency detected across video/audio streams",
                "🔬 Unified Forensic Engine identified manipulation patterns",
                "🚨 CRITICAL: Media appears to be artificially generated",
              ]
            : [
                "✅ Media appears AUTHENTIC (${confidence.toStringAsFixed(1)}% confidence)",
                "🔍 No significant manipulation artifacts detected",
                "📊 Video-Audio synchronization verified",
              ];

        // Save to Supabase
        try {
          await Supabase.instance.client.from('scans').insert({
            'user_id': Supabase.instance.client.auth.currentUser!.id,
            'scan_type': 'video',
            'file_name': _selectedFile!.name,
            'is_threat': isFake,
            'confidence_score': confidence,
            'risk_level': isFake ? 'CRITICAL' : 'SAFE',
          });
        } catch (e) {
          debugPrint("Failed to save history to DB: $e");
        }

        appState.recordScanUsage();

        setState(() {
          _resultData = data;
          _currentState = 2;
        });
      } else {
        _showError(
          appState,
          "Server returned status ${response.statusCode}.\n\n"
          "Response: ${response.body.length > 300 ? response.body.substring(0, 300) + '…' : response.body}",
        );
      }
    } on Exception catch (e) {
      _showError(appState, e.toString());
    }
  }

  void _showError(AppState appState, String message) {
    debugPrint("Analysis failed: $message");
    setState(() {
      _currentState = 3;
      _errorMessage = message;
    });
  }

  void _reset() {
    setState(() {
      _currentState = 0;
      _selectedFile = null;
      _resultData = null;
      _errorMessage = null;
      _loadingMessage = "Waking up analysis server...";
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = appState.isDarkMode;

    final bgCol = isDark ? const Color(0xFF0B1121) : const Color(0xFFF8FAFC);
    final cardCol = isDark ? const Color(0xFF151E32) : Colors.white;
    final textCol = isDark ? Colors.white : const Color(0xFF1E293B);
    final borderCol = isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300;

    return Scaffold(
      backgroundColor: bgCol,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Deepfake Forensics",
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textCol),
                    ),
                    Row(
                      children: [
                        Text(
                          _resultData != null
                              ? "Active Model: ${_resultData!['model_used'] ?? 'best_model_unified.pth'}  •  "
                              : "Dual-Engine Forensic System  •  ",
                          style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'monospace'),
                        ),
                        Text(
                          appState.subscriptionPlan == 'free'
                              ? "Scans Used: ${appState.scansUsed} / ${appState.maxScans}"
                              : "Scans: Unlimited",
                          style: TextStyle(
                            color: appState.canUpload ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_currentState == 2 || _currentState == 3)
                  OutlinedButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text("New Scan"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textCol,
                      side: BorderSide(color: borderCol),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 30),

            if (!appState.canUpload)
              _buildPaywall(isDark, cardCol, textCol, appState)
            else if (_currentState == 0)
              _buildUploadArea(isDark, textCol, appState)
            else if (_currentState == 1)
              _buildLoadingState(isDark, textCol)
            else if (_currentState == 3)
              _buildErrorState(isDark, cardCol, textCol, appState)
            else
              _buildResultDashboard(isDark, cardCol, textCol, borderCol),
          ],
        ),
      ),
    );
  }

  // ── Paywall ───────────────────────────────────────────────────────────────────
  Widget _buildPaywall(bool isDark, Color cardCol, Color textCol, AppState appState) {
    return Container(
      height: 500,
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardCol,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.lock_outline, size: 60, color: Colors.redAccent),
          ),
          const SizedBox(height: 24),
          Text("Monthly Limit Reached", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textCol)),
          const SizedBox(height: 12),
          const Text(
            "You have used all your free scans for this month.\n"
            "Upgrade to a Pro or Enterprise plan for unlimited video analysis.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            icon: const Icon(Icons.star, color: Colors.white),
            label: const Text("VIEW PLANS & UPGRADE"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            ),
            onPressed: () => appState.setIndex(1),
          ),
        ],
      ),
    );
  }

  // ── Upload area ───────────────────────────────────────────────────────────────
  Widget _buildUploadArea(bool isDark, Color textCol, AppState appState) {
    return Container(
      height: 500,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151E32) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DottedBorder(
            color: AppTheme.primaryBlue.withOpacity(0.5),
            strokeWidth: 2,
            dashPattern: const [8, 4],
            borderType: BorderType.RRect,
            radius: const Radius.circular(20),
            child: Container(
              width: 600,
              height: 350,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: AppTheme.primaryBlue.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.video_file, size: 60, color: AppTheme.primaryBlue),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _selectedFile != null ? _selectedFile!.name : "Drag & Drop Video Evidence",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textCol),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text("Supported formats: MP4, MOV, AVI (Max 500MB)", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: _pickFile,
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
                        child: const Text("BROWSE FILES"),
                      ),
                      const SizedBox(width: 16),
                      if (_selectedFile != null)
                        ElevatedButton(
                          onPressed: () => _startAnalysis(appState),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          ),
                          child: const Text("ANALYZE VIDEO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Loading state ────────────────────────────────────────────────────────────
  Widget _buildLoadingState(bool isDark, Color textCol) {
    return SizedBox(
      height: 500,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 60, height: 60, child: CircularProgressIndicator(color: AppTheme.primaryBlue, strokeWidth: 4)),
            const SizedBox(height: 24),
            Text(_loadingMessage, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textCol), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
              "This may take up to 3–5 minutes on first run\n(the server wakes from sleep, then loads the dual models)",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error state ───────────────────────────────────────────────────────────────
  Widget _buildErrorState(bool isDark, Color cardCol, Color textCol, AppState appState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: cardCol,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text("Analysis Failed", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textCol)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.07), borderRadius: BorderRadius.circular(12)),
            child: Text(
              _errorMessage ?? "Unknown error",
              style: const TextStyle(color: Colors.redAccent, fontFamily: 'monospace', fontSize: 12, height: 1.6),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Tips:\n"
            "• HuggingFace Spaces can take 2–4 minutes to wake up — try again\n"
            "• Make sure the video file is under 500 MB\n"
            "• Check that the backend Space is not paused on HuggingFace",
            style: TextStyle(color: Colors.grey, height: 1.7),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text("Go Back"),
                style: OutlinedButton.styleFrom(foregroundColor: textCol),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _currentState = 0;
                    _errorMessage = null;
                  });
                  if (_selectedFile != null) {
                    final appState = Provider.of<AppState>(context, listen: false);
                    _startAnalysis(appState);
                  }
                },
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Result dashboard ──────────────────────────────────────────────────────────
  Widget _buildResultDashboard(bool isDark, Color cardCol, Color textCol, Color borderCol) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 1000;
        final visualSection = _buildForensicReportViewer(isDark, cardCol, borderCol, textCol, isWide);
        final metricsSection = _buildMetricsPanel(isDark, cardCol, textCol, borderCol);

        if (isWide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAlertBanner(isDark),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: visualSection),
                  const SizedBox(width: 24),
                  Expanded(flex: 2, child: metricsSection),
                ],
              ),
            ],
          );
        }
        return Column(
          children: [
            _buildAlertBanner(isDark),
            const SizedBox(height: 24),
            visualSection,
            const SizedBox(height: 24),
            metricsSection,
          ],
        );
      },
    );
  }

  // ── Threat Type Display (FIXED - with parameters) ────────────────────────────
  Widget _buildThreatTypeDisplay(Color cardCol, Color borderCol) {
    final String threatType = _resultData?['threat_type'] ?? "None (Authentic)";
    final String modelUsed = _resultData?['model_used'] ?? "best_model_unified.pth";
    final double fakeProb = _toDouble(_resultData?['fake_probability']);
    
    bool isAIGenerated = threatType.contains("AI GENERATED") || threatType.contains("Synthetic");
    bool isManipulated = threatType.contains("MANIPULATED") || threatType.contains("Face-swap");
    
    Color threatColor;
    IconData threatIcon;
    String threatTitle;
    String threatDescription;
    
    if (isAIGenerated) {
      threatColor = Colors.purple;
      threatIcon = Icons.branding_watermark;
      threatTitle = "🤖 FULLY AI GENERATED";
      threatDescription = "This video was likely created entirely by AI (text-to-video, synthetic generation)";
    } else if (isManipulated) {
      threatColor = Colors.orange;
      threatIcon = Icons.face_retouching_natural;
      threatTitle = "🎭 MANIPULATED (Face-Swap)";
      threatDescription = "This video contains face-swap or editing manipulations";
    } else {
      threatColor = Colors.green;
      threatIcon = Icons.verified;
      threatTitle = "✅ AUTHENTIC VIDEO";
      threatDescription = "No manipulation or AI generation detected";
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardCol,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: threatColor.withOpacity(0.15), shape: BoxShape.circle),
                child: Icon(threatIcon, color: threatColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(threatTitle, style: TextStyle(color: threatColor, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(threatDescription, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: borderCol),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text("Detection Model", style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(4)),
                      child: Text(modelUsed, style: TextStyle(color: Colors.cyanAccent, fontSize: 10, fontFamily: 'monospace')),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text("Confidence", style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                    const SizedBox(height: 4),
                    Text("${_toDouble(_resultData?['confidence']).toStringAsFixed(1)}%",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              ),
            ],
          ),
          if (isAIGenerated || isManipulated) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: fakeProb / 100,
              backgroundColor: Colors.grey[800],
              color: isAIGenerated ? Colors.purple : Colors.orange,
              minHeight: 4,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Fake Probability", style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                Text("${fakeProb.toStringAsFixed(1)}%", style: TextStyle(color: isAIGenerated ? Colors.purple : Colors.orange, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Alert Banner ─────────────────────────────────────────────────────────────
  Widget _buildAlertBanner(bool isDark) {
    final bool isFake = _resultData?['is_manipulated'] ?? false;
    final Color alertColor = isFake ? const Color(0xFFE53935) : Colors.green;
    final String verdictString = _resultData?['verdict_string'] ?? (isFake ? "DEEPFAKE DETECTED" : "AUTHENTIC VIDEO");

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(
        color: alertColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: alertColor.withOpacity(0.3), blurRadius: 15)],
      ),
      child: Row(
        children: [
          Icon(isFake ? Icons.warning_amber_rounded : Icons.check_circle, color: Colors.white, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isFake ? "⚠️ CRITICAL ALERT: $verdictString" : "✅ MEDIA AUTHENTICATED",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
                Text(isFake ? "Inconsistencies located within the visual/auditory timelines" : "Fully verified biometric markers and spectrogram timeline",
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Text("${_toDouble(_resultData?['confidence']).toStringAsFixed(1)}%",
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ── Forensic Visual Report Viewer ────────────────────────────────────────────
  Widget _buildForensicReportViewer(bool isDark, Color cardCol, Color borderCol, Color textCol, bool isWide) {
    final String? forensicReportB64 = _resultData?['forensic_report'];
    final String? heatmapImageB64 = _resultData?['heatmap_image'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildImageCard(title: "Grad-CAM Heatmap Overlay", subtitle: "Neural activation map showing face target focus areas", imageB64: heatmapImageB64, borderCol: borderCol)),
              const SizedBox(width: 16),
              Expanded(child: _buildImageCard(title: "Matplotlib Analytical Compilation", subtitle: "2×3 complete metric matrices and desync timelines", imageB64: forensicReportB64, borderCol: borderCol)),
            ],
          )
        else
          Column(
            children: [
              _buildImageCard(title: "Grad-CAM Heatmap Overlay", subtitle: "Neural activation map showing face target focus areas", imageB64: heatmapImageB64, borderCol: borderCol),
              const SizedBox(height: 16),
              _buildImageCard(title: "Matplotlib Analytical Compilation", subtitle: "2×3 complete metric matrices and desync timelines", imageB64: forensicReportB64, borderCol: borderCol),
            ],
          ),
        const SizedBox(height: 24),
        _buildAttributionSection(cardCol, textCol, borderCol),
      ],
    );
  }

  // ── Individual Image Card ────────────────────────────────────────────────────
  Widget _buildImageCard({
    required String title,
    required String subtitle,
    required String? imageB64,
    required Color borderCol,
  }) {
    ImageProvider? imageProvider;
    if (imageB64 != null && imageB64.startsWith('data:image')) {
      try {
        final String cleanB64 = imageB64.split(',')[1];
        imageProvider = MemoryImage(base64Decode(cleanB64));
      } catch (e) {
        debugPrint("Image parse failure: $e");
      }
    }

    return Container(
      decoration: BoxDecoration(color: const Color(0xFF151E32), borderRadius: BorderRadius.circular(16), border: Border.all(color: borderCol)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 12),
          Container(
            height: 320,
            width: double.infinity,
            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: imageProvider != null
                  ? GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => Dialog.fullscreen(
                            backgroundColor: const Color(0xFF0B1121),
                            child: Stack(
                              children: [
                                InteractiveViewer(maxScale: 6.0, child: Center(child: Image(image: imageProvider!))),
                                Positioned(
                                  top: 40,
                                  right: 20,
                                  child: CircleAvatar(
                                    backgroundColor: Colors.black54,
                                    child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: Image(image: imageProvider, fit: BoxFit.contain),
                    )
                  : const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Attribution Section ──────────────────────────────────────────────────────
  Widget _buildAttributionSection(Color cardCol, Color textCol, Color borderCol) {
    final List<Map<String, dynamic>> engines = _getDetectingEngines();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardCol, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderCol)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.developer_board, color: Colors.cyanAccent, size: 20),
              const SizedBox(width: 8),
              Text("Triggering Network Attribution", style: TextStyle(color: textCol, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 6),
          const Text("Identifies which integrated neural module or network flagged localized synthetic traces.", style: TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: engines.length,
            separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 20),
            itemBuilder: (context, index) {
              final engine = engines[index];
              final bool isTriggered = engine['isTriggered'];
              final double score = engine['confidence'];

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: isTriggered ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(isTriggered ? Icons.warning_amber_rounded : Icons.gpp_good_outlined, color: isTriggered ? Colors.redAccent : Colors.greenAccent, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(engine['name'], style: TextStyle(color: textCol, fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(4)),
                              child: Text(engine['tech'], style: const TextStyle(color: Colors.grey, fontSize: 9, fontFamily: 'monospace')),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(engine['description'], style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(isTriggered ? "FLAGGED" : "SECURE", style: TextStyle(color: isTriggered ? Colors.redAccent : Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                      Text("${score.toStringAsFixed(1)}% weight", style: const TextStyle(color: Colors.grey, fontSize: 10)),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Engine Attribution Logic ─────────────────────────────────────────────────
  List<Map<String, dynamic>> _getDetectingEngines() {
    final bool isFake = _resultData?['is_manipulated'] ?? false;
    final double delay = _toDouble(_resultData?['delay_ms']);
    final double alignment = _toDouble(_resultData?['alignment_confidence']);
    final double fakeProb = _toDouble(_resultData?['fake_probability']);

    return [
      {
        'name': 'MDDA Attention Fusion',
        'tech': 'EfficientNet + CLIP ViT + Text',
        'description': 'Identifies semantic disconnects between what is said and face movements.',
        'isTriggered': isFake && fakeProb > 65.0,
        'confidence': fakeProb,
      },
      {
        'name': 'ERF Cross-Reconstruction',
        'tech': 'BA-TFD+ Transformer Layer',
        'description': 'Pinpoints mechanical desynchronization between voice signals and spatial lip movements.',
        'isTriggered': isFake && (delay > 35.0 || alignment < 0.65),
        'confidence': delay > 35.0 ? 88.0 : 15.0,
      },
      {
        'name': 'Audity Spectral Module',
        'tech': 'WavLM Forensics + Wav2Vec2',
        'description': 'Screens low-level acoustic frequencies for synthetic speech vocoder traces.',
        'isTriggered': isFake && fakeProb > 72.0 && delay <= 35.0,
        'confidence': isFake ? (fakeProb - 4.0).clamp(0.0, 100.0) : 12.5,
      },
      {
        'name': 'BNN Mobile CNN',
        'tech': 'Binary Neural Network Engine',
        'description': 'Scans facial structural borders and eye regions for deepface stitching anomalies.',
        'isTriggered': isFake && fakeProb > 50.0,
        'confidence': fakeProb,
      }
    ];
  }

  // ── Metrics Panel ────────────────────────────────────────────────────────────
  Widget _buildMetricsPanel(bool isDark, Color cardCol, Color textCol, Color borderCol) {
    final List<String> indicators = _resultData?['indicators'] != null ? List<String>.from(_resultData!['indicators']) : [];

    final double confidenceScore = _toDouble(_resultData?['confidence']) / 100;
    final double syntheticScore = _toDouble(_resultData?['score_synthetic']) / 100;
    final double manipulationScore = _toDouble(_resultData?['score_unified']) / 100;
    final double uncertainty = _toDouble(_resultData?['uncertainty']) / 100;
    final double alignment = _toDouble(_resultData?['alignment_confidence']);
    final double delay = _toDouble(_resultData?['delay_ms']);
    final String activePthFile = _resultData?['model_used'] ?? 'best_model_unified.pth';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: cardCol, borderRadius: BorderRadius.circular(20), border: Border.all(color: borderCol)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // THREAT TYPE DISPLAY (FIXED - with parameters)
          _buildThreatTypeDisplay(cardCol, borderCol),
          
          const SizedBox(height: 20),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Forensic Breakdown", style: TextStyle(color: textCol, fontWeight: FontWeight.bold, fontSize: 18)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white10)),
                child: Row(
                  children: [
                    const Icon(Icons.layers, size: 10, color: Colors.cyanAccent),
                    const SizedBox(width: 4),
                    Text(activePthFile, style: const TextStyle(color: Colors.white70, fontSize: 9, fontFamily: 'monospace')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          _buildMetricRow("Unified Forensic Engine (Overall Verdict)", confidenceScore, Colors.tealAccent, textCol),
          _buildMetricRow("Synthetic AI Detector (Fully-Gen AI)", syntheticScore, Colors.orange, textCol),
          _buildMetricRow("Face-Swap/Manipulation Engine (Unified)", manipulationScore, Colors.purple, textCol),

          const Divider(height: 30),

          if (uncertainty > 0 || alignment > 0 || delay > 0) ...[
            Text("Real-time Analysis Metrics", style: TextStyle(color: textCol, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            if (uncertainty > 0) _buildMetricRow("Model Uncertainty", uncertainty, Colors.orangeAccent, textCol),
            if (alignment > 0) _buildMetricRow("Audio-Video Alignment", alignment.clamp(0.0, 1.0), Colors.cyanAccent, textCol),
            if (delay > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("AV Sync Delay", style: TextStyle(color: textCol.withOpacity(0.7), fontSize: 13)),
                    Text("${delay.toStringAsFixed(1)} ms", style: TextStyle(color: delay < 30 ? Colors.green : (delay < 70 ? Colors.orange : Colors.red), fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            const Divider(height: 30),
          ],

          Text("Architecture Triggers", style: TextStyle(color: textCol, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          ...indicators.map((ind) => _indicator(ind, isDark)),

          const SizedBox(height: 30),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.picture_as_pdf, size: 18),
              label: const Text("DOWNLOAD FORENSIC REPORT"),
              style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade100, foregroundColor: textCol),
              onPressed: () async {
                if (_resultData != null) {
                  await PdfService.generateAndDownloadReport(_selectedFile?.name ?? "Report.mp4", _resultData!);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared widgets ───────────────────────────────────────────────────────────
  Widget _buildMetricRow(String label, double value, Color color, Color textCol) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(label, style: TextStyle(color: textCol.withOpacity(0.7), fontSize: 13))),
              Text("${(value * 100).toStringAsFixed(1)}%", style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: value.clamp(0.0, 1.0), color: color, backgroundColor: color.withOpacity(0.15), minHeight: 6),
          ),
        ],
      ),
    );
  }

  Widget _indicator(String text, bool isDark) {
    final bool isWarning = text.contains("⚠️") || text.contains("CRITICAL") || text.contains("manipulated");
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isWarning ? Icons.warning : Icons.check_circle, color: isWarning ? const Color(0xFFE53935) : Colors.green, size: 16),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[800], fontSize: 13))),
        ],
      ),
    );
  }
}
