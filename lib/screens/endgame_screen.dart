import 'dart:math';
import 'package:flutter/material.dart';
import '../core/app_router.dart';
import '../widgets/bold_button.dart';
import '../widgets/universal_safearea.dart';
import '../services/shared_preferences_service.dart';

/// Route arguments:
///   - 'currentUserNickname' : String
///   - 'players'             : List<Map<String, dynamic>>
class EndGameScreen extends StatefulWidget {
  const EndGameScreen({super.key});

  @override
  State<EndGameScreen> createState() => _EndGameScreenState();
}

class _EndGameScreenState extends State<EndGameScreen>
    with TickerProviderStateMixin {

  late String _currentUserNickname;
  late List<Map<String, dynamic>> _players;
  late List<Map<String, dynamic>> _winners;
  late bool _currentUserWon;

  late AnimationController _headerCtrl;
  late AnimationController _confettiCtrl;
  late AnimationController _listCtrl;
  late Animation<double> _headerScale;
  late Animation<double> _headerOpacity;

  final List<_ConfettiParticle> _particles = [];
  static const List<Color> _confettiColors = [
    Color(0xFFFFD700), Color(0xFFFF6B6B), Color(0xFF4ECDC4),
    Color(0xFF45B7D1), Color(0xFF96E6A1), Color(0xFFFFA07A),
    Color(0xFFDA70D6),
  ];

  bool _argsLoaded = false;

  @override
  void initState() {
    super.initState();

    _headerCtrl = AnimationController(
        duration: const Duration(milliseconds: 900), vsync: this);
    _confettiCtrl = AnimationController(
        duration: const Duration(seconds: 6), vsync: this);
    _listCtrl = AnimationController(
        duration: const Duration(milliseconds: 700), vsync: this);

    _headerScale = CurvedAnimation(
        parent: _headerCtrl, curve: Curves.elasticOut);
    _headerOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _headerCtrl, curve: Curves.easeIn));

    final rng = Random();
    for (int i = 0; i < 60; i++) {
      _particles.add(_ConfettiParticle(
        x: rng.nextDouble(),
        delay: rng.nextDouble() * 3.0,
        speed: 0.3 + rng.nextDouble() * 0.7,
        size: 6 + rng.nextDouble() * 8,
        color: _confettiColors[rng.nextInt(_confettiColors.length)],
        angle: rng.nextDouble() * 2 * pi,
        rotSpeed: (rng.nextDouble() - 0.5) * 4,
      ));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    _argsLoaded = true;

    final args = ModalRoute.of(context)?.settings.arguments
        as Map<String, dynamic>? ?? {};
    _currentUserNickname = args['currentUserNickname'] as String? ?? '';

    final rawPlayers = args['players'] as List? ?? [];
    _players = rawPlayers
        .map<Map<String, dynamic>>(
            (e) => Map<String, dynamic>.from(e as Map))
        .toList();

    _winners = _players.where((p) => p['won'] == true).toList();
    _currentUserWon = _players.any(
        (p) => p['nickname'] == _currentUserNickname && p['won'] == true);
    if (_currentUserWon) {
      SharedPreferencesService.updateSettingsAndStats(winsDelta: 1, gamesPlayedDelta: 1);
    } else {
      SharedPreferencesService.updateSettingsAndStats(lossesDelta: 1, gamesPlayedDelta: 1);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _headerCtrl.forward();
      await Future.delayed(const Duration(milliseconds: 250));
      _listCtrl.forward();
      if (_currentUserWon) _confettiCtrl.repeat();
    });
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _confettiCtrl.dispose();
    _listCtrl.dispose();
    super.dispose();
  }

  int _completedCount(Map<String, dynamic> p) {
    int n = 0;
    for (final s in (p['completedScales'] as List? ?? [])) {
      if (s is List) n += s.length;
    }
    return n;
  }

  int _handCount(Map<String, dynamic> p) =>
      (p['hand'] as List? ?? []).length;

  List<List<Map<String, dynamic>>> _nonEmptyScales(
      Map<String, dynamic> p) =>
      ((p['completedScales'] as List? ?? []))
          .whereType<List>()
          .where((s) => s.isNotEmpty)
          .map((s) => s
              .map((c) => Map<String, dynamic>.from(c as Map))
              .toList())
          .toList();

  // ── Single card ──────────────────────────────────────────────────────────────
  Widget _buildCard(String cardName,
      {required String uid, double w = 38, double h = 54, double el = 1.0}) {
    return Container(
      key: ValueKey('card_$uid'),
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15 * el),
            blurRadius: 20 * el,
            spreadRadius: 2 * el,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35 * el),
            blurRadius: 4 * el,
            spreadRadius: 0.5 * el,
            offset: Offset(1 * el, 3 * el),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Image.asset(
          'assets/images/cards/$cardName.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  /// Overlapping card fan — uses Stack+Positioned, no negative padding.
  Widget _cardFan(
    List<String> cardNames, {
    required String fanKey,
    double cardW = 38,
    double cardH = 54,
    double overlap = 14,
    double el = 0.8,
  }) {
    if (cardNames.isEmpty) return const SizedBox.shrink();
    final totalW = cardW + (cardNames.length - 1) * (cardW - overlap);
    return PageStorage(
      bucket: PageStorageBucket(),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: totalW,
          height: cardH + 12,
          child: Stack(
            children: [
              for (int i = 0; i < cardNames.length; i++)
                Positioned(
                  key: ValueKey('fan_pos_${fanKey}_$i'),
                  left: i * (cardW - overlap),
                  top: 0,
                  child: _buildCard(
                    cardNames[i],
                    uid: '${fanKey}_$i',
                    w: cardW,
                    h: cardH,
                    el: el,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scaleFan(
    List<Map<String, dynamic>> cards, {
    required String fanKey,
    double cardW = 40,
    double cardH = 57,
    double overlap = 14,
    double el = 0.85,
  }) {
    return _cardFan(
      cards.map((c) => c['card'] as String? ?? 'back').toList(),
      fanKey: fanKey,
      cardW: cardW,
      cardH: cardH,
      overlap: overlap,
      el: el,
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/background.jpg',
                fit: BoxFit.cover)),
          Positioned.fill(
            child: Container(
                color: Colors.black.withValues(alpha: 0.60))),
          if (_currentUserWon)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _confettiCtrl,
                builder: (_, __) => CustomPaint(
                  painter: _ConfettiPainter(
                    particles: _particles,
                    progress: _confettiCtrl.value,
                  ),
                ),
              ),
            ),
          MySafeArea(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        Expanded(child: _buildAnimatedList()),
        _buildFooter(),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildAnimatedList() {
    return AnimatedBuilder(
      animation: _listCtrl,
      builder: (context, _) {
        final t = _listCtrl.value;
        // ease-in opacity, ease-out-cubic offset
        final opacity = t;
        final offset = 60.0 * (1.0 - t * t * (3.0 - 2.0 * t));
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, offset),
            child: _buildListView(),
          ),
        );
      },
    );
  }

  Widget _buildListView() {
    final listItems = <Widget>[];

    listItems.addAll([
      const SizedBox(height: 8),
      _buildHeader(),
      const SizedBox(height: 14),
    ]);

    if (_winners.isNotEmpty) {
      listItems.add(_sectionTitle('🏅  VINCITORI'));
      listItems.add(const SizedBox(height: 8));
      for (int i = 0; i < _winners.length; i++) {
        listItems.add(_buildWinnerDetailCard(_winners[i], index: i));
      }
      listItems.add(const SizedBox(height: 16));
    }

    listItems.add(_sectionTitle('👥  GIOCATORI'));
    listItems.add(const SizedBox(height: 8));
    for (int i = 0; i < _players.length; i++) {
      listItems.add(_buildRankCard(_players[i], rank: i + 1));
    }
    listItems.add(const SizedBox(height: 8));

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      children: listItems,
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return FadeTransition(
      opacity: _headerOpacity,
      child: ScaleTransition(
        scale: _headerScale,
        child: Column(
          children: [
            Text(_currentUserWon ? '🏆' : '😔',
                style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 4),
            Text(
              _currentUserWon ? 'HAI VINTO!' : 'HAI PERSO!',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: _currentUserWon
                    ? const Color(0xFFFFD700)
                    : Colors.red.shade300,
                shadows: const [
                  Shadow(
                      blurRadius: 20,
                      color: Colors.black,
                      offset: Offset(2, 3)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _buildWinnerPill(),
          ],
        ),
      ),
    );
  }

  Widget _buildWinnerPill() {
    if (_winners.isEmpty) return const SizedBox.shrink();
    final names =
        _winners.map((w) => w['nickname'] as String).join(' & ');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.35),
            blurRadius: 20,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Text(
        _winners.length == 1
            ? '👑  $names  ha vinto!'
            : '👑  $names  hanno vinto!',
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w800,
          fontSize: 13,
          letterSpacing: 0.4,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 2),
        child: Text(text,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            )),
      );

  // ── Winner detail card ───────────────────────────────────────────────────────
  Widget _buildWinnerDetailCard(Map<String, dynamic> player,
      {required int index}) {
    final nickname = player['nickname'] as String? ?? '?';
    final isMe = nickname == _currentUserNickname;
    final scales = _nonEmptyScales(player);

    return Container(
      key: ValueKey('winner_card_$index'),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: const Color(0xFFFFD700), width: 2),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF3D2B00).withValues(alpha: 0.95),
            const Color(0xFF1A1200).withValues(alpha: 0.95),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.22),
            blurRadius: 24,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Player header row
            Row(
              children: [
                Stack(clipBehavior: Clip.none, children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white10,
                    backgroundImage: AssetImage(
                        player['avatarPath'] as String? ??
                            'assets/images/avatars/avatar_1.png'),
                  ),
                  const Positioned(
                    top: -12,
                    right: -8,
                    child: Text('👑',
                        style: TextStyle(fontSize: 18)),
                  ),
                ]),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(nickname,
                            style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              letterSpacing: 0.5,
                            )),
                        if (isMe) ...[
                          const SizedBox(width: 8),
                          _meBadge(),
                        ],
                      ]),
                      const SizedBox(height: 4),
                      Text(
                        '${_completedCount(player)} completate  ·  '
                        '${_handCount(player)} in mano',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Completed scales
            if (scales.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(color: Colors.white10),
              const SizedBox(height: 10),
              const Text('SCALE COMPLETATE',
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  )),
              const SizedBox(height: 12),
              for (int si = 0; si < scales.length; si++) ...[
                Container(
                  key: ValueKey('w_scale_label_${index}_$si'),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFFFD700)
                          .withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'Scala ${si + 1}  •  ${scales[si].length} carte',
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _scaleFan(
                  scales[si],
                  fanKey: 'winner_${index}_scale_$si',
                  cardW: 44,
                  cardH: 62,
                ),
                const SizedBox(height: 14),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // ── Rank card ────────────────────────────────────────────────────────────────
  Widget _buildRankCard(Map<String, dynamic> player,
      {required int rank}) {
    final nickname = player['nickname'] as String? ?? '?';
    final isWinner = player['won'] == true;
    final isMe = nickname == _currentUserNickname;
    final hand = (player['hand'] as List? ?? []).cast<String>();
    final scales = _nonEmptyScales(player);

    return Container(
      key: ValueKey('rank_card_$rank'),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: isMe
            ? Border.all(color: Colors.white38, width: 1.5)
            : null,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isWinner
              ? [
                  const Color(0xFF3D2B00).withValues(alpha: 0.80),
                  const Color(0xFF1A1200).withValues(alpha: 0.80),
                ]
              : [
                  Colors.white.withValues(alpha: 0.10),
                  Colors.white.withValues(alpha: 0.05),
                ],
        ),
      ),
      child: Theme(
        data: Theme.of(context)
            .copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey('expansion_$rank'),
          tilePadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 2),
          childrenPadding:
              const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Stack(clipBehavior: Clip.none, children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white10,
              backgroundImage: AssetImage(
                  player['avatarPath'] as String? ??
                      'assets/images/avatars/avatar_1.png'),
            ),
            if (isWinner)
              const Positioned(
                top: -10,
                right: -6,
                child: Text('👑',
                    style: TextStyle(fontSize: 13)),
              ),
          ]),
          title: Row(children: [
            Text(nickname,
                style: TextStyle(
                  color: isWinner
                      ? const Color(0xFFFFD700)
                      : Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                )),
            if (isMe) ...[
              const SizedBox(width: 8),
              _meBadge(),
            ],
          ]),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Wrap(spacing: 10, children: [
              _chip('🃏 ${_completedCount(player)} completate',
                  Colors.green.shade400),
              _chip('✋ ${_handCount(player)} in mano',
                  Colors.orange.shade300),
            ]),
          ),
          children: _buildExpansionChildren(
              player, scales, hand, nickname, rank),
        ),
      ),
    );
  }

  /// Extracted to a plain method so Flutter can properly key the children list.
  List<Widget> _buildExpansionChildren(
    Map<String, dynamic> player,
    List<List<Map<String, dynamic>>> scales,
    List<String> hand,
    String nickname,
    int rank,
  ) {
    final children = <Widget>[];

    if (scales.isNotEmpty) {
      children.add(_subLabel('SCALE COMPLETATE'));
      children.add(const SizedBox(height: 8));
      for (int si = 0; si < scales.length; si++) {
        children.add(Column(
          key: ValueKey('rank_${rank}_scale_$si'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Scala ${si + 1}  (${scales[si].length} carte)',
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            _scaleFan(
              scales[si],
              fanKey: 'rank_${rank}_scale_$si',
            ),
            const SizedBox(height: 12),
          ],
        ));
      }
    }

    if (hand.isNotEmpty) {
      children.add(const SizedBox(height: 4));
      children.add(_subLabel('CARTE IN MANO'));
      children.add(const SizedBox(height: 8));
      children.add(_cardFan(
        hand,
        fanKey: 'rank_${rank}_hand',
      ));
    }

    return children;
  }

  // ── Small widgets ────────────────────────────────────────────────────────────
  Widget _meBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text('TU',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            )),
      );

  Widget _chip(String label, Color color) => Text(label,
      style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600));

  Widget _subLabel(String text) => Text(text,
      style: const TextStyle(
        color: Colors.white30,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.6,
      ));

  // ── Footer ───────────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: BoldButton(
        label: 'TORNA ALLA HOME',
        onPressed: () => Navigator.pushNamedAndRemoveUntil(
          context,
          AppRouter.home,
          (route) => false,
        ),
        backgroundColor: Colors.orange.shade400,
        borderColor: Colors.yellow.shade600,
      ),
    );
  }
}

// ── Confetti ──────────────────────────────────────────────────────────────────
class _ConfettiParticle {
  final double x, delay, speed, size, angle, rotSpeed;
  final Color color;
  const _ConfettiParticle({
    required this.x,
    required this.delay,
    required this.speed,
    required this.size,
    required this.color,
    required this.angle,
    required this.rotSpeed,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;
  const _ConfettiPainter(
      {required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      double t = (progress - p.delay / 6.0) % 1.0;
      if (t < 0) t += 1.0;
      final y = size.height * t * p.speed * 1.8;
      final x =
          size.width * p.x + sin(t * 2 * pi * 2 + p.angle) * 30;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * p.rotSpeed * 2 * pi);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset.zero,
              width: p.size,
              height: p.size * 0.55),
          const Radius.circular(2),
        ),
        Paint()
          ..color = p.color.withValues(alpha: 1.0 - t * 0.6),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) =>
      old.progress != progress;
}