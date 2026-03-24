import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/app_globals.dart';
import '../services/shared_preferences_service.dart';
import '../widgets/bold_button.dart';
import '../widgets/universal_safearea.dart';
import '../widgets/settings_tile.dart';

// A screen for viewing and editing the user's profile (nickname and avatar).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nicknameController = TextEditingController();
  Map<String, dynamic>? _actual_prefs;
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();

  // Defines the list of available avatar images.
  final List<String> _avatars = List.generate(20, (i) => 'assets/images/avatars/avatar_$i.png');

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  // Loads the user's nickname and avatar path from persistent storage.
  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferencesService.loadPreferences();
    if (mounted) {
      setState(() {
        _actual_prefs = prefs;
        _nicknameController.text = prefs[AppGlobals.keyNickname];
        _isLoading = false;
      });
    }
  }

  // Saves the current profile data to persistent storage.
  Future<void> _saveProfileData() async {
    final newNickname = _nicknameController.text.trim();
    if (newNickname.isEmpty) {
      _showSnackBar('Il nickname non può essere vuoto');
      return;
    }

    await Future.wait([
      SharedPreferencesService.savePreference(AppGlobals.keyNickname, newNickname),
      SharedPreferencesService.savePreference(AppGlobals.keyAvatarPath, _actual_prefs![AppGlobals.keyAvatarPath]),
    ]);

    if (mounted) {
      _showSnackBar('Profilo aggiornato con successo!');
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _scrollController.dispose();
    super.dispose();
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
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              BoldButton(
                                label: 'INDIETRO',
                                onPressed: () => Navigator.of(context).pop(),
                                backgroundColor: Colors.grey.shade700,
                                borderColor: Colors.grey.shade500,
                              ),
                              Text(
                                'PROFILO',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.yellow[100],
                                  shadows: const [
                                    Shadow(blurRadius: 6, color: Colors.black87, offset: Offset(2, 2)),
                                  ],
                                ),
                              ),
                              BoldButton(
                                label: 'SALVA',
                                onPressed: _saveProfileData,
                                backgroundColor: Colors.green.shade600,
                                borderColor: Colors.green.shade400,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildAvatarSelector(),
                          const SizedBox(height: 24),
                          _buildNicknameField(),
                          const SizedBox(height: 50),
                          _buildPref("Partite giocate", "Quante partite hai giocato", AppGlobals.keyGamesPlayed),
                          _buildPref("Vittorie", "Quante partite hai vinto", AppGlobals.keyWins),
                          _buildPref("Sconitte", "Quante partite hai perso", AppGlobals.keyLosses),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      )
    );
  }

  // Builds the horizontal list of selectable avatars.
  Widget _buildAvatarSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Seleziona il tuo avatar',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: Scrollbar(
            controller: _scrollController, // Collega il controller
            thumbVisibility: true,         // Rende visibile la barra su desktop
            child: ScrollConfiguration(
              behavior: MaterialScrollBehavior().copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.stylus,
                  PointerDeviceKind.unknown,
                },
              ),
              child: ListView.builder(
                controller: _scrollController, // Usa lo stesso controller
                scrollDirection: Axis.horizontal,
                itemCount: _avatars.length,
                padding: const EdgeInsets.symmetric(vertical: 10),
                itemBuilder: (context, index) {
                  final avatar = _avatars[index];
                  final isSelected = avatar == _actual_prefs![AppGlobals.keyAvatarPath];
                  return GestureDetector(
                    onTap: () => setState(() => _actual_prefs![AppGlobals.keyAvatarPath] = avatar),
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.yellow.shade600, width: 4)
                            : null,
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black54,
                            blurRadius: 5,
                            offset: Offset(2, 2),
                          )
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 45,
                        backgroundImage: AssetImage(avatar),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Builds the text field for editing the nickname.
  Widget _buildNicknameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Il tuo nickname',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nicknameController,
          maxLength: 10,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.5),
            counterStyle: const TextStyle(color: Colors.white70),
            hintText: 'Nickname',
            hintStyle: const TextStyle(color: Colors.white54),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.yellow.shade800.withValues(alpha: 0.7)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.yellow.shade600, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPref(String title, String subtitle, String key) {
    return SettingsTile(
      title: title, 
      subtitle: subtitle,
      trailing: Text(_actual_prefs![key].toString(), style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold)),
    );
  }

  // Displays a temporary feedback message to the user.
  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.black87,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}
