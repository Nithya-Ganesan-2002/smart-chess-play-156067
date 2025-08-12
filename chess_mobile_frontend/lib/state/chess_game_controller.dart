import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chess/chess.dart' as ch;

/// Represents AI difficulty levels.
enum AIDifficulty { easy, medium, hard }

/// A struct-like model for a single move in history.
class MoveRecord {
  final String san; // Standard Algebraic Notation
  final String from;
  final String to;
  final bool byAI;

  MoveRecord({
    required this.san,
    required this.from,
    required this.to,
    required this.byAI,
  });
}

/// PUBLIC_INTERFACE
/// A ChangeNotifier-based controller managing chess gameplay state, including:
/// - board position and move validation via the local chess engine,
/// - AI move generation with adjustable difficulty,
/// - move history handling with undo/redo,
/// - game outcome detection.
class ChessGameController extends ChangeNotifier {
  ChessGameController() {
    _loadDifficulty();
  }

  final ch.Chess _chess = ch.Chess();
  final List<MoveRecord> _history = [];
  final List<Map<String, dynamic>> _redoStack = [];

  AIDifficulty _difficulty = AIDifficulty.medium;
  bool _isAIMoving = false;

  /// PUBLIC_INTERFACE
  /// Current AI difficulty.
  AIDifficulty get difficulty => _difficulty;

  /// PUBLIC_INTERFACE
  /// Whether the AI is currently computing a move.
  bool get isAIMoving => _isAIMoving;

  /// PUBLIC_INTERFACE
  /// Current FEN string of the board.
  String get fen => _chess.fen;

  /// PUBLIC_INTERFACE
  /// Returns the side to move: 'w' or 'b'.
  String get turn => _chess.turn();

  /// PUBLIC_INTERFACE
  /// Readable outcome string if the game is over, or null if the game continues.
  String? get outcome {
    if (!_chess.game_over()) return null;

    if (_chess.in_checkmate()) {
      final winner = _chess.turn() == 'w' ? 'Black' : 'White';
      return '$winner wins by checkmate';
    }
    if (_chess.in_stalemate()) {
      return 'Draw by stalemate';
    }
    // Some engines expose threefold repetition via in_threefold_repetition()
    try {
      final dynamic r = _chess.in_threefold_repetition;
      if ((r is bool && r == true) || (r is Function && r() == true)) {
        return 'Draw by repetition';
      }
    } catch (_) {
      // Ignore if not available in this version.
    }
    try {
      final dynamic im = _chess.insufficient_material;
      if ((im is bool && im == true) || (im is Function && im() == true)) {
        return 'Draw by insufficient material';
      }
    } catch (_) {
      // Ignore if not available in this version.
    }
    if (_chess.in_draw()) {
      return 'Draw';
    }
    return 'Game over';
  }

  /// PUBLIC_INTERFACE
  /// Returns the move history as pairs (white, black).
  List<List<MoveRecord>> get movePairs {
    final pairs = <List<MoveRecord>>[];
    for (int i = 0; i < _history.length; i += 2) {
      final pair = <MoveRecord>[];
      pair.add(_history[i]);
      if (i + 1 < _history.length) pair.add(_history[i + 1]);
      pairs.add(pair);
    }
    return pairs;
  }

  /// PUBLIC_INTERFACE
  /// Returns verbose legal moves from a given source square.
  /// Each entry is a Map with keys like 'from', 'to', 'san', 'flags', 'promotion'.
  List<Map<String, dynamic>> legalMovesFrom(String square) {
    final moves = _chess.moves({'square': square, 'verbose': true});
    return moves.cast<Map<String, dynamic>>();
  }

  /// PUBLIC_INTERFACE
  /// Returns the piece on a given square or null.
  /// The piece object has keys: 'type' ('p','n','b','r','q','k') and 'color' ('w','b').
  Map<String, dynamic>? pieceAt(String square) {
    final piece = _chess.get(square);
    if (piece == null) return null;
    return Map<String, dynamic>.from(piece);
  }

  /// PUBLIC_INTERFACE
  /// Updates AI difficulty and persists it.
  Future<void> setDifficulty(AIDifficulty level) async {
    _difficulty = level;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('difficulty', level.index);
  }

  Future<void> _loadDifficulty() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt('difficulty');
    if (idx != null && idx >= 0 && idx < AIDifficulty.values.length) {
      _difficulty = AIDifficulty.values[idx];
      notifyListeners();
    }
  }

  /// PUBLIC_INTERFACE
  /// Starts a new game, clearing history and redo stack.
  void newGame({bool notify = true}) {
    _chess.reset();
    _history.clear();
    _redoStack.clear();
    _isAIMoving = false;
    if (notify) notifyListeners();
  }

  /// PUBLIC_INTERFACE
  /// Attempts to make a player move. Returns true if legal and applied.
  bool makePlayerMove(String from, String to, {String? promotion}) {
    if (_isAIMoving || _chess.game_over()) return false;

    final move = _chess.move({
      'from': from,
      'to': to,
      if (promotion != null) 'promotion': promotion,
    });

    if (move == null) return false;

    final m = Map<String, dynamic>.from(move);
    _history.add(MoveRecord(
      san: (m['san'] ?? '').toString(),
      from: (m['from'] ?? '').toString(),
      to: (m['to'] ?? '').toString(),
      byAI: false,
    ));
    _redoStack.clear();
    notifyListeners();

    // Trigger AI if it's now black's turn
    if (!_chess.game_over() && _chess.turn() == 'b') {
      _aiMoveAsync();
    }
    return true;
  }

  /// PUBLIC_INTERFACE
  /// Undoes the last ply. Returns true if a move was undone.
  bool undo() {
    if (_isAIMoving) return false;
    final undone = _chess.undo();
    if (undone == null) return false;

    if (_history.isNotEmpty) {
      _redoStack.add(Map<String, dynamic>.from(undone));
      _history.removeLast();
    }
    notifyListeners();
    return true;
  }

  /// PUBLIC_INTERFACE
  /// Redoes the last undone ply if available. Returns true if a move was redone.
  bool redo() {
    if (_isAIMoving || _redoStack.isEmpty) return false;
    final next = _redoStack.removeLast();
    final moved = _chess.move({
      'from': next['from'],
      'to': next['to'],
      if (next['promotion'] != null) 'promotion': next['promotion'],
    });
    if (moved == null) return false;

    final m = Map<String, dynamic>.from(moved);
    _history.add(MoveRecord(
      san: (m['san'] ?? '').toString(),
      from: (m['from'] ?? '').toString(),
      to: (m['to'] ?? '').toString(),
      byAI: _chess.turn() == 'w',
    ));
    notifyListeners();
    return true;
  }

  /// PUBLIC_INTERFACE
  /// Forces the AI to move now (if it's black's turn).
  void aiMoveNow() {
    if (_isAIMoving || _chess.game_over() || _chess.turn() == 'w') return;
    _aiMoveAsync();
  }

  Future<void> _aiMoveAsync() async {
    _isAIMoving = true;
    notifyListeners();
    // Small delay to show thinking.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    try {
      final depth = switch (_difficulty) {
        AIDifficulty.easy => 1,
        AIDifficulty.medium => 2,
        AIDifficulty.hard => 3,
      };

      final move = _chooseBestMove(depth: depth);
      if (move != null) {
        final applied = _chess.move(move);
        if (applied != null) {
          final m = Map<String, dynamic>.from(applied);
          _history.add(MoveRecord(
            san: (m['san'] ?? '').toString(),
            from: (m['from'] ?? '').toString(),
            to: (m['to'] ?? '').toString(),
            byAI: true,
          ));
        }
      }
    } finally {
      _isAIMoving = false;
      notifyListeners();
    }
  }

  Map<String, dynamic>? _chooseBestMove({required int depth}) {
    final moves = _chess.moves({'verbose': true}).cast<Map<String, dynamic>>();
    if (moves.isEmpty) return null;

    if (depth == 1) {
      return moves[Random().nextInt(moves.length)];
    }

    double bestEval = double.negativeInfinity;
    Map<String, dynamic>? bestMove;

    for (final m in moves) {
      _chess.move(m);
      final eval = -_negamax(depth - 1, double.negativeInfinity, double.infinity);
      _chess.undo();
      if (eval > bestEval) {
        bestEval = eval;
        bestMove = m;
      }
    }
    return bestMove ?? moves[0];
  }

  double _negamax(int depth, double alpha, double beta) {
    if (depth == 0 || _chess.game_over()) {
      return _evaluateBoard();
    }
    final moves = _chess.moves({'verbose': true}).cast<Map<String, dynamic>>();
    if (moves.isEmpty) {
      // No legal moves -> checkmate or stalemate
      if (_chess.in_check()) {
        // Checkmated current player: bad for the side to move
        return -100000;
      } else {
        return 0; // stalemate
      }
    }

    double maxEval = double.negativeInfinity;
    for (final m in moves) {
      _chess.move(m);
      final eval = -_negamax(depth - 1, -beta, -alpha);
      _chess.undo();
      if (eval > maxEval) maxEval = eval;
      if (eval > alpha) alpha = eval;
      if (alpha >= beta) break; // alpha-beta pruning
    }
    return maxEval;
  }

  // Simple material evaluation + small mobility factor.
  double _evaluateBoard() {
    const pieceValues = {
      'p': 100.0,
      'n': 320.0,
      'b': 330.0,
      'r': 500.0,
      'q': 900.0,
      'k': 20000.0,
    };

    double score = 0;
    const files = 'abcdefgh';
    for (int rank = 1; rank <= 8; rank++) {
      for (int f = 0; f < 8; f++) {
        final square = '${files[f]}$rank';
        final piece = _chess.get(square);
        if (piece == null) continue;
        final type = piece['type']?.toString();
        final color = piece['color']?.toString();
        final value = pieceValues[type] ?? 0;
        score += color == 'w' ? value : -value;
      }
    }

    // Slight bonus for mobility
    final mobility = _chess.moves().length.toDouble();
    score += (_chess.turn() == 'w' ? 0.1 : -0.1) * mobility;

    // Evaluate from side to move perspective for negamax
    return _chess.turn() == 'w' ? score : -score;
  }
}
