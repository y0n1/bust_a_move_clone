/// The gameplay screen: a thin View over [GameViewModel].
///
/// All state and logic live in the ViewModel; this widget only observes
/// and forwards pointer input. Rebuilds are driven by ChangeNotifier.
library;

import 'package:flutter/material.dart';

import '../../game/model.dart';
import '../viewmodel/game_viewmodel.dart';
import 'hud/score_display.dart';
import 'hud/level_display.dart';
import 'renderer/bubble_renderer.dart';

/// Minimum supported viewport width (covers ~95% of smartphones).
const double minViewportWidth = 360;

/// Maximum supported viewport width (covers tablets and standard desktops).
const double maxViewportWidth = 1024;

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.viewModel});

  final GameViewModel viewModel;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = widget.viewModel;
    _vm.init();
    _vm.addListener(_onViewModelChanged);
  }

  void _onViewModelChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _vm.removeListener(_onViewModelChanged);
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _vm.state;
    return Scaffold(
      backgroundColor: const Color(0xFF0B1E3A),
      body: Column(
        children: [
          _Hud(state: state, onRestart: _vm.restart),
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              final size = constraints.biggest;
              if (size.width == 0 || size.height == 0) return const SizedBox();
              _vm.computeLayout(size);
              return Stack(
                fit: StackFit.expand,
                children: [
                  Listener(
                    onPointerMove: (event) {
                      _vm.updateAim(event.localPosition, size);
                    },
                    onPointerDown: (event) {
                      _vm.updateAim(event.localPosition, size);
                    },
                    onPointerUp: (_) => _vm.fire(),
                    child: CustomPaint(
                      painter: GamePainter(
                        state: state,
                        engine: _vm.engine,
                        aimAngle: _vm.aimAngle,
                        hasPointer: _vm.hasPointer,
                        bubbleSize: _vm.bubbleSize,
                        offsetX: _vm.offsetX,
                        offsetY: _vm.offsetY,
                        bigPopElapsedMs: _vm.bigPopElapsedMs,
                        popups: _vm.popups,
                        bursts: _vm.bursts,
                        shakeElapsedMs: _vm.shakeElapsedMs,
                        trail: _vm.trail,
                        recoilElapsedMs: _vm.recoilElapsedMs,
                        fxElapsedMs: _vm.fxElapsedMs,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  if (state.status != GameStatus.playing)
                    _StatusOverlay(state: state, onRestart: _vm.restart),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// HUD widget — inline composite of score, level, and controls.
class _Hud extends StatelessWidget {
  const _Hud({required this.state, required this.onRestart});

  final GameState state;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: ScoreDisplay(state: state),
            ),
            LevelDisplay(state: state, onRestart: onRestart),
          ],
        ),
      ),
    );
  }
}

/// A modal shown when the game is won or lost.
class _StatusOverlay extends StatelessWidget {
  const _StatusOverlay({required this.state, required this.onRestart});

  final GameState state;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final won = state.status == GameStatus.won;
    final lost = state.status == GameStatus.lost;
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: Card(
        color: const Color(0xFF0B1E3A),
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                won
                    ? 'LEVEL ${state.level} CLEARED!'
                    : 'GAME OVER',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFDD835),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Score: ${state.score}',
                style: const TextStyle(
                    color: Color(0xFFFFFFFF), fontSize: 20),
              ),
              if (won) ...[
                const SizedBox(height: 8),
                Text(
                  'Level ${state.level + 1} awaits!',
                  style: const TextStyle(
                      color: Color(0xFFFFFFFF), fontSize: 16),
                ),
              ],
              if (lost) ...[
                const SizedBox(height: 8),
                Text(
                  state.lives > 0
                      ? 'You have ${state.lives} lives left — tap to continue'
                      : 'No lives remaining',
                  style: const TextStyle(
                      color: Color(0xFFFFFFFF), fontSize: 16),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onRestart,
                child: Text(
                  won
                      ? 'CONTINUE'
                      : (lost && state.lives > 0 ? 'CONTINUE' : 'PLAY AGAIN'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
