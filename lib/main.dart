import 'dart:async';
import 'package:dynamic_sdk/dynamic_sdk.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:my_app/views/login_view.dart';
import 'package:my_app/views/home_view.dart';
import 'package:my_app/views/loading_view.dart';
import 'package:my_app/views/wallet_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  DynamicSDK.init(
    props: ClientProps(
      // Find your environment id at https://app.dynamic.xyz/dashboard/developer
      environmentId: '0322a696-4207-48c6-9ed4-ffb0aa896090',
      appLogoUrl: 'https://demo.dynamic.xyz/favicon-32x32.png',
      appName: 'Dynamic Demo',
      redirectUrl: "flutterdemo://",
    ),
  );
  runApp(const MyApp());
}

/// Simple enum to reason about routing
enum AuthPhase { loading, unauthenticated, authenticated }

/// Bridges DynamicSDK streams into a ChangeNotifier for go_router
class AuthNotifier extends ChangeNotifier {
  AuthPhase _phase = AuthPhase.loading;
  AuthPhase get phase => _phase;

  StreamSubscription<bool>? _readySub;
  StreamSubscription<dynamic /*User?*/>? _userSub;

  bool _ready = false;
  bool _hasUser = false;

  AuthNotifier() {
    // Listen to SDK readiness
    _readySub = DynamicSDK.instance.sdk.readyChanges.listen((ready) {
      _ready = ready;
      _recomputePhase();
    });

    // Listen to auth state changes
    _userSub = DynamicSDK.instance.auth.authenticatedUserChanges.listen((user) {
      _hasUser = user != null;
      _recomputePhase();
    });

    // Initial snapshot in case streams emit late
    // (If the SDK exposes current values, read them here)
    // _ready = DynamicSDK.instance.sdk.isReady; // if available
    // _hasUser = DynamicSDK.instance.auth.currentUser != null; // if available
  }

  void _recomputePhase() {
    final next = !_ready
        ? AuthPhase.loading
        : (_hasUser ? AuthPhase.authenticated : AuthPhase.unauthenticated);

    if (next != _phase) {
      _phase = next;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _readySub?.cancel();
    _userSub?.cancel();
    super.dispose();
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AuthNotifier _auth;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _auth = AuthNotifier();

    _router = GoRouter(
      // This makes go_router re-check redirect whenever auth/ready changes
      refreshListenable: _auth,
      routes: [
        GoRoute(path: '/', builder: (_, __) => const HomeView()),
        GoRoute(path: '/login', builder: (_, __) => const LoginView()),
        GoRoute(path: '/loading', builder: (_, __) => const LoadingView()),
        GoRoute(
          path: '/wallet/:walletId',
          builder: (_, state) =>
              WalletView(walletId: state.pathParameters['walletId']!),
        ),
      ],
      redirect: (context, state) {
        final inLogin = state.matchedLocation == '/login';
        final inLoading = state.matchedLocation == '/loading';

        switch (_auth.phase) {
          case AuthPhase.loading:
            // While SDK/user are loading, keep users on /loading
            return inLoading ? null : '/loading';

          case AuthPhase.unauthenticated:
            // If not logged in, force /login except when already there
            return inLogin ? null : '/login';

          case AuthPhase.authenticated:
            // If logged in, keep them off /login and /loading
            if (inLogin || inLoading) return '/';
            return null;
        }
      },
      // Optional: keep query params/fragments if you redirect
      // redirectLimit: 5,
    );
  }

  @override
  void dispose() {
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Flutter Demo',
      routerDelegate: _router.routerDelegate,
      routeInformationParser: _router.routeInformationParser,
      routeInformationProvider: _router.routeInformationProvider,
      builder: (context, child) {
        // child is the routed page (Home/Login/Loading)
        if (child == null) return const SizedBox.shrink();

        return Stack(
          children: [
            child,
            // Keep Dynamic overlay/widget above your pages
            DynamicSDK.instance.dynamicWidget,
          ],
        );
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
    );
  }
}
