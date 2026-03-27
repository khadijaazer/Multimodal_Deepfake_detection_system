import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _filterType = "All"; // All, Video, Text
  final TextEditingController _searchCtrl = TextEditingController();

  // --- MOCK DATA (Simulating Database) ---
  final List<Map<String, dynamic>> _allHistory = [
    {
      "id": "101",
      "type": "video",
      "name": "Interview_Clip_04.mp4",
      "date": "Feb 24, 10:30 AM",
      "status": "Fake Detected",
      "confidence": 98.4,
      "isSafe": false,
    },
    {
      "id": "102",
      "type": "text",
      "name": "SMS: 'Urgent Bank Verify...'",
      "date": "Feb 24, 09:15 AM",
      "status": "Potential Scam",
      "confidence": 85.0,
      "isSafe": false,
    },
    {
      "id": "103",
      "type": "video",
      "name": "Zoom_Meeting_Rec.mov",
      "date": "Feb 23, 04:00 PM",
      "status": "Authentic",
      "confidence": 99.1,
      "isSafe": true,
    },
    {
      "id": "104",
      "type": "text",
      "name": "Email: 'Project Update'",
      "date": "Feb 23, 02:20 PM",
      "status": "Safe Message",
      "confidence": 95.5,
      "isSafe": true,
    },
    {
      "id": "105",
      "type": "video",
      "name": "CCTV_Evidence_001.avi",
      "date": "Feb 22, 11:00 AM",
      "status": "Fake Detected",
      "confidence": 92.3,
      "isSafe": false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = appState.isDarkMode;

    // Theme Colors
    final bgCol = isDark ? const Color(0xFF0B1121) : const Color(0xFFF8FAFC);
    final cardCol = isDark ? const Color(0xFF151E32) : Colors.white;
    final textCol = isDark ? Colors.white : const Color(0xFF1E293B);
    final borderCol = isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300;

    // Filter Logic
    List<Map<String, dynamic>> filteredList = _allHistory.where((item) {
      bool typeMatch = _filterType == "All" || item['type'] == _filterType.toLowerCase();
      bool searchMatch = item['name'].toLowerCase().contains(_searchCtrl.text.toLowerCase());
      return typeMatch && searchMatch;
    }).toList();

    return Scaffold(
      backgroundColor: bgCol,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER ---
            Text("Analysis History", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textCol)),
            const SizedBox(height: 20),

            // --- SEARCH & FILTER BAR ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardCol,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderCol),
              ),
              child: Row(
                children: [
                  // Search Input
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() {}),
                      style: TextStyle(color: textCol),
                      decoration: InputDecoration(
                        hintText: "Search filename or content...",
                        hintStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Filter Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _filterType,
                        dropdownColor: cardCol,
                        icon: Icon(Icons.filter_list, color: textCol),
                        style: TextStyle(color: textCol),
                        items: ["All", "Video", "Text"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (val) => setState(() => _filterType = val!),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- HISTORY LIST ---
            if (filteredList.isEmpty)
              Center(child: Padding(padding: const EdgeInsets.all(40), child: Text("No history found", style: TextStyle(color: textCol))))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredList.length,
                itemBuilder: (context, index) {
                  return _buildHistoryCard(filteredList[index], isDark, cardCol, textCol, borderCol);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item, bool isDark, Color cardCol, Color textCol, Color borderCol) {
    bool isVideo = item['type'] == 'video';
    bool isSafe = item['isSafe'];
    Color statusColor = isSafe ? Colors.green : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardCol,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Row(
        children: [
          // 1. Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isVideo ? Colors.blue.withOpacity(0.1) : Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isVideo ? Icons.play_circle_fill : Icons.text_snippet,
              color: isVideo ? Colors.blue : Colors.purple,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),

          // 2. Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textCol)),
                const SizedBox(height: 4),
                Text(item['date'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),

          // 3. Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(isSafe ? Icons.check_circle : Icons.warning, color: statusColor, size: 14),
                const SizedBox(width: 6),
                Text(item['status'], style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
          
          const SizedBox(width: 16),

          // 4. Action Button
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onPressed: () {
              // Open detailed report (You can link this to DeepfakeScreen results later)
            },
          )
        ],
      ),
    );
  }
}