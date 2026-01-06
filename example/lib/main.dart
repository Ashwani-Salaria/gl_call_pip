// import 'package:gl_call_pip/gl_call_pip.dart';
// import 'package:flutter/material.dart';

// // In-app PiP (floating overlay) controller
// class InAppPipController extends ChangeNotifier {
//   bool _visible = false;
//   bool get visible => _visible;

//   Offset _pos = const Offset(16, 120);
//   Offset get pos => _pos;

//   Size _size = const Size(180, 100);
//   Size get size => _size;

//   Widget? _child;
//   Widget? get child => _child;

//   void show(Widget child, {Offset? position, Size? size}) {
//     _child = child;
//     if (position != null) _pos = position;
//     if (size != null) _size = size;
//     _visible = true;
//     notifyListeners();
//   }

//   void hide() {
//     _visible = false;
//     notifyListeners();
//   }

//   void move(Offset delta) {
//     _pos += delta;
//     notifyListeners();
//   }
// }

// // Global controller
// final inAppPip = InAppPipController();

// void main() => runApp(const MyApp());

// class MyApp extends StatefulWidget {
//   const MyApp({super.key});
//   @override
//   State<MyApp> createState() => _MyAppState();
// }

// class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);

//     // Auto enter on minimize enable (Android 12+ native; <12 plugin fallback)
//     GlCallPip.setAutoEnterOnMinimize(true);
//     // Default portrait ratio
//     GlCallPip.updateAspectRatio(width: 9, height: 16);
//   }

//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     super.dispose();
//   }

//   // Optional: resume par UI refresh ya overlay logic
//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     // App foreground me aayega to overlay already visible rehega (agar tumne hide nahi kiya).
//   }

//   @override
//   Widget build(BuildContext context) {
//     return AnimatedBuilder(
//       animation: inAppPip,
//       builder: (context, _) {
//         return MaterialApp(
//           debugShowCheckedModeBanner: false,
//           // Global overlay sab routes ke upar inject karo
//           builder: (context, child) {
//             final ch = child ?? const SizedBox.shrink();
//             return Stack(
//               children: [
//                 ch,
//                 InAppPipOverlay(controller: inAppPip),
//               ],
//             );
//           },
//           routes: {
//             '/': (_) => const Page1(),
//             '/p2': (_) => const Page2(),
//             '/p3': (_) => const Page3(),
//             '/p4': (_) => const Page4(),
//             '/p5': (_) => const Page5(),
//           },
//         );
//       },
//     );
//   }
// }

// // In-app floating overlay widget
// class InAppPipOverlay extends StatelessWidget {
//   final InAppPipController controller;
//   const InAppPipOverlay({super.key, required this.controller});

//   @override
//   Widget build(BuildContext context) {
//     return AnimatedBuilder(
//       animation: controller,
//       builder: (context, _) {
//         if (!controller.visible || controller.child == null)
//           return const SizedBox.shrink();
//         return Positioned(
//           left: controller.pos.dx,
//           top: controller.pos.dy,
//           child: GestureDetector(
//             onPanUpdate: (d) => controller.move(d.delta),
//             child: Material(
//               elevation: 8,
//               borderRadius: BorderRadius.circular(12),
//               clipBehavior: Clip.antiAlias,
//               child: Container(
//                 width: controller.size.width,
//                 height: controller.size.height,
//                 color: Colors.black,
//                 child: Stack(
//                   children: [
//                     // Yahan tum apna Agora video widget mount kar do
//                     Positioned.fill(
//                       child: Center(
//                         child: Text(
//                           'Video',
//                           style: TextStyle(
//                             color: Colors.white.withOpacity(0.85),
//                             fontSize: 16,
//                           ),
//                         ),
//                       ),
//                     ),
//                     // Close button
//                     Positioned(
//                       right: 4,
//                       top: 4,
//                       child: IconButton(
//                         icon: const Icon(
//                           Icons.close,
//                           size: 18,
//                           color: Colors.white,
//                         ),
//                         padding: EdgeInsets.zero,
//                         constraints: const BoxConstraints(),
//                         onPressed: controller.hide,
//                       ),
//                     ),
//                     // Bottom actions: OS PiP enter / Foreground
//                     Positioned(
//                       left: 6,
//                       right: 6,
//                       bottom: 6,
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           _SmallBtn(
//                             icon: Icons.picture_in_picture_alt,
//                             label: 'PiP',
//                             onTap: () async {
//                               await GlCallPip.enter(
//                                 width: 9,
//                                 height: 16,
//                                 autoEnterOnMinimize: true,
//                               );
//                             },
//                           ),
//                           _SmallBtn(
//                             icon: Icons.open_in_full,
//                             label: 'FG',
//                             onTap: () async {
//                               await GlCallPip.bringToForeground();
//                             },
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }
// }

// class _SmallBtn extends StatelessWidget {
//   final IconData icon;
//   final String label;
//   final VoidCallback onTap;
//   const _SmallBtn({
//     required this.icon,
//     required this.label,
//     required this.onTap,
//   });
//   @override
//   Widget build(BuildContext context) {
//     return InkWell(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//         decoration: BoxDecoration(
//           color: Colors.white12,
//           borderRadius: BorderRadius.circular(6),
//           border: Border.all(color: Colors.white24),
//         ),
//         child: Row(
//           children: [
//             Icon(icon, size: 16, color: Colors.white),
//             const SizedBox(width: 4),
//             Text(
//               label,
//               style: const TextStyle(color: Colors.white, fontSize: 12),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // 5 pages

// class Page1 extends StatelessWidget {
//   const Page1({super.key});
//   @override
//   Widget build(BuildContext context) {
//     return _PageShell(
//       title: 'Page 1',
//       children: [
//         const Text('Navigate through pages. Overlay sab pages par dikhega.'),
//         const SizedBox(height: 12),
//         ElevatedButton(
//           onPressed: () => Navigator.pushNamed(context, '/p2'),
//           child: const Text('Go to Page 2'),
//         ),
//       ],
//     );
//   }
// }

// class Page2 extends StatelessWidget {
//   const Page2({super.key});
//   @override
//   Widget build(BuildContext context) {
//     return _PageShell(
//       title: 'Page 2',
//       children: [
//         ElevatedButton(
//           onPressed: () => Navigator.pushNamed(context, '/p3'),
//           child: const Text('Go to Page 3 (Start Call)'),
//         ),
//       ],
//     );
//   }
// }

// class Page3 extends StatelessWidget {
//   const Page3({super.key});
//   @override
//   Widget build(BuildContext context) {
//     return _PageShell(
//       title: 'Page 3 (Call)',
//       children: [
//         ElevatedButton(
//           onPressed: () {
//             // In-app overlay start: yahan tum apna Agora view pass kar do
//             inAppPip.show(
//               Container(
//                 color: Colors.black,
//                 child: const Center(
//                   child: Text(
//                     'Agora Video Here',
//                     style: TextStyle(color: Colors.white),
//                   ),
//                 ),
//               ),
//               size: const Size(200, 112), // ~16:9
//             );
//           },
//           child: const Text('Start call overlay (in-app)'),
//         ),
//         const SizedBox(height: 8),
//         ElevatedButton(
//           onPressed: inAppPip.hide,
//           child: const Text('Stop call overlay'),
//         ),
//         const Divider(height: 24),
//         ElevatedButton(
//           onPressed: () async {
//             await GlCallPip.enter(
//               width: 9,
//               height: 16,
//               autoEnterOnMinimize: true,
//             );
//           },
//           child: const Text('Enter OS PiP now'),
//         ),
//         const SizedBox(height: 8),
//         const Text('Tip: Home swipe/press → auto PiP (Android 12+)'),
//         const SizedBox(height: 20),
//         ElevatedButton(
//           onPressed: () => Navigator.pushNamed(context, '/p4'),
//           child: const Text('Go to Page 4'),
//         ),
//       ],
//     );
//   }
// }

// class Page4 extends StatelessWidget {
//   const Page4({super.key});
//   @override
//   Widget build(BuildContext context) {
//     return _PageShell(
//       title: 'Page 4',
//       children: [
//         ElevatedButton(
//           onPressed: () => Navigator.pushNamed(context, '/p5'),
//           child: const Text('Go to Page 5'),
//         ),
//       ],
//     );
//   }
// }

// class Page5 extends StatelessWidget {
//   const Page5({super.key});
//   @override
//   Widget build(BuildContext context) {
//     return _PageShell(
//       title: 'Page 5',
//       children: [
//         ElevatedButton(
//           onPressed: () =>
//               Navigator.popUntil(context, ModalRoute.withName('/')),
//           child: const Text('Back to Page 1'),
//         ),
//       ],
//     );
//   }
// }

// // Common shell
// class _PageShell extends StatelessWidget {
//   final String title;
//   final List<Widget> children;
//   const _PageShell({required this.title, required this.children});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text(title)),
//       body: ListView(
//         padding: const EdgeInsets.all(16),
//         children: [
//           ...children,
//           const SizedBox(height: 12),
//           Text('Overlay visible: ${inAppPip.visible}'),
//         ],
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:gl_call_pip/gl_call_pip.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _flutterCallPipPlugin = GlCallPip();
  bool _isInCall = false;
  String _status = 'Idle';

  @override
  void initState() {
    super.initState();
    _initPipCallbacks();
  }

  void _initPipCallbacks() {
    // Optional: You can listen to PiP status changes via MethodChannel if you expose them
    // (not required now but useful if you extend the plugin)
  }

  Future<void> _enterPipMode() async {
    try {
      print('🎬 Requesting PiP mode from Flutter');
      await GlCallPip.enter();
      setState(() => _status = 'In PiP');
    } catch (e) {
      debugPrint('❌ Error entering PiP mode: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to enter PiP: $e')));
    }
  }

  Future<void> _exitPipMode() async {
    try {
      print('🛑 Requesting exit PiP mode');
      await GlCallPip.stop();
      setState(() => _status = 'Call Ended');
    } catch (e) {
      debugPrint('❌ Error exiting PiP mode: $e');
    }
  }

  void _startFakeCall() {
    setState(() {
      _isInCall = true;
      _status = 'In Call';
    });
  }

  void _endFakeCall() {
    setState(() {
      _isInCall = false;
      _status = 'Idle';
    });
    _exitPipMode();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Call PiP Demo',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter Call PiP Demo'),
          backgroundColor: Colors.blueAccent,
        ),
        body: Center(child: !_isInCall ? _buildHomeUI() : _buildCallUI()),
      ),
    );
  }

  Widget _buildHomeUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.video_call, size: 80, color: Colors.blueAccent),
        const SizedBox(height: 20),
        Text('Status: $_status', style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _startFakeCall,
          icon: const Icon(Icons.call),
          label: const Text('Start Fake Call'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildCallUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircleAvatar(
          radius: 50,
          backgroundColor: Colors.blueAccent,
          child: Icon(Icons.person, size: 60, color: Colors.white),
        ),
        const SizedBox(height: 16),
        const Text(
          'John Calling...',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 40),
        Text('Status: $_status', style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _endFakeCall,
              icon: const Icon(Icons.call_end, color: Colors.white),
              label: const Text('End Call'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(width: 20),
            ElevatedButton.icon(
              onPressed: _enterPipMode,
              icon: const Icon(Icons.picture_in_picture, color: Colors.white),
              label: const Text('PiP'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
