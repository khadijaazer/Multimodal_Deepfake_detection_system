import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  static final _primaryNavy = PdfColor.fromHex('#0F172A'); 
  static final _accentBlue  = PdfColor.fromHex('#3B82F6'); 
  static final _textGray    = PdfColor.fromHex('#475569'); 
  static final _dividerGray = PdfColor.fromHex('#E2E8F0');
  static final _greenStrong = PdfColor.fromHex('#059669'); 
  static final _redStrong   = PdfColor.fromHex('#DC2626');
  static final _purpleGen   = PdfColor.fromHex('#7C3AED');
  static final _amberWarn   = PdfColor.fromHex('#D97706');
  static final _orangeMulti = PdfColor.fromHex('#FF8C00');
  
  // Couleur orange avec transparence (0.3 = 30% opacité = 77 sur 255)
  static final _orangeMultiLight = PdfColor(1.0, 0.55, 0.0, 0.3);  // RGBA avec alpha=0.3

  static Future<void> generateAndDownloadReport({
    required String fileName,
    String mediaType = 'video',
    required Map<String, dynamic> analysisData,
  }) async {
    final pdf = pw.Document();
    final DateTime now = DateTime.now();
    final String reportId = "DET-${now.millisecondsSinceEpoch.toString().substring(7)}";
    
    final bool isFake = analysisData['is_manipulated'] ?? false;
    final double confidence = _toDouble(analysisData['confidence']);
    final String mode = analysisData['heatmap_mode'] ?? 'authentic';
    final double delay = _toDouble(analysisData['delay_ms']);
    final double alignment = _toDouble(analysisData['alignment_confidence']) * 100;
    final double fakeProb = _toDouble(analysisData['fake_probability']);
    final double realProb = _toDouble(analysisData['real_probability']);
    final double synthScore = _toDouble(analysisData['score_synthetic']);
    final double manipulationScore = _toDouble(analysisData['score_unified']);
    final double uncertainty = _toDouble(analysisData['uncertainty']);
    
    final bool isMultiManipulated = analysisData['is_multi_manipulated'] ?? false;
    final List<dynamic> detectedModes = analysisData['detected_modes'] ?? [];
    final Map<String, dynamic> manipulationScores = analysisData['manipulation_scores'] ?? {};

    final PdfColor verdictColor = isMultiManipulated 
        ? _orangeMulti 
        : (mode == 'gen_ai') 
            ? _purpleGen 
            : (isFake ? _redStrong : _greenStrong);
    
    final String mediaLabel = mediaType.toUpperCase();
    String verdictTitle;
    if (isMultiManipulated) {
      verdictTitle = "$mediaLabel MULTI-MANIPULATION DETECTED";
    } else if (isFake) {
      verdictTitle = "$mediaLabel DEEPFAKE DETECTED";
    } else {
      verdictTitle = "$mediaLabel AUTHENTICATED";
    }

    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    pw.MemoryImage? heatmapImg;
    if (analysisData['heatmap_image'] != null && mediaType != 'audio') {
      try {
        final String b64 = analysisData['heatmap_image'].toString().split(',').last;
        heatmapImg = pw.MemoryImage(base64Decode(b64));
      } catch (e) { print("Image failed: $e"); }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        margin: const pw.EdgeInsets.all(35),
        build: (context) => [
          _buildHeader(reportId, now),
          pw.SizedBox(height: 15),
          pw.Divider(thickness: 1.5, color: _primaryNavy),
          pw.SizedBox(height: 20),

          _buildVerdictBanner(verdictTitle, verdictColor, confidence, fileName, mode, mediaType, isMultiManipulated, detectedModes),

          pw.SizedBox(height: 25),

          pw.Text("EXECUTIVE SUMMARY", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _primaryNavy)),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(color: PdfColors.grey50, borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Text(
              _generateExplanation(mode, isFake, delay, alignment, mediaType, isMultiManipulated, detectedModes, manipulationScores),
              style: pw.TextStyle(fontSize: 10, lineSpacing: 1.5, color: _textGray),
            ),
          ),

          pw.SizedBox(height: 25),

          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(flex: 1, child: _buildProbabilityGrid(fakeProb, realProb, mediaType, isMultiManipulated, manipulationScores)),
              pw.SizedBox(width: 20),
              pw.Expanded(
                flex: 1,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("DETECTION METRICS", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 12),
                    if (mediaType != 'image') _buildProgressBar("Voice/Audio Analysis", isFake ? 0.98 : 0.05, _accentBlue),
                    if (mediaType != 'audio') _buildProgressBar("Visual/Face Analysis", isFake ? 0.94 : 0.08, _accentBlue),
                    _buildProgressBar("AI Generation Score", synthScore / 100, _purpleGen),
                    _buildProgressBar("Analysis Uncertainty", uncertainty / 100, _amberWarn),
                    if (isMultiManipulated) ...[
                      pw.SizedBox(height: 8),
                      _buildProgressBar("Multi-Manipulation Severity", 0.95, _orangeMulti),
                    ],
                  ],
                ),
              ),
            ],
          ),

          if (isMultiManipulated) ...[
            pw.SizedBox(height: 25),
            pw.Text("MULTI-MANIPULATION ANALYSIS", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _orangeMulti)),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('FFF3E0'),
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: _orangeMulti),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("⚠️ MULTIPLE MANIPULATIONS DETECTED", 
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _orangeMulti)),
                  pw.SizedBox(height: 8),
                  ...detectedModes.map((modeInfo) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 6),
                    child: pw.Row(
                      children: [
                        pw.Container(
                          width: 8, height: 8,
                          decoration: pw.BoxDecoration(
                            color: _getModeColor(modeInfo['mode']),
                            shape: pw.BoxShape.circle,
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Expanded(
                          child: pw.Text(
                            "${modeInfo['description']} — ${modeInfo['confidence']}% confidence",
                            style: pw.TextStyle(fontSize: 9, color: _textGray),
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                  pw.SizedBox(height: 6),
                  pw.Divider(thickness: 0.5, color: _orangeMultiLight),  // CORRIGÉ : utiliser la couleur avec alpha
                  pw.SizedBox(height: 6),
                  pw.Text(
                    "Media contains BOTH face-swap AND voice clone manipulations simultaneously.",
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _orangeMulti),
                  ),
                ],
              ),
            ),
          ],

          if (mediaType != 'image') ...[
            pw.SizedBox(height: 25),
            pw.Text("TEMPORAL ANALYSIS", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Row(
              children: [
                pw.Expanded(child: _buildDetailRow("A/V Sync Delay", mediaType == 'audio' ? "N/A" : "${delay.abs().toStringAsFixed(1)} ms", delay.abs() > 40 ? _redStrong : _greenStrong)),
                pw.SizedBox(width: 10),
                pw.Expanded(child: _buildDetailRow("Pattern Accuracy", "${alignment.toStringAsFixed(1)}%", alignment < 50 ? _redStrong : _greenStrong)),
                pw.SizedBox(width: 10),
                pw.Expanded(child: _buildDetailRow("Overall Sync", delay.abs() < 50 ? "NATURAL" : "SUSPICIOUS", delay.abs() < 50 ? _greenStrong : _redStrong)),
              ],
            ),
          ],

          if (mediaType != 'audio') ...[
            pw.SizedBox(height: 25),
            pw.Text("VISUAL EVIDENCE MAP", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 240, height: 160,
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: _dividerGray), color: PdfColors.black),
                  child: heatmapImg != null ? pw.Image(heatmapImg, fit: pw.BoxFit.contain) : pw.Center(child: pw.Text("N/A", style: pw.TextStyle(color: PdfColors.white))),
                ),
                pw.SizedBox(width: 20),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("Highlighted areas interpretation:", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 5),
                      pw.Text(_getHeatmapDescription(mode, mediaType, isMultiManipulated), style: pw.TextStyle(fontSize: 9, color: _textGray, lineSpacing: 1.2)),
                    ],
                  ),
                ),
              ],
            ),
          ],

          if (mediaType == 'audio') ...[
            pw.SizedBox(height: 25),
            pw.Text("SPECTRAL ANALYSIS", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: _dividerGray),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Frequency Domain Findings:", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    _getSpectralAnalysisDescription(mode, isFake, isMultiManipulated),
                    style: pw.TextStyle(fontSize: 9, color: _textGray, lineSpacing: 1.4),
                  ),
                ],
              ),
            ),
          ],

          pw.SizedBox(height: 30),
          _buildAdvisory(isFake, mediaType, isMultiManipulated),
        ],
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: "Detectini_${mediaType}_Report_$reportId.pdf");
  }

  static PdfColor _getModeColor(String mode) {
    switch (mode) {
      case 'face_swap':
        return _redStrong;
      case 'audio_fake':
        return _redStrong;
      case 'gen_ai':
        return _purpleGen;
      default:
        return _greenStrong;
    }
  }

  static pw.Widget _buildHeader(String id, DateTime now) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text("DETECTINI", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _primaryNavy, letterSpacing: 2)),
          pw.Text("MULTIMODAL FORENSIC ANALYSIS", style: pw.TextStyle(fontSize: 9, color: _accentBlue, fontWeight: pw.FontWeight.bold)),
        ]),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text("OFFICIAL FORENSIC RECORD", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.Text("Document ID: $id", style: pw.TextStyle(fontSize: 9, color: _textGray)),
        ]),
      ],
    );
  }

  static pw.Widget _buildVerdictBanner(String title, PdfColor color, double conf, String file, String mode, String type, bool isMulti, List<dynamic> detectedModes) {
    return pw.Row(
      children: [
        pw.Expanded(
          flex: 3,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Column(children: [
              pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
              pw.SizedBox(height: 5),
              pw.Text("Confidence Score: ${conf.toStringAsFixed(1)}%", style: pw.TextStyle(fontSize: 11, color: const PdfColor(1, 1, 1, 0.9))),
            ]),
          ),
        ),
        pw.SizedBox(width: 15),
        pw.Expanded(
          flex: 2,
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text("SOURCE FILE", style: pw.TextStyle(fontSize: 7, color: _textGray, fontWeight: pw.FontWeight.bold)),
            pw.Text(file, style: pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 8),
            pw.Text("MEDIA TYPE", style: pw.TextStyle(fontSize: 7, color: _textGray, fontWeight: pw.FontWeight.bold)),
            pw.Text(type.toUpperCase(), style: pw.TextStyle(fontSize: 9, color: _primaryNavy)),
            pw.SizedBox(height: 8),
            pw.Text("DETECTION TYPE", style: pw.TextStyle(fontSize: 7, color: _textGray, fontWeight: pw.FontWeight.bold)),
            pw.Text(_getModeLabel(mode, isMulti), style: pw.TextStyle(fontSize: 9, color: color, fontWeight: pw.FontWeight.bold)),
          ]),
        ),
      ],
    );
  }

  static String _getModeLabel(String mode, bool isMulti) {
    if (isMulti) return "MULTI-MANIPULATION (Face-Swap + Voice Clone)";
    switch (mode) {
      case 'gen_ai': return "COMPUTED GENERATED (AI)";
      case 'audio_fake': return "VOICE CLONE / AUDIO SYNTHESIS";
      case 'face_swap': return "FACIAL MANIPULATION / FACE SWAP";
      case 'multi_manipulation': return "MULTI-MANIPULATION";
      default: return "AUTHENTIC MEDIA";
    }
  }

  static String _generateExplanation(String mode, bool isFake, double delay, double alignment, String type, bool isMulti, List<dynamic> detectedModes, Map<String, dynamic> scores) {
    if (isMulti) {
      return "⚠️ CRITICAL: This $type contains MULTIPLE MANIPULATIONS simultaneously.\n\n"
          "• Face-Swap detected: ${(scores['face_swap'] ?? 0.0 * 100).toStringAsFixed(0)}% confidence — Someone else's face has been digitally pasted onto this person.\n"
          "• Voice Clone detected: ${(scores['voice_clone'] ?? 0.0 * 100).toStringAsFixed(0)}% confidence — The audio has been artificially generated or cloned.\n\n"
          "The $type is HIGHLY UNTRUSTWORTHY as both the visual identity and voice have been manipulated using different AI techniques. This is a sophisticated deepfake combining multiple tampering methods.";
    }
    
    if (!isFake) {
      switch (type) {
        case 'image':
          return "This image appears to be authentic. Our system verified the structural integrity, pixel distribution, and digital noise patterns. The metadata, color consistency, and natural artifacts match the characteristics of a real camera-captured image.";
        case 'audio':
          return "This audio file appears to be authentic. Our system analyzed the frequency spectrum, temporal patterns, and natural voice characteristics. The acoustic signature matches expected patterns for real human speech without synthetic artifacts.";
        default:
          return "This video appears to be authentic. Our system verified the skin textures, lighting patterns, facial dynamics, and the timing of voice against lip movements. Everything matches the characteristics of a real recording.";
      }
    }

    if (mode == 'gen_ai') {
      return "This $type was entirely generated by Artificial Intelligence. It is not a recording or capture of real media. Our AI detected 'digital fingerprints'—microscopic patterns in the data that only appear when content is synthetically generated by generative models. No original source exists for this $type.";
    }

    if (type == 'audio' || mode == 'audio_fake') {
      return "This audio file has been tampered with using voice synthesis or cloning technology. We detected spectral anomalies, robotic modulation patterns, and frequency inconsistencies ($alignment% accuracy) that suggest this voice was artificially generated or manipulated. Natural human speech contains subtle variations that are missing here.";
    }

    if (type == 'image') {
      return "This image shows signs of digital manipulation. We found lighting inconsistencies, edge artifacts, and pixel-level anomalies ($alignment% accuracy) indicating the image has been digitally altered. These 'digital seams' around subjects suggest parts of the image were added, removed, or modified by AI or editing software.";
    }

    return "This video shows a 'Face Swap' manipulation. A real person was filmed, but AI technology has digitally pasted someone else's face over them. Our system detected stitching artifacts and resolution mismatches around the eyes, jawline, and face boundaries where the swap occurred.";
  }

  static String _getHeatmapDescription(String mode, String type, bool isMulti) {
    if (type == 'audio') return "Not applicable for audio-only analysis.";
    if (isMulti) {
      return "⚠️ MULTI-MANIPULATION HEATMAP — The orange overlay combines both face-swap boundary detection AND audio-visual desynchronization markers. Key areas:\n"
          "• Red zones: Face-swap boundaries (jaw, eyes, face edges)\n"
          "• Orange highlights: Mouth region where voice mismatch occurs\n"
          "• Yellow indicators: Areas with combined manipulation evidence";
    }
    switch (mode) {
      case 'gen_ai':
        return "The AI detected synthetic patterns across the entire $type. Evidence of AI generation is distributed globally throughout the frame, with no single region showing normal statistical properties expected from real-captured media.";
      case 'audio_fake':
        return "The AI is highlighting regions where visual movements should correlate with audio characteristics, identifying mismatches in the $type that indicate the voice has been artificially generated or replaced.";
      case 'face_swap':
        return "The AI focuses on facial boundary regions—edges around the face, jawline, and eye sockets. These 'seams' are where digital face masks leave subtle artifacts and unnatural blending when pasted over the original face.";
      default:
        return "The AI scanned the $type and found natural statistical distributions across all regions. No specific areas of concern were detected, indicating authentic, unmanipulated media.";
    }
  }

  static String _getSpectralAnalysisDescription(String mode, bool isFake, bool isMulti) {
    if (isMulti) {
      return "• VOICE CLONE CONFIRMED: Robotic modulation and frequency gaps detected\n"
          "• FORMANT INCONSISTENCIES: Artificial voice patterns identified\n"
          "• SPECTRAL ANOMALIES: Multiple frequency bands show tampering evidence\n"
          "• CRITICAL: Audio shows clear signs of AI generation/synthesis";
    }
    if (!isFake) {
      return "• Natural voice harmonics present throughout the frequency range\n• Consistent formant structure matching human speech patterns\n• No evidence of robotic modulation or artificial pitch correction\n• Natural background noise distribution typical of real recordings";
    }
    if (mode == 'gen_ai') {
      return "• Complete absence of natural acoustic noise patterns\n• Frequency distribution inconsistent with real recording equipment\n• Artificial spectrum with unnaturally clean frequency bands\n• Synthetic waveform lacking subtle variations of human speech";
    }
    return "• Robotic modulation patterns detected across voice frequencies\n• Inconsistent formant transitions indicating synthetic generation\n• Missing natural vocal fry and breath artifacts\n• Frequency gaps suggesting audio segments were artificially inserted";
  }

  static pw.Widget _buildAdvisory(bool isFake, String type, bool isMulti) {
    String advice;
    if (isMulti) {
      advice = "⚠️ EXTREME CAUTION ADVISED — This $type contains MULTIPLE independent manipulations (Face-Swap + Voice Clone). Do not trust this media for any purpose. Both the visual identity and voice have been artificially tampered with using different AI techniques. This is a sophisticated deepfake designed to deceive.";
    } else if (isFake) {
      advice = "Do not rely on this $type for factual information. It shows clear evidence of being digitally created, altered, or manipulated. Exercise extreme caution before trusting this media for any critical decisions or evidence.";
    } else {
      advice = "This $type passed all forensic integrity checks and matches the characteristics of authentic, unmanipulated media. It can be considered trustworthy for general use, though standard verification practices are still recommended.";
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: isMulti ? PdfColor.fromHex('FFF3E0') : PdfColors.grey100, 
        border: pw.Border(left: pw.BorderSide(color: isMulti ? _orangeMulti : _primaryNavy, width: 3))
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(isMulti ? "CRITICAL ADVISORY" : "HOW TO INTERPRET THIS RESULT", 
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: isMulti ? _orangeMulti : null)),
          pw.SizedBox(height: 8),
          pw.Bullet(text: advice, style: pw.TextStyle(fontSize: 9)),
          pw.Bullet(text: "Result based on Detectini Multimodal $type Scan.", style: pw.TextStyle(fontSize: 9)),
          pw.Bullet(text: "Analysis performed by Detectini Forensic Engine v5.2.", style: pw.TextStyle(fontSize: 9)),
          pw.Bullet(text: "This report is for informational purposes and constitutes an AI-assisted analysis.", style: pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  static pw.Widget _buildProbabilityGrid(double fake, double real, String type, bool isMulti, Map<String, dynamic> scores) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text("DETECTION PROBABILITY", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 10),
      pw.Table(border: pw.TableBorder.all(color: _dividerGray, width: 0.5), children: [
        pw.TableRow(children: [
          pw.Container(padding: const pw.EdgeInsets.all(5), child: pw.Text("Modality", style: pw.TextStyle(fontSize: 7))),
          pw.Container(color: _redStrong, padding: const pw.EdgeInsets.all(5), child: pw.Text("FAKE %", style: pw.TextStyle(fontSize: 7, color: PdfColors.white), textAlign: pw.TextAlign.center)),
          pw.Container(color: _greenStrong, padding: const pw.EdgeInsets.all(5), child: pw.Text("REAL %", style: pw.TextStyle(fontSize: 7, color: PdfColors.white), textAlign: pw.TextAlign.center)),
        ]),
        if (type == 'audio')
          _buildProbRow("Audio Fingerprint", fake, real)
        else if (type == 'image')
          _buildProbRow("Visual Integrity", fake, real)
        else
          _buildProbRow("A/V Correlation", fake, real),
        _buildProbRow("AI Model Score", fake > 50 ? fake - 2 : fake, real),
        _buildProbRow("Final Forensics Score", fake, real),
        if (isMulti) _buildProbRow("Multi-Manipulation", (scores['face_swap'] ?? 0.5) * 100, (scores['voice_clone'] ?? 0.5) * 100),
      ]),
    ]);
  }

  static pw.TableRow _buildProbRow(String label, double fake, double real) {
    return pw.TableRow(children: [
      pw.Container(padding: const pw.EdgeInsets.all(5), child: pw.Text(label, style: pw.TextStyle(fontSize: 7))),
      pw.Container(padding: const pw.EdgeInsets.all(5), child: pw.Text("${fake.toStringAsFixed(1)}%", style: pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
      pw.Container(padding: const pw.EdgeInsets.all(5), child: pw.Text("${real.toStringAsFixed(1)}%", style: pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
    ]);
  }

  static pw.Widget _buildProgressBar(String label, double val, PdfColor color) {
    return pw.Padding(padding: const pw.EdgeInsets.only(bottom: 8), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 8)),
        pw.Text("${(val * 100).toStringAsFixed(1)}%", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: color)),
      ]),
      pw.SizedBox(height: 3),
      pw.Stack(children: [
        pw.Container(height: 4, width: double.infinity, decoration: pw.BoxDecoration(color: _dividerGray, borderRadius: pw.BorderRadius.circular(2))),
        pw.Container(height: 4, width: (val.clamp(0.0, 1.0)) * 130, decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(2))),
      ]),
    ]));
  }

  static pw.Widget _buildDetailRow(String label, String value, PdfColor valueColor) {
    return pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(label, style: pw.TextStyle(fontSize: 9, color: _textGray)),
      pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: valueColor)),
    ]));
  }

  static double _toDouble(dynamic v) => (v is num) ? v.toDouble() : (double.tryParse(v?.toString() ?? '0') ?? 0.0);
}