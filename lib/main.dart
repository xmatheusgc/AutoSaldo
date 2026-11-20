import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/constants.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/expense_repository.dart';
import 'data/repositories/vehicle_repository.dart';
import 'data/repositories/workspace_repository.dart';
import 'data/services/fipe_service.dart';
import 'firebase_options.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/auth/unauthorized_screen.dart';
import 'presentation/screens/home_shell.dart';
import 'presentation/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const AutoSaldoApp());
}

class AutoSaldoApp extends StatefulWidget {
  const AutoSaldoApp({super.key});

  @override
  State<AutoSaldoApp> createState() => _AutoSaldoAppState();
}

class _AutoSaldoAppState extends State<AutoSaldoApp> {
  late final AuthRepository _authRepository;
  late final WorkspaceRepository _workspaceRepository;
  late final VehicleRepository _vehicleRepository;
  late final ExpenseRepository _expenseRepository;
  late final FipeService _fipeService;

  @override
  void initState() {
    super.initState();
    _authRepository = AuthRepository();
    _workspaceRepository = WorkspaceRepository();
    _vehicleRepository = VehicleRepository();
    _expenseRepository = ExpenseRepository();
    _fipeService = FipeService();
  }

  @override
  void dispose() {
    _fipeService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AutoSaldo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      locale: const Locale('pt', 'BR'),
      home: AuthGate(
        authRepository: _authRepository,
        workspaceRepository: _workspaceRepository,
        vehicleRepository: _vehicleRepository,
        expenseRepository: _expenseRepository,
        fipeService: _fipeService,
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  final AuthRepository authRepository;
  final WorkspaceRepository workspaceRepository;
  final VehicleRepository vehicleRepository;
  final ExpenseRepository expenseRepository;
  final FipeService? fipeService;
  final String workspaceId;

  const AuthGate({
    super.key,
    required this.authRepository,
    required this.workspaceRepository,
    required this.vehicleRepository,
    required this.expenseRepository,
    this.fipeService,
    this.workspaceId = AppConstants.defaultWorkspaceId,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Stream<User?> _authStream;
  int _refreshKey = 0;
  String? _watchedUid;
  int _watchedRefreshKey = -1;
  Stream<bool>? _accessStream;

  @override
  void initState() {
    super.initState();
    _authStream = widget.authRepository.authStateChanges;
  }

  @override
  void didUpdateWidget(covariant AuthGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authRepository != widget.authRepository) {
      _authStream = widget.authRepository.authStateChanges;
    }
    if (oldWidget.workspaceRepository != widget.workspaceRepository ||
        oldWidget.workspaceId != widget.workspaceId) {
      _accessStream = null;
    }
  }

  Stream<bool> _getAccessStream(String uid) {
    if (_accessStream == null ||
        _watchedUid != uid ||
        _watchedRefreshKey != _refreshKey) {
      _watchedUid = uid;
      _watchedRefreshKey = _refreshKey;
      _accessStream = widget.workspaceRepository.watchUserAuthorization(
        workspaceId: widget.workspaceId,
        uid: uid,
      );
    }
    return _accessStream!;
  }

  void _triggerRefresh() {
    setState(() {
      _refreshKey++;
      _authStream = widget.authRepository.authStateChanges;
      _accessStream = null;
    });
  }

  Widget _buildConnectionError({
    required String message,
    bool showSignOut = false,
  }) {
    return Scaffold(
      backgroundColor: AppTheme.bgSurface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_off_outlined,
                        size: 44,
                        color: AppTheme.dangerRed,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Erro de conexão',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textMain,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Tentar novamente'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: _triggerRefresh,
                      ),
                      if (showSignOut) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.logout, size: 18),
                          label: const Text('Sair da conta'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: () => widget.authRepository.signOut(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, authSnapshot) {
        if (authSnapshot.hasError) {
          return _buildConnectionError(
            message: 'Não foi possível verificar sua sessão. Confira a internet e tente novamente.',
          );
        }

        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppTheme.bgSurface,
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final user = authSnapshot.data;
        if (user == null) {
          return LoginScreen(authRepository: widget.authRepository);
        }

        // Usuário logado: validar permissão de membro no workspace
        return StreamBuilder<bool>(
          key: ValueKey('${user.uid}_$_refreshKey'),
          stream: _getAccessStream(user.uid),
          builder: (context, accessSnapshot) {
            if (accessSnapshot.hasError) {
              return _buildConnectionError(
                message: 'Falha ao consultar sua autorização no servidor. Tente novamente em instantes.',
                showSignOut: true,
              );
            }

            if (accessSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: AppTheme.bgSurface,
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Verificando seu acesso...',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              );
            }

            final isAuthorized = accessSnapshot.data ?? false;

            if (!isAuthorized) {
              return UnauthorizedScreen(
                userUid: user.uid,
                userEmail: user.email,
                onRefresh: _triggerRefresh,
                authRepository: widget.authRepository,
              );
            }

            return HomeShell(
              workspaceId: widget.workspaceId,
              userUid: user.uid,
              userEmail: user.email,
              authRepository: widget.authRepository,
              vehicleRepository: widget.vehicleRepository,
              expenseRepository: widget.expenseRepository,
              fipeService: widget.fipeService,
            );
          },
        );
      },
    );
  }
}
