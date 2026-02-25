import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import 'login_screen.dart'; 

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Access the Global Theme
    final theme = Theme.of(context);
    final appState = Provider.of<AppState>(context);
    final isDark = appState.isDarkMode;

    // Text Color logic
    Color textColor = isDark ? Colors.white : Colors.black87;
    Color subTextColor = isDark ? Colors.grey : Colors.grey[700]!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, // Dynamic Background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // THEME SWITCHER (Top Right)
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            color: isDark ? Colors.white : Colors.black54,
            onPressed: () => appState.toggleTheme(),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Image.asset('assets/logo.png', height: 60, errorBuilder: (c,e,s)=>Icon(Icons.security, size: 60, color: theme.primaryColor)),
              const SizedBox(height: 40),
              
              Text(
                "Select your Account Type",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 10),
              Text(
                "Choose the profile that best fits your needs.",
                style: TextStyle(color: subTextColor),
              ),
              const SizedBox(height: 40),

              // THE CARDS
              Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.center,
                children: [
                  _RoleCard(
                    context,
                    title: "Individual",
                    desc: "Protect yourself from scams.",
                    icon: Icons.person_outline,
                    color: Colors.blue,
                    role: "individual",
                    isDark: isDark,
                  ),
                  _RoleCard(
                    context,
                    title: "Media & Enterprise",
                    desc: "For journalists and companies.",
                    icon: Icons.business,
                    color: Colors.purple,
                    role: "enterprise",
                    isDark: isDark,
                  ),
                  _RoleCard(
                    context,
                    title: "Government / Police",
                    desc: "Forensics & Evidence analysis.",
                    icon: Icons.security,
                    color: Colors.redAccent,
                    role: "police",
                    isDark: isDark,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _RoleCard(BuildContext context, {
    required String title, 
    required String desc, 
    required IconData icon, 
    required Color color, 
    required String role,
    required bool isDark
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (_) => LoginScreen(selectedRole: role))
        );
      },
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          // Dynamic Card Color
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black26 : Colors.grey.withOpacity(0.2), 
              blurRadius: 20,
              offset: const Offset(0, 4)
            )
          ],
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 20),
            Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(desc, textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.grey : Colors.grey[600], fontSize: 13)),
          ],
        ),
      ),
    );
  }
}