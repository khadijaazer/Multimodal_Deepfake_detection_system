import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../services/scam_detection_service.dart';

class ScamDetectionScreen extends StatefulWidget {
  const ScamDetectionScreen({super.key});

  @override
  State<ScamDetectionScreen> createState() => _ScamDetectionScreenState();
}

class _ScamDetectionScreenState extends State<ScamDetectionScreen> {
  final TextEditingController _textCtrl = TextEditingController();
  bool _isAnalyzing = false;
  bool _isServerConnected = true;
  Map<String, dynamic>? _result;
  
  final ScamDetectionService _apiService = ScamDetectionService();

  @override
  void initState() {
    super.initState();
    _checkServerConnection();
  }

  Future<void> _checkServerConnection() async {
    final isConnected = await _apiService.checkHealth();
    if (mounted) {
      setState(() {
        _isServerConnected = isConnected;
      });
    }
  }

  Future<void> _analyzeText() async {
    if (_textCtrl.text.isEmpty) {
      _showErrorDialog('Please enter some text to analyze');
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _result = null;
    });

    try {
      if (!_isServerConnected) {
        final isConnected = await _apiService.checkHealth();
        if (!isConnected) {
          throw Exception('Server is not running. Please start the Python server.');
        }
        setState(() {
          _isServerConnected = true;
        });
      }

      final result = await _apiService.analyzeText(_textCtrl.text);
      
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _result = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _isServerConnected = false;
        });
        
        _showErrorDialog(
          'Failed to analyze text: ${e.toString()}\n\n'
          'Make sure your Python server is running at ${ScamDetectionService.baseUrl}'
        );
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _checkServerConnection();
            },
            child: const Text('Retry Connection'),
          ),
        ],
      ),
    );
  }

  Color _getThreatLevelColor(String level) {
    switch (level) {
      case 'CRITICAL':
        return const Color(0xFF7B1FA2);
      case 'HIGH':
        return const Color(0xFFC62828);
      case 'MEDIUM':
        return const Color(0xFFEF6C00);
      case 'LOW':
        return const Color(0xFF2E7D32);
      default:
        return Colors.grey;
    }
  }

  IconData _getThreatLevelIcon(String level) {
    switch (level) {
      case 'CRITICAL':
        return Icons.warning_amber_rounded;
      case 'HIGH':
        return Icons.error_outline;
      case 'MEDIUM':
        return Icons.warning;
      case 'LOW':
        return Icons.check_circle_outline;
      default:
        return Icons.help_outline;
    }
  }

  String _getThreatLevelText(String level) {
    switch (level) {
      case 'CRITICAL':
        return 'CRITICAL THREAT';
      case 'HIGH':
        return 'HIGH RISK';
      case 'MEDIUM':
        return 'MEDIUM RISK';
      case 'LOW':
        return 'LOW RISK';
      default:
        return 'UNKNOWN';
    }
  }

  Widget _buildInfoChip(String label, String value, Color color, {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: color.withOpacity(0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = appState.isDarkMode;

    Color bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    Color textMain = isDark ? Colors.white : Colors.black87;
    Color borderColor = isDark ? Colors.white10 : Colors.grey.shade300;

    return Scaffold(
      backgroundColor: bg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "Multilingual Scam & Spam Detection", 
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textMain),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isServerConnected 
                        ? Colors.green.withOpacity(0.2) 
                        : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isServerConnected ? Colors.green : Colors.red,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isServerConnected ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isServerConnected ? 'Server Online' : 'Server Offline',
                        style: TextStyle(
                          fontSize: 10,
                          color: _isServerConnected ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Detect fraudulent messages in 41 languages using advanced AI", 
              style: TextStyle(color: isDark ? Colors.grey : Colors.grey[700]),
            ),
            
            const SizedBox(height: 30),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Paste suspicious message here...", 
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                      if (!_isServerConnected)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Offline Mode',
                            style: TextStyle(fontSize: 10, color: Colors.orange),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  
                  TextField(
                    controller: _textCtrl,
                    maxLines: 6,
                    style: TextStyle(color: textMain, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: "Ex: Urgent! Your account is compromised...",
                      hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), 
                        borderSide: BorderSide.none
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isServerConnected 
                            ? const Color(0xFF2E86DE)
                            : Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)
                        ),
                        elevation: 5,
                      ),
                      onPressed: (_isAnalyzing || !_isServerConnected) ? null : _analyzeText,
                      child: _isAnalyzing 
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20, 
                                height: 20, 
                                child: CircularProgressIndicator(
                                  color: Colors.white, 
                                  strokeWidth: 2
                                )
                              ),
                              SizedBox(width: 12),
                              Text(
                                "ANALYZING...", 
                                style: TextStyle(
                                  color: Colors.white, 
                                  fontWeight: FontWeight.bold, 
                                  letterSpacing: 1
                                )
                              ),
                            ],
                          )
                        : Text(
                            _isServerConnected ? "ANALYZE MESSAGE" : "SERVER OFFLINE",
                            style: const TextStyle(
                              color: Colors.white, 
                              fontWeight: FontWeight.bold, 
                              letterSpacing: 1
                            )
                          ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            if (_result != null) 
              _buildEnhancedResultCard(_result!, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedResultCard(Map<String, dynamic> result, bool isDark) {
    bool isScam = result['isScam'];
    String threatLevel = result['threat_level'] ?? (isScam ? 'HIGH' : 'LOW');
    Color threatColor = _getThreatLevelColor(threatLevel);
    Color statusColor = isScam ? threatColor : const Color(0xFF00C853);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(color: statusColor.withOpacity(0.15), blurRadius: 30)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getThreatLevelIcon(threatLevel),
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isScam ? _getThreatLevelText(threatLevel) : "SAFE MESSAGE",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (isScam)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.analytics, color: Colors.orange, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Risk: ${result['risk_score']}/100',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _buildInfoChip(
                  'Confidence',
                  '${result['confidence']}%',
                  statusColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildInfoChip(
                  'Language',
                  result['language'],
                  Colors.blue,
                  subtitle: result['language_confidence'] != null
                      ? '${result['language_confidence']}% confidence'
                      : null,
                ),
              ),
            ],
          ),

          if (result['scam_category'] != null && 
              (result['scam_category'] as List).isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Scam Categories:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
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
                  child: Text(
                    category,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          if (result['urls_found'] != null && 
              (result['urls_found'] as List).isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Suspicious URLs:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
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
                child: Text(
                  url,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ],

          const SizedBox(height: 16),
          const Text(
            'Key Indicators:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ...(result['indicators'] as List).map((indicator) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isScam ? Icons.warning_amber : Icons.check_circle,
                    size: 16,
                    color: statusColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      indicator,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[300] : Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),

          if (isScam && result['safety_tips'] != null && 
              (result['safety_tips'] as List).isNotEmpty) ...[
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
                  const Row(
                    children: [
                      Icon(Icons.security, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Safety Tips:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...(result['safety_tips'] as List).map((tip) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(color: Colors.blue)),
                          Expanded(
                            child: Text(
                              tip,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
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
              if (isScam)
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.flag, size: 18),
                    label: const Text("REPORT SCAM"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      _showReportDialog();
                    },
                  ),
                ),
              if (isScam) const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _textCtrl.clear();
                      _result = null;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey,
                    side: const BorderSide(color: Colors.grey),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text("CLEAR"),
                ),
              ),
              if (!isScam) const SizedBox(width: 12),
              if (!isScam)
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text("SHARE RESULT"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      _showShareDialog();
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report Scam'),
        content: const Text('This scam message will be reported to help improve detection for others.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Scam reported successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  void _showShareDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Share Result'),
        content: Text(
          'Analysis Result: ${_result!['isScam'] ? "SCAM" : "SAFE"}\n'
          'Confidence: ${_result!['confidence']}%\n'
          'Language: ${_result!['language']}'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Result copied to clipboard'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Copy to Clipboard'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }
}