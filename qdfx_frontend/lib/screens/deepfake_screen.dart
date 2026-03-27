import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';

class DeepfakeScreen extends StatefulWidget {
  const DeepfakeScreen({super.key});

  @override
  State<DeepfakeScreen> createState() => _DeepfakeScreenState();
}

class _DeepfakeScreenState extends State<DeepfakeScreen> {
  // State Machine: 0 = Upload, 1 = Analyzing, 2 = Result
  int _currentState = 0;
  bool _showHeatmap = true; // Toggle for video player overlay

  // --- LOGIC: START SCAN ---
  void _startAnalysis(AppState appState) async {
    // 1. Check Credits again (Security)
    if (appState.credits <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Insufficient credits. Please upgrade."), backgroundColor: Colors.red),
      );
      return;
    }
    
    // 2. Consume Credit
    appState.deductCredit(); 

    // 3. Start Simulation
    setState(() => _currentState = 1); // Switch to Loading
    
    // Simulate heavy AI processing (3 seconds)
    await Future.delayed(const Duration(seconds: 3)); 
    
    setState(() => _currentState = 2); // Switch to Result
  }

  // --- LOGIC: RESET ---
  void _reset() {
    setState(() => _currentState = 0);
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = appState.isDarkMode;
    
    // Professional Color Palette
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
            // -------------------------------------------------------
            // HEADER SECTION (Title + Credit Counter)
            // -------------------------------------------------------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Deepfake Forensics", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textCol)),
                    Row(
                      children: [
                        Text("Multimodal Analysis Engine v2.1  •  ", style: TextStyle(color: Colors.grey, fontSize: 12)),
                        Text(
                          "Credits: ${appState.credits}", 
                          style: TextStyle(
                            color: appState.canUpload ? Colors.green : Colors.red, 
                            fontWeight: FontWeight.bold,
                            fontSize: 12
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Show "New Scan" button only if we are viewing a result
                if (_currentState == 2)
                  OutlinedButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text("New Scan"),
                    style: OutlinedButton.styleFrom(foregroundColor: textCol, side: BorderSide(color: borderCol)),
                  )
              ],
            ),
            const SizedBox(height: 30),

            // -------------------------------------------------------
            // MAIN CONTENT SWITCHER
            // -------------------------------------------------------
            // 1. If No Credits -> Show Paywall
            if (!appState.canUpload) 
              _buildPaywall(isDark, cardCol, textCol, appState)
            
            // 2. If Has Credits & State is 0 -> Show Upload
            else if (_currentState == 0) 
              _buildUploadArea(isDark, textCol, appState)
            
            // 3. If State is 1 -> Show Loading
            else if (_currentState == 1) 
              _buildLoadingState(isDark, textCol)
            
            // 4. If State is 2 -> Show Results
            else 
              _buildResultDashboard(isDark, cardCol, textCol, borderCol),
          ],
        ),
      ),
    );
  }

  // =================================================================
  // WIDGET: PAYWALL (Shown when credits == 0)
  // =================================================================
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
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              shape: BoxShape.circle
            ),
            child: const Icon(Icons.lock_outline, size: 60, color: Colors.redAccent),
          ),
          const SizedBox(height: 24),
          Text("Subscription Required", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textCol)),
          const SizedBox(height: 12),
          const Text(
            "You have used your free welcome credits.\nUpgrade to a Professional plan to continue analyzing videos.",
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 10,
              shadowColor: AppTheme.primaryBlue.withOpacity(0.4)
            ),
            onPressed: () {
              // Redirect to Billing Tab (Index 1)
              appState.setIndex(1); 
            },
          )
        ],
      ),
    );
  }

  // =================================================================
  // WIDGET: UPLOAD AREA (Drag & Drop Look)
  // =================================================================
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
              height: 300,
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
                    child: const Icon(Icons.cloud_upload_outlined, size: 60, color: AppTheme.primaryBlue),
                  ),
                  const SizedBox(height: 24),
                  Text("Drag & Drop Video Evidence", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textCol)),
                  const SizedBox(height: 8),
                  const Text("Supported formats: MP4, MOV, AVI (Max 500MB)", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => _startAnalysis(appState),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("BROWSE FILES (-1 Credit)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =================================================================
  // WIDGET: LOADING STATE (Spinner)
  // =================================================================
  Widget _buildLoadingState(bool isDark, Color textCol) {
    return SizedBox(
      height: 500,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 60, height: 60,
              child: CircularProgressIndicator(color: AppTheme.primaryBlue, strokeWidth: 4),
            ),
            const SizedBox(height: 24),
            Text("Extracting Frames & Audio...", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textCol)),
            const SizedBox(height: 8),
            const Text("Running ResNet + LSTM Analysis", style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // =================================================================
  // WIDGET: RESULT DASHBOARD (The "Command Center")
  // =================================================================
  Widget _buildResultDashboard(bool isDark, Color cardCol, Color textCol, Color borderCol) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isWide = constraints.maxWidth > 900;
        
        // Sections
        Widget videoSection = _buildVideoPlayer(isDark, cardCol, borderCol);
        Widget metricsSection = _buildMetricsPanel(isDark, cardCol, textCol, borderCol);

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: videoSection),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: metricsSection),
            ],
          );
        } else {
          return Column(
            children: [
              videoSection,
              const SizedBox(height: 24),
              metricsSection,
            ],
          );
        }
      },
    );
  }

  Widget _buildVideoPlayer(bool isDark, Color cardCol, Color borderCol) {
    return Column(
      children: [
        // 1. ALERT BANNER
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFE53935), // Red
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: const Color(0xFFE53935).withOpacity(0.4), blurRadius: 20)]
          ),
          child: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("CRITICAL ALERT: DEEPFAKE DETECTED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  Text("Manipulation Type: Face Swap + Lip Sync Error", style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
              Spacer(),
              Text("98.4%", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 2. VIDEO PLAYER UI
        Container(
          height: 450,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderCol),
            image: const DecorationImage(
              image: AssetImage('assets/logo.png'), // Placeholder - Uses logo if no video frame available
              opacity: 0.2,
              fit: BoxFit.contain,
            )
          ),
          child: Stack(
            children: [
              // Heatmap Overlay
              if (_showHeatmap)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: RadialGradient(
                      colors: [Colors.red.withOpacity(0.6), Colors.transparent],
                      center: const Alignment(0.0, -0.2), // Focus on center-top (Face)
                      radius: 0.4,
                    ),
                  ),
                ),
              
              // Video Controls Overlay (Fake)
              Positioned(
                bottom: 20, left: 20, right: 20,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24)
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.play_arrow, color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey,
                            borderRadius: BorderRadius.circular(2)
                          ),
                          child: Row(
                            children: [
                              Container(width: 100, color: Colors.green), // Real part
                              Container(width: 40, color: Colors.red),    // Fake part (Timeline)
                              Container(width: 60, color: Colors.green),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text("00:12 / 00:45", style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ),

              // Heatmap Toggle Button
              Positioned(
                top: 20, right: 20,
                child: GestureDetector(
                  onTap: () => setState(() => _showHeatmap = !_showHeatmap),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _showHeatmap ? AppTheme.primaryBlue : Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24)
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.layers, size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(_showHeatmap ? "Heatmap: ON" : "Heatmap: OFF", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsPanel(bool isDark, Color cardCol, Color textCol, Color borderCol) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardCol,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Forensic Breakdown", style: TextStyle(color: textCol, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 24),
          
          _buildMetricRow("Visual Artifacts", 0.94, Colors.red, textCol),
          _buildMetricRow("Audio Consistency", 0.45, Colors.orange, textCol),
          _buildMetricRow("Metadata Integrity", 0.10, Colors.green, textCol),
          
          const Divider(height: 40),
          
          Text("Key Indicators", style: TextStyle(color: textCol, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          _indicator("Irregular eye blinking detected (0.2Hz)", isDark),
          _indicator("Lip-sync mismatch > 150ms", isDark),
          _indicator("Background warping around facial borders", isDark),
          
          const SizedBox(height: 30),
          
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.download, size: 18),
              label: const Text("DOWNLOAD PDF REPORT"),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade100,
                foregroundColor: textCol,
                elevation: 0,
                side: BorderSide(color: borderCol)
              ),
              onPressed: () {},
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, double value, Color color, Color textCol) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: textCol.withOpacity(0.7), fontSize: 13)),
              Text("${(value * 100).toInt()}%", style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value, 
              color: color, 
              backgroundColor: color.withOpacity(0.15),
              minHeight: 6,
            ),
          )
        ],
      ),
    );
  }

  Widget _indicator(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFFE53935), size: 16),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[800], fontSize: 13))),
        ],
      ),
    );
  }
}