import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../providers/app_state.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _textCtrl = TextEditingController();
  
  // State
  bool _isAnalyzing = false;
  Map<String, dynamic>? _analysisResult;
  int _detectionsRemaining = 5;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  // --- LOGIC: Text Analysis ---
  Future<void> _runAnalysis() async {
    if (_detectionsRemaining <= 0) {
      _showSignUpDialog();
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _analysisResult = null;
    });

    await Future.delayed(const Duration(seconds: 2));

    try {
      // Use 127.0.0.1 for Web, 10.0.2.2 for Emulator
      var url = Uri.parse('http://127.0.0.1:8000/api/scan-text'); 
      
      if (_textCtrl.text.isEmpty) {
         _mockResult(); 
      } else {
        var response = await http.post(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"text": _textCtrl.text}),
        );

        if (response.statusCode == 200) {
          setState(() {
            _analysisResult = jsonDecode(response.body);
            _detectionsRemaining--;
          });
        } else {
          _mockResult();
        }
      }
    } catch (e) {
      _mockResult();
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  void _mockResult() {
    setState(() {
      _analysisResult = {
        "isScam": true,
        "confidence": 98.2,
        "risk_score": 85,
        "language": "English",
        "scam_category": ["Phishing", "Urgency"],
        "indicators": ["Suspicious Link", "Urgency Keywords"]
      };
      _detectionsRemaining--;
    });
  }

  void _showSignUpDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Free Limit Reached"),
        content: const Text("You have used your 5 free detections. Please sign up to continue."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Close")),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/auth'),
            child: const Text("Sign Up Free"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = appState.isDarkMode;

    // Colors
    Color bg = isDark ? const Color(0xFF0B1121) : const Color(0xFFF8FAFC);
    Color textMain = isDark ? Colors.white : const Color(0xFF1E293B);
    Color textSub = isDark ? Colors.grey : Colors.grey[700]!;
    Color accent = const Color(0xFF3B82F6); 

    return Scaffold(
      backgroundColor: bg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive Flag
          bool isMobile = constraints.maxWidth < 900;

          return Stack(
            children: [
              if (isDark)
                Positioned.fill(
                  child: CustomPaint(painter: CircuitBoardPainter(color: Colors.white.withOpacity(0.03))),
                ),

              SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 0),
                  child: Column(
                    children: [
                      // 1. NAVBAR
                      _buildNavbar(context, isDark, appState, isMobile),

                      SizedBox(height: isMobile ? 40 : 60),

                      // 2. HERO SECTION
                      Column(
                        children: [
                          Text(
                            "Detect. Verify. Trust.", 
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isMobile ? 36 : 56, // Responsive Font
                              fontWeight: FontWeight.w900, 
                              color: textMain, 
                              letterSpacing: -1
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Multimodal Deepfake & Scam Detection.", 
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: isMobile ? 16 : 20, color: textSub),
                          ),
                          const SizedBox(height: 30),
                          Container(
                            decoration: BoxDecoration(
                              boxShadow: isDark ? [BoxShadow(color: accent.withOpacity(0.5), blurRadius: 30, spreadRadius: 1)] : [],
                            ),
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.video_camera_front, color: Colors.white),
                              label: const Text("Try Now - No Sign Up", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                                padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 32, vertical: 20),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              ),
                              onPressed: () {}, // Scroll logic
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: isMobile ? 40 : 60),

                      // 3. HOW IT WORKS (Responsive Row/Column)
                      isMobile 
                        ? Column(
                            children: [
                              _buildStepCard("1", "Drag & Drop", "Upload media or paste text.", isDark, isMobile),
                              const SizedBox(height: 16),
                              _buildStepCard("2", "AI Analysis", "Multimodal engine scans anomalies.", isDark, isMobile),
                              const SizedBox(height: 16),
                              _buildStepCard("3", "Get Results", "Receive detailed forensic report.", isDark, isMobile),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildStepCard("1", "Drag & Drop", "Upload media or paste text.", isDark, isMobile),
                              _buildStepCard("2", "AI Analysis", "Multimodal engine scans anomalies.", isDark, isMobile),
                              _buildStepCard("3", "Get Results", "Receive detailed forensic report.", isDark, isMobile),
                            ],
                          ),

                      SizedBox(height: isMobile ? 40 : 60),

                      // 4. FREE TRIAL WIDGET
                      _buildTrialWidget(isDark, textMain, isMobile),

                      const SizedBox(height: 40),

                      // 5. RESULTS
                      if (_analysisResult != null)
                        _buildResultCard(isDark, textMain, isMobile),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  // --- RESPONSIVE WIDGET COMPONENTS ---

  Widget _buildNavbar(BuildContext context, bool isDark, AppState appState, bool isMobile) {
    Color textCol = isDark ? Colors.white : Colors.black87;
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 0 : 40, vertical: 24),
      child: isMobile 
      ? Column(
          children: [
            // Mobile: Logo Centered
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/logo.png', height: 30, errorBuilder: (c,e,s)=>Icon(Icons.shield, color: Colors.blue)),
                const SizedBox(width: 10),
                Text("QDFX", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textCol)),
              ],
            ),
            const SizedBox(height: 16),
            // Mobile: Buttons Row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: textCol),
                  onPressed: () => appState.toggleTheme(),
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/auth'),
                  child: Text("LOGIN", style: TextStyle(color: textCol)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/auth'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
                  ),
                  child: const Text("SIGN UP", style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ],
            )
          ],
        )
      : Row( // Desktop: Full Navbar
          children: [
            Image.asset('assets/logo.png', height: 35, errorBuilder: (c,e,s)=>Icon(Icons.shield, color: Colors.blue)),
            const SizedBox(width: 10),
            Text("QDFX", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textCol)),
            const Spacer(),
           /* _navLink("Product", textCol),
            _navLink("Learn", textCol),
            _navLink("Pricing", textCol),*/
            const SizedBox(width: 20),
            IconButton(
              icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: textCol),
              onPressed: () => appState.toggleTheme(),
            ),
            const SizedBox(width: 20),
            OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, '/auth'),
              style: OutlinedButton.styleFrom(side: BorderSide(color: textCol.withOpacity(0.3))),
              child: Text("LOGIN", style: TextStyle(color: textCol)),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/auth'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
              child: const Text("SIGN UP", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
    );
  }

  Widget _navLink(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildStepCard(String number, String title, String subtitle, bool isDark, bool isMobile) {
    return Container(
      width: isMobile ? double.infinity : 220, // Full width on mobile
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151E32) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF00D2D3).withOpacity(0.3) : Colors.grey.shade200),
        boxShadow: isDark 
          ? [BoxShadow(color: const Color(0xFF00D2D3).withOpacity(0.1), blurRadius: 15)] 
          : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Text(number, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF00D2D3))),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 8),
          Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey : Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildTrialWidget(bool isDark, Color textMain, bool isMobile) {
    return Center(
      child: Container(
        width: 800, // Maximum width
        constraints: const BoxConstraints(maxWidth: 800), // Responsive constraint
        child: Column(
          children: [
            // Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF00D2D3),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                boxShadow: [BoxShadow(color: const Color(0xFF00D2D3).withOpacity(0.4), blurRadius: 15)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bar_chart, color: Colors.black87, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text("REMAINING: $_detectionsRemaining/5 FREE", 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
                  ),
                ],
              ),
            ),
            
            // Main Card
            Container(
              height: 400,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF151E32) : Colors.white,
                borderRadius: BorderRadius.circular(24),
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
                      Tab(icon: Icon(Icons.folder), text: "Video/Image"),
                      Tab(icon: Icon(Icons.text_fields), text: "Paste Text"),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildDragDropZone(isDark),
                        _buildTextScanner(isDark, textMain),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDragDropZone(bool isDark) {
    return Center(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_upload_outlined, size: 48, color: const Color(0xFF3B82F6).withOpacity(0.8)),
            const SizedBox(height: 16),
            Text("Drag and drop media", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text("MP4, JPG, PNG, max 100MB", style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
              child: const Text("BROWSE FILES", style: TextStyle(color: Colors.white, fontSize: 10)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTextScanner(bool isDark, Color textCol) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Expanded(
            child: TextField(
              controller: _textCtrl,
              maxLines: 10,
              style: TextStyle(color: textCol),
              decoration: InputDecoration(
                hintText: "Paste suspicious text here to analyze...",
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
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isAnalyzing ? null : _runAnalysis,
              child: _isAnalyzing 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                : const Text("ANALYZE TEXT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildResultCard(bool isDark, Color textCol, bool isMobile) {
    bool isScam = _analysisResult!['isScam'];
    Color statusColor = isScam ? const Color(0xFFE53935) : const Color(0xFF00C853);

    return Container(
      width: 800,
      constraints: const BoxConstraints(maxWidth: 800),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151E32) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.5), width: 2),
        boxShadow: [BoxShadow(color: statusColor.withOpacity(0.1), blurRadius: 30)],
      ),
      // Responsive Switch: Column on Mobile, Row on Desktop
      child: isMobile 
        ? Column(
            children: [
              _buildResultDetails(isScam, statusColor, textCol),
              const SizedBox(height: 20),
              Container(height: 1, color: Colors.grey.withOpacity(0.2)),
              const SizedBox(height: 20),
              _buildResultVisuals(),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _buildResultDetails(isScam, statusColor, textCol)),
              Container(width: 1, height: 150, color: Colors.grey.withOpacity(0.2), margin: const EdgeInsets.symmetric(horizontal: 24)),
              Expanded(flex: 1, child: _buildResultVisuals()),
            ],
          ),
    );
  }

  Widget _buildResultDetails(bool isScam, Color statusColor, Color textCol) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(isScam ? Icons.warning_amber_rounded : Icons.check_circle, color: statusColor, size: 28),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                isScam ? "SCAM DETECTED" : "MESSAGE SAFE",
                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text("Confidence Score: ${_analysisResult!['confidence']}%", style: TextStyle(color: textCol, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text("Risk Level: ${_analysisResult!['risk_score']}/100", style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: (_analysisResult!['indicators'] as List).map<Widget>((i) => Chip(
            label: Text(i, style: const TextStyle(fontSize: 10, color: Colors.white)),
            backgroundColor: statusColor.withOpacity(0.8),
            padding: EdgeInsets.zero,
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildResultVisuals() {
    return Column(
      children: [
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            image: const DecorationImage(image: AssetImage('assets/logo.png'), opacity: 0.5)
          ),
          child: Center(child: Icon(Icons.analytics, color: Colors.white.withOpacity(0.5), size: 40)),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.download, size: 14),
          label: const Text("Download Report", style: TextStyle(fontSize: 12)),
          onPressed: () {},
        )
      ],
    );
  }
}

class CircuitBoardPainter extends CustomPainter {
  final Color color; CircuitBoardPainter({this.color = Colors.white10});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1.5..style = PaintingStyle.stroke;
    final dotPaint = Paint()..color = color.withOpacity(0.2)..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(0, size.height * 0.2); path.lineTo(size.width * 0.2, size.height * 0.2);
    path.lineTo(size.width * 0.3, size.height * 0.3);
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.3), 4, dotPaint);
    path.moveTo(size.width, size.height * 0.7); path.lineTo(size.width * 0.8, size.height * 0.7);
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}