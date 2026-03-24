import '../core/app_globals.dart';
import '../services/pocketbase_service.dart';

// Manages deck operations for a card game session synchronized with PocketBase.
//
// Handles deck creation, shuffling, drawing, discarding, and deck/discard pile swapping.
class DeckController {
  final PocketBaseService _pbService = PocketBaseService();
  final String _sessionCode;

  // Initializes a new controller for the specified session.
  DeckController(this._sessionCode);

  // Creates and persists a new standard 56-card deck (two mixed sets + 4 jokers).
  //
  // Resets the discard pile and updates the session record in the database.
  Future<void> newDeck() async {
    try {
      final session = await _pbService.getSessionByCode(_sessionCode);
      if (session == null) return;

      await _pbService.sessions.update(
        session.id,
        body: {
          'deck': [
            for (int i = 0; i < 2; i++)
              for (var rank in "A234567890JQK".split(''))
                for (var suit in "CDHS".split('')) rank + suit,
            ...List.filled(4, 'JOLLY'),
          ],
          'discardPile': [],
        },
      );
    } catch (e) {
      AppGlobals.debugPrint('Error in newDeck: $e');
    }
  }

  // Randomly shuffles the current draw deck and persists the change.
  Future<void> shuffle() async {
    try {
      final session = await _pbService.getSessionByCode(_sessionCode);
      if (session == null) return;

      var deck = List<String>.from(session.data['deck'] ?? []);
      deck.shuffle();

      await _pbService.sessions.update(session.id, body: {'deck': deck});
    } catch (e) {
      AppGlobals.debugPrint('Error in shuffle: $e');
    }
  }

  // Draws [nCards] from the top of the deck and returns them.
  //
  // Returns `null` if the session is not found, the deck is empty, or an error occurs.
  Future<List<String>?> getCardsFromDeck(int nCards) async {
    try {
      final session = await _pbService.getSessionByCode(_sessionCode);
      if (session == null) return null;

      var deck = List<String>.from(session.data['deck'] ?? []);
      if (nCards > deck.length) {
        AppGlobals.debugPrint('Not enough cards in deck to draw $nCards');
        return null;
      }

      List<String> cards = [for (int i = 0; i < nCards; i++) deck.removeAt(0)];

      await _pbService.sessions.update(session.id, body: {'deck': deck});

      return cards;
    } catch (e) {
      AppGlobals.debugPrint('Error in getCardsFromDeck: $e');
      return null;
    }
  }

  // Draws and returns the top card from the discard pile.
  //
  // Returns an empty string if the session is not found, the pile is empty, or an error occurs.
  Future<String> getCardFromDiscard() async {
    try {
      final session = await _pbService.getSessionByCode(_sessionCode);
      if (session == null) return "";

      var discardPile = List<String>.from(session.data['discardPile'] ?? []);
      if (discardPile.isEmpty) return "";

      final card = discardPile.removeLast();

      await _pbService.sessions.update(session.id, body: {'discardPile': discardPile});

      return card;
    } catch (e) {
      AppGlobals.debugPrint('Error in getCardFromDiscard: $e');
      return "";
    }
  }

  // Adds the specified [card] to the discard pile and persists the change.
  Future<void> discardCard(String card) async {
    try {
      final session = await _pbService.getSessionByCode(_sessionCode);
      if (session == null) return;

      var discardPile = List<String>.from(session.data['discardPile'] ?? []);
      discardPile.add(card);

      await _pbService.sessions.update(session.id, body: {'discardPile': discardPile});
    } catch (e) {
      AppGlobals.debugPrint('Error in discardCard: $e');
    }
  }

  // Swaps the contents of the draw deck and discard pile in the database.
  Future<void> invertDeckDiscard() async {
    try {
      final session = await _pbService.getSessionByCode(_sessionCode);
      if (session == null) return;

      var deck = List<String>.from(session.data['deck'] ?? []);
      var discardPile = List<String>.from(session.data['discardPile'] ?? []);

      if (session.data['gameSettings']['shuffleCardsWhenFinishDeck']) {
        discardPile.shuffle();
      }

      await _pbService.sessions.update(
        session.id,
        body: {'discardPile': deck, 'deck': discardPile},
      );
    } catch (e) {
      AppGlobals.debugPrint('Error in invertDeckDiscard: $e');
    }
  }
}
