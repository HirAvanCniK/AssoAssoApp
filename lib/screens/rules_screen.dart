import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/bold_button.dart';
import '../widgets/universal_safearea.dart';

class RulesScreen extends StatefulWidget {
  const RulesScreen({super.key});

  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen> {
  String? _markdownContent;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMarkdown();
  }

  Future<void> _loadMarkdown() async {
    try {
      final content = await rootBundle.loadString('assets/attachments/rules.md');
      setState(() {
        _markdownContent = content;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _markdownContent = '⚠️ Errore nel caricamento del regolamento: $e';
        _isLoading = false;
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
          child: Column(
            children: [
              const SizedBox(height: 30),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.yellow.shade600, width: 2),
                  ),
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.yellow),
                        )
                      : Markdown(
                          data: _markdownContent ?? '',
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          styleSheet: MarkdownStyleSheet.fromTheme(
                            Theme.of(context).copyWith(
                              textTheme: GoogleFonts.bangersTextTheme(
                                Theme.of(context).textTheme,
                              ),
                            ),
                          ).copyWith(
                            p: GoogleFonts.bangers(
                              fontSize: 16,
                              color: Colors.white,
                              letterSpacing: 1.5,
                              height: 1.8,
                            ),
                            h1: GoogleFonts.bangers(
                              fontSize: 24,
                              color: Colors.yellow.shade300,
                              letterSpacing: 2,
                            ),
                            h2: GoogleFonts.bangers(
                              fontSize: 20,
                              color: Colors.orange.shade300,
                              letterSpacing: 1.8,
                            ),
                            h3: GoogleFonts.bangers(
                              fontSize: 16,
                              color: const Color.fromARGB(255, 255, 210, 64),
                              letterSpacing: 1.6,
                            ),
                            listBullet: GoogleFonts.bangers(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                            blockquote: GoogleFonts.bangers(
                              fontSize: 14,
                              color: Colors.grey.shade300,
                              fontStyle: FontStyle.italic,
                            ),
                            blockquoteDecoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: Colors.yellow.shade600,
                                  width: 3,
                                ),
                              ),
                            ),
                            code: GoogleFonts.bangers(
                              fontSize: 14,
                              color: Colors.green.shade300,
                              backgroundColor: Colors.black54,
                            ),
                          ),
                        ),
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
}