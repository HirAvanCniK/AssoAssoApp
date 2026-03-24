import 'package:flutter/material.dart';
import '../core/app_globals.dart';
import '../services/shared_preferences_service.dart';
import '../widgets/bold_button.dart';
import '../widgets/settings_tile.dart';
import '../widgets/universal_safearea.dart';

// A screen for configuring global application settings.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? _actual_prefs;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Loads all settings from persistent storage.
  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferencesService.loadPreferences();
    if (mounted) {
      setState(() {
        _actual_prefs = prefs;
        _isLoading = false;
      });
    }
  }

  // Saves a boolean setting and updates the UI state.
  Future<void> _saveSetting(String key, dynamic value) async {
    await SharedPreferencesService.savePreference(key, value);
    if (mounted) {
      setState(() {
        _actual_prefs![key] = value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: MySafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        children: [
                          const SizedBox(height: 30),
                          Align(
                            alignment: Alignment.center, 
                            child: Text(
                              'IMPOSTAZIONI',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.yellow[100],
                                shadows: const [
                                  Shadow(blurRadius: 6, color: Colors.black87, offset: Offset(2, 2)),
                                ],
                              ),
                            )
                          ),
                          const SizedBox(height: 20),
                          Text("Generali", 
                            style: TextStyle(
                              color: const Color(0xFFFFF0BA), 
                              fontSize: 28, 
                              fontWeight: FontWeight.bold
                            )
                          ),
                          _buildToggleSetting("Audio", "Abilita o disabilita tutti i suoni di gioco", AppGlobals.keySound),
                          SizedBox(height: 40),
                          Text("Gioco", 
                            style: TextStyle(
                              color: const Color(0xFFFFF0BA), 
                              fontSize: 28, 
                              fontWeight: FontWeight.bold
                            )
                          ),
                          _buildToggleSetting('Mescola giocatori', 'Determina l\'ordine di gioco casualmente', AppGlobals.keyShufflePlayers),
                          _buildToggleSetting('Rimescola mazzo', 'Se il mazzo finisce, rimescola gli scarti prima di riutilizzarli', AppGlobals.keyReshuffleDeck),
                          _buildToggleSetting('Squadre', 'Abilita la modalità a squadre quando si è in 4 giocatori', AppGlobals.keySquads),
                          _buildDropdownSetting<int>('Tempo per mossa', 'Durata massima di ogni mossa', AppGlobals.keyTimePerTurn, [10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60], (v) => '$v sec'),
                          _buildDropdownSetting<int>('Scale minime', 'Numero di scale per vincere quando si è in 2 giocatori', AppGlobals.keyMinScales, [1, 2], (v) => '$v'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    BoldButton(
                      label: 'INDIETRO',
                      onPressed: () => Navigator.pop(context),
                      backgroundColor: Colors.orange.shade400,
                      borderColor: Colors.yellow.shade600,
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildToggleSetting(String title, String subtitle, String key) {
    return SettingsTile(
      title: title,
      subtitle: subtitle,
      trailing: Switch(
        value: _actual_prefs![key],
        onChanged: (bool value){
          _saveSetting(key, value);
        },
        activeThumbColor: Colors.green.shade400,
        inactiveThumbColor: Colors.grey.shade700,
        activeTrackColor: Colors.green.withValues(alpha: 0.5),
        inactiveTrackColor: Colors.grey.withValues(alpha: 0.5),
      ),
    );
  }


  Widget _buildDropdownSetting<T>(
    String title, String subtitle, String key, List<T> items, String Function(T) valueBuilder) {
    return SettingsTile(
      title: title,
      subtitle: subtitle,
      trailing: DropdownButton<T>(
        value: _actual_prefs![key],
        items: items.map((item) => DropdownMenuItem<T>(value: item, child: Text(valueBuilder(item)))).toList(),
        onChanged: (newValue) => _saveSetting(key, newValue),
        dropdownColor: Colors.black87,
        style: const TextStyle(color: Colors.white),
        underline: Container(),
      ),
    );
  }
}
