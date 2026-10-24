import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const kRed = Color(0xFFE11D26);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Landscape only, like a video player.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const KingApp());
}

class KingApp extends StatelessWidget {
  const KingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'King',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(primary: kRed),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

/// Black screen, red logo in the center, app name underneath.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: Curves.easeOut);
  late final Animation<double> _scale = Tween<double>(begin: 0.85, end: 1.0)
      .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack));

  @override
  void initState() {
    super.initState();
    _c.forward();
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (_, __, ___) => const LoadingScreen(),
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
        ),
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Put your own logo in assets/logo.png to replace this.
                Image.asset('assets/logo.png', width: 150, height: 150),
                const SizedBox(height: 6),
                const Text(
                  'King',
                  style: TextStyle(
                    color: kRed,
                    fontSize: 44,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Loading screen: logo + progress bar, then goes to the login screen.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    while (_progress < 1) {
      await Future.delayed(const Duration(milliseconds: 60));
      if (!mounted) return;
      setState(() => _progress = (_progress + 0.04).clamp(0, 1));
    }
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/logo.png', width: 120, height: 120),
            const SizedBox(height: 32),
            SizedBox(
              width: 260,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 8,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(kRed),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${(_progress * 100).round()}%',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

/// Login screen: sign in with Facebook, Google, or as a guest.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  void _goToName(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PlayerNameScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/logo.png', width: 110, height: 110),
              const SizedBox(height: 8),
              const Text(
                'King',
                style: TextStyle(
                  color: kRed,
                  fontSize: 36,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 48),
              _LoginButton(
                label: 'الدخول بفيسبوك',
                icon: Icons.facebook,
                color: const Color(0xFF1877F2),
                onTap: () => _goToName(context),
              ),
              const SizedBox(height: 14),
              _LoginButton(
                label: 'الدخول بجوجل',
                icon: Icons.g_mobiledata,
                color: Colors.white,
                textColor: Colors.black87,
                onTap: () => _goToName(context),
              ),
              const SizedBox(height: 14),
              _LoginButton(
                label: 'الدخول كضيف',
                icon: Icons.person_outline,
                color: const Color(0xFF1A1A1A),
                border: true,
                onTap: () => _goToName(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;
  final bool border;
  final VoidCallback onTap;

  const _LoginButton({
    required this.label,
    required this.icon,
    required this.color,
    this.textColor = Colors.white,
    this.border = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: textColor),
        label: Text(label, style: TextStyle(color: textColor, fontSize: 15)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: border ? const BorderSide(color: Colors.white24) : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

/// Screen where the player types their in-game name.
class PlayerNameScreen extends StatefulWidget {
  const PlayerNameScreen({super.key});

  @override
  State<PlayerNameScreen> createState() => _PlayerNameScreenState();
}

class _PlayerNameScreenState extends State<PlayerNameScreen> {
  final _controller = TextEditingController();

  void _confirm() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => HomeScreen(playerName: name)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'اكتب اسم اللاعب',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 300,
                  child: TextField(
                    controller: _controller,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    maxLength: 16,
                    decoration: InputDecoration(
                      hintText: 'Player Name',
                      hintStyle: const TextStyle(color: Colors.white38),
                      counterStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF1A1A1A),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: kRed),
                      ),
                    ),
                    onSubmitted: (_) => _confirm(),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 300,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kRed,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'تأكيد',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Main home screen: player card + friends list.
/// Friends shown here are sample data; wire up a real backend later.
class HomeScreen extends StatelessWidget {
  final String playerName;
  const HomeScreen({super.key, required this.playerName});

  static const _friends = [
    ('Ahmed_99', true),
    ('ZeroKing', true),
    ('Sara.gg', false),
    ('NoobMaster', true),
    ('Mo_Sniper', false),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('King', style: TextStyle(color: kRed)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Player card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF151515),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: kRed.withOpacity(0.2),
                    child: const Icon(Icons.person, color: kRed, size: 34),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playerName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'المستوى 1',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text(
                    'قائمة الأصدقاء',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_friends.length}',
                    style: const TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _friends.length,
                separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                itemBuilder: (context, i) {
                  final (name, online) = _friends[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white10,
                      child: const Icon(Icons.person, color: Colors.white54),
                    ),
                    title: Text(name, style: const TextStyle(color: Colors.white)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: online ? Colors.greenAccent : Colors.white24,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          online ? 'متصل' : 'غير متصل',
                          style: const TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
