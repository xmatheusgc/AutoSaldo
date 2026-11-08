import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/constants.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/expense_repository.dart';
import 'data/repositories/vehicle_repository.dart';
import 'data/repositories/workspace_repository.dart';
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

  @override
  void initState() {
    super.initState();
    _authRepository = AuthRepository();
    _workspaceRepository = WorkspaceRepository();
    _vehicleRepository = VehicleRepository();
    _expenseRepository = ExpenseRepository();
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
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  final AuthRepository authRepository;
  final WorkspaceRepository workspaceRepository;
  final VehicleRepository vehicleRepository;
  final ExpenseRepository expenseRepository;
  final String workspaceId;

  const AuthGate({
    super.key,
    required this.authRepository,
    required this.workspaceRepository,
    required this.vehicleRepository,
    required this.expenseRepository,
    this.workspaceId = AppConstants.defaultWorkspaceId,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  int _refreshKey = 0;

  void _triggerRefresh() {
    setState(() {
      _refreshKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: widget.authRepository.authStateChanges,
      builder: (context, authSnapshot) {
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
          stream: widget.workspaceRepository.watchUserAuthorization(
            workspaceId: widget.workspaceId,
            uid: user.uid,
          ),
          builder: (context, accessSnapshot) {
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
                        'Verificando autorização no espaço de trabalho...',
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
            );
          },
        );
      },
    );
  }
}
