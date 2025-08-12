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
  // Stores minimal data needed to redo: {from, to, promotion}
  final List<Map<String, dynamic>> _redoStack = [];

  AIDifficulty _difficulty = AIDifficulty.medium;
  bool _isAIMoving = false;

  /// Coerce a chess.dart property or function into a bool (compatible with both getter and method styles).
  bool _toBool(dynamic v) {
    if (v is bool) return v;
    if (v is bool Function()) return v();
    return v == true; // fallback
  }

  /// Convert a Piece (or dynamic) to a map with String keys (type/color) compatible with the UI.
  Map<String, dynamic>? _pieceToMap(dynamic piece) {
    if (piece == null) return null;

    // Try to extract enum names safely.
    String colorStr;
    try {
      final raw = piece.color?.toString() ?? '';
      final tail = raw.split('.').last.toLowerCase();
      colorStr = tail.startsWith('w')
          ? 'w'
          : (tail.startsWith('b')
              ? 'b'
              : (tail.contains('white') ? 'w' : 'b'));
    } catch (_) {
      // Fallback guess
      colorStr = 'w';
    }

    String typeStr;
    try {
      final raw = piece.type?.toString() ?? '';
      final tail = raw.split('.').last.toLowerCase();
      switch (tail) {
        case 'pawn':
        case 'p':
          typeStr = 'p';
          break;
        case 'knight':
        case 'n':
          typeStr = 'n';
          break;
        case 'bishop':
        case 'b':
          typeStr = 'b';
          break;
        case 'rook':
        case 'r':
          typeStr = 'r';
          break;
        case 'queen':
        case 'q':
          typeStr = 'q';
          break;
        case 'king':
        case 'k':
          typeStr = 'k';
          break;
        default:
          // Some libraries return single-character piece codes directly
          typeStr = tail.isNotEmpty ? tail[0] : 'p';
      }
    } catch (_) {
      typeStr = 'p';
    }

    return <String, dynamic>{'type': typeStr, 'color': colorStr};
  }

  /// Convert a Move-like object (either Map or typed Move) into a friendly map.
  Map<String, dynamic> _moveToMap(dynamic move) {
    if (move is Map) {
      return Map<String, dynamic>.from(move);
    }
    // Attempt property access for typed Move
    try {
      final from = move.from?.toString();
      final to = move.to?.toString();
      final san = move.san?.toString();
      final promotion = move.promotion?.toString();
      final flags = move.flags?.toString();
      return {
        if (from != null) 'from': from,
        if (to != null) 'to': to,
        if (san != null) 'san': san,
        if (promotion != null) 'promotion': promotion,
        if (flags != null) 'flags': flags,
      };
    } catch (_) {
      // Unknown shape
      return <String, dynamic>{};
    }
  }

  /// PUBLIC_INTERFACE
  /// Current AI difficulty.
  AIDifficulty get difficulty => _difficulty;

  /// PUBLIC_INTERFACE
  /// Whether the AI is currently computing a move.
  bool get isAIMoving => _isAIMoving;

  /// PUBLIC_INTERFACE
  /// Current FEN string of the board.
  String get fen {
    // chess.dart 0.8.1 exposes fen as a getter property.
    return _chess.fen;
  }

  /// PUBLIC_INTERFACE
  /// Returns the side to move: 'w' or 'b'.
  String get turn {
    final t = _chess.turn; // 0.8.1 uses a getter, often an enum or string-like
    final s = t.toString().toLowerCase();
    // Be robust across enum naming
    if (s.contains('w') || s.contains('white')) return 'w';
    return 'b';
  }

  /// PUBLIC_INTERFACE
  /// Readable outcome string if the game is over, or null if the game continues.
  String? get outcome {
    if (!_toBool(_chess.game_over)) return null;

    if (_toBool(_chess.in_checkmate)) {
      final winner = turn == 'w' ? 'Black' : 'White';
      return '$winner wins by checkmate';
    }
    if (_toBool(_chess.in_stalemate)) {
      return 'Draw by stalemate';
    }
    if (_toBool(_chess.in_threefold_repetition)) {
      return 'Draw by repetition';
    }
    if (_toBool(_chess.insufficient_material)) {
      return 'Draw by insufficient material';
    }
    if (_toBool(_chess.in_draw)) {
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
    // chess.dart uses positional options map: moves({'square': 'e2', 'verbose': true})
    final List<dynamic> moves = _chess.moves({'square': square, 'verbose': true});
    return moves.map(_moveToMap).toList();
  }

  /// PUBLIC_INTERFACE
  /// Returns the piece on a given square or null.
  /// The returned Map has keys: 'type' ('p','n','b','r','q','k') and 'color' ('w','b').
  Map<String, dynamic>? pieceAt(String square) {
    final dynamic piece = _chess.get(square);
    return _pieceToMap(piece);
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

  /// Find a legal move object for given coordinates (and optional promotion).
  dynamic _findLegalMove(String from, String to, {String? promotion}) {
    final List<dynamic> moves =
        _chess.moves({'square': from, 'verbose': true});
    for (final m in moves) {
      final mm = _moveToMap(m);
      if (mm['from'] == from && mm['to'] == to) {
        if (promotion == null || mm['promotion'] == promotion) {
          return m;
        }
      }
    }
    return null;
  }

  /// PUBLIC_INTERFACE
  /// Attempts to make a player move. Returns true if legal and applied.
  bool makePlayerMove(String from, String to, {String? promotion}) {
    if (_isAIMoving || _toBool(_chess.game_over)) return false;

    // Validate against legal moves to avoid relying on nullable returns.
    final dynamic candidate = _findLegalMove(from, to, promotion: promotion);
    if (candidate == null) return false;

    final applied = _chess.move(candidate);
    final m = _moveToMap(applied);
    _history.add(MoveRecord(
      san: (m['san'] ?? '').toString(),
      from: (m['from'] ?? '').toString(),
      to: (m['to'] ?? '').toString(),
      byAI: false,
    ));
    _redoStack.clear();
    notifyListeners();

    // Trigger AI if it's now black's turn
    if (!_toBool(_chess.game_over) && turn == 'b') {
      _aiMoveAsync();
    }
    return true;
  }

  /// PUBLIC_INTERFACE
  /// Undoes the last ply. Returns true if a move was undone.
  bool undo() {
    if (_isAIMoving) return false;
    if (_history.isEmpty) return false;

    final dynamic undone = _chess.undo();

    // Store minimal data to redo later
    final m = _moveToMap(undone);
    if (m.containsKey('from') && m.containsKey('to')) {
      _redoStack.add({
        'from': m['from'],
        'to': m['to'],
        if (m['promotion'] != null) 'promotion': m['promotion'],
      });
    }

    if (_history.isNotEmpty) {
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
    final applied = _chess.move({
      'from': next['from'],
      'to': next['to'],
      if (next['promotion'] != null) 'promotion': next['promotion'],
    });

    final m = _moveToMap(applied);
    _history.add(MoveRecord(
      san: (m['san'] ?? '').toString(),
      from: (m['from'] ?? '').toString(),
      to: (m['to'] ?? '').toString(),
      // If after the move it's white to move, the redone move was by black (AI).
      byAI: turn == 'w',
    ));
    notifyListeners();
    return true;
  }

  /// PUBLIC_INTERFACE
  /// Forces the AI to move now (if it's black's turn).
  void aiMoveNow() {
    if (_isAIMoving || _toBool(_chess.game_over) || turn == 'w') return;
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

      final dynamic move = _chooseBestMove(depth: depth);
      if (move != null) {
        final applied = _chess.move(move);
        final m = _moveToMap(applied);
        _history.add(MoveRecord(
          san: (m['san'] ?? '').toString(),
          from: (m['from'] ?? '').toString(),
          to: (m['to'] ?? '').toString(),
          byAI: true,
        ));
      }
    } finally {
      _isAIMoving = false;
      notifyListeners();
    }
  }

  dynamic _chooseBestMove({required int depth}) {
    // Use verbose flag in options map to get rich move objects compatible with _chess.move
    final List<dynamic> moves = _chess.moves({'verbose': true});
    if (moves.isEmpty) return null;

    if (depth == 1) {
      return moves[Random().nextInt(moves.length)];
    }

    double bestEval = double.negativeInfinity;
    dynamic bestMove;

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
    if (depth == 0 || _toBool(_chess.game_over)) {
      return _evaluateBoard();
    }
    final List<dynamic> moves = _chess.moves({'verbose': true});
    if (moves.isEmpty) {
      // No legal moves -> checkmate or stalemate
      if (_toBool(_chess.in_check)) {
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
        final pMap = _pieceToMap(_chess.get(square));
        if (pMap == null) continue;
        final type = pMap['type']?.toString();
        final color = pMap['color']?.toString();
        final value = pieceValues[type] ?? 0;
        score += color == 'w' ? value : -value;
      }
    }

    // Slight bonus for mobility
    final mobility = _chess.moves().length.toDouble();
    score += (turn == 'w' ? 0.1 : -0.1) * mobility;

    // Evaluate from side to move perspective for negamax
    return turn == 'w' ? score : -score;
  }
}
