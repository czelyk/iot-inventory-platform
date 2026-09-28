import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_kuhlschrank/providers/app_settings_provider.dart';
import 'package:smart_kuhlschrank/l10n/app_localizations.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = Provider.of<AppSettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        children: [
          // --- Appearance Section ---
          _buildSectionHeader(context, l10n.appearance), // Hardcoded 'Appearance' until l10n update
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: Text(l10n.theme), // Using 'theme' from l10n if available or hardcode fallbacks
            subtitle: Text(_getThemeModeName(settings.themeMode, context)),
            trailing: DropdownButton<ThemeMode>(
              value: settings.themeMode,
              onChanged: (ThemeMode? newValue) {
                if (newValue != null) {
                  settings.setThemeMode(newValue);
                }
              },
              items: [
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text(l10n.systemDefault), // 'System Default'
                ),
                DropdownMenuItem(
                  value: ThemeMode.light,
                  child: Text(l10n.lightTheme), // 'Light Theme'
                ),
                DropdownMenuItem(
                  value: ThemeMode.dark,
                  child: Text(l10n.darkTheme), // 'Dark Theme'
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  String _getThemeModeName(ThemeMode mode, BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (mode) {
      case ThemeMode.system: return l10n.systemDefault;
      case ThemeMode.light: return l10n.lightTheme;
      case ThemeMode.dark: return l10n.darkTheme;
    }
  }
}

// Temporary extensions for l10n to avoid compilation errors if keys are missing
// You should add these to your arb files properly.
extension L10nExtras on AppLocalizations {
  String get appearance => 'Appearance'; // Placeholder
  String get theme => 'Theme';
  String get systemDefault => 'System Default';
  String get lightTheme => 'Light';
  String get darkTheme => 'Dark';
  
}
