import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class GamePage extends StatefulWidget {
  const GamePage({Key? key}) : super(key: key);

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Game page"),
      ),
      body: const Center(
        child: _GameView(),
      ),
    );
  }
}

class _GameView extends StatefulWidget {
  const _GameView({Key? key}) : super(key: key);

  @override
  State<_GameView> createState() => _GameViewState();
}

class _GameViewState extends State<_GameView>
    with SingleTickerProviderStateMixin {
  late final Emulator _emulator;
  late final _Timer _timer;

  @override
  void initState() {
    super.initState();
    _emulator = Emulator();
    _emulator.run();
    _timer = _Timer(this);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: lcdWidth.toDouble(),
      height: lcdHeight.toDouble(),
      child: CustomPaint(
        painter: _LCD(
          emulator: _emulator,
          timer: _timer,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emulator.dispose();
    _timer.dispose();
    super.dispose();
  }
}

class _Timer extends ChangeNotifier {
  final TickerProvider _vsync;
  late final Ticker _ticker;

  _Timer(this._vsync) {
    _ticker = _vsync.createTicker(_onTick);
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.stop();
    _ticker.dispose();
    super.dispose();
  }
}

class _LCD extends CustomPainter {
  final Emulator emulator;

  _LCD({
    required this.emulator,
    required _Timer timer,
  }) : super(repaint: timer);

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final image = emulator.image;
    if (image != null) {
      canvas.drawImage(image, Offset.zero, Paint());
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

const lcdWidth = 160;
const lcdHeight = 144;

class Emulator {
  ui.Image? _image;

  ui.Image? get image => _image;

  bool _isRunning = false;
  Timer? _timer;

  int xorshift32(int x) {
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    return x;
  }

  int seed = 0xDEADBEEF;

  Future<ui.Image> makeImage() {
    final c = Completer<ui.Image>();
    final pixels = Int32List(lcdWidth * lcdHeight);
    for (int i = 0; i < pixels.length; i++) {
      seed = pixels[i] = xorshift32(seed);
    }
    void decodeCallback(ui.Image image) {
      c.complete(image);
    }

    ui.decodeImageFromPixels(
      pixels.buffer.asUint8List(),
      lcdWidth,
      lcdHeight,
      ui.PixelFormat.rgba8888,
      decodeCallback,
    );
    return c.future;
  }

  void run() {
    if (_isRunning) {
      return;
    }
    _isRunning = true;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (timer) async {
      final newImage = await makeImage();
      _image?.dispose();
      _image = newImage;
    });
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _image?.dispose();
  }
}
