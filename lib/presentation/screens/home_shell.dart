import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/expense_repository.dart';
import '../../data/repositories/vehicle_repository.dart';
import '../theme/app_theme.dart';
import 'stock/stock_screen.dart';
import 'summary/monthly_summary_screen.dart';

class HomeShell extends StatefulWidget {
  final String workspaceId;
  final String userUid;
  final String? userEmail;
  final AuthRepository authRepository;
  final VehicleRepository vehicleRepository;
  final ExpenseRepository expenseRepository;

  const HomeShell({
    super.key,
    this.workspaceId = AppConstants.defaultWorkspaceId,
    required this.userUid,
    this.userEmail,
    required this.authRepository,
    required this.vehicleRepository,
    required this.expenseRepository,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  void _showUserBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final initial = (widget.userEmail != null && widget.userEmail!.isNotEmpty)
            ? widget.userEmail![0].toUpperCase()
            : 'U';

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.accentSoft,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.accentBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.userEmail ?? 'Usuário Autenticado',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textMain,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Espaço de Trabalho: AutoSaldo (Principal)',
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.logout, size: 20),
                  label: const Text('Sair da Conta'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.dangerRed,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await widget.authRepository.signOut();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      StockScreen(
        workspaceId: widget.workspaceId,
        userUid: widget.userUid,
        userEmail: widget.userEmail,
        vehicleRepository: widget.vehicleRepository,
        expenseRepository: widget.expenseRepository,
      ),
      MonthlySummaryScreen(
        workspaceId: widget.workspaceId,
        vehicleRepository: widget.vehicleRepository,
        expenseRepository: widget.expenseRepository,
      ),
    ];

    final initial = (widget.userEmail != null && widget.userEmail!.isNotEmpty)
        ? widget.userEmail![0].toUpperCase()
        : 'U';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.accentBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.directions_car, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text(
              'AutoSaldo',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          // Avatar clicável do usuário
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: InkWell(
              onTap: _showUserBottomSheet,
              borderRadius: BorderRadius.circular(20),
              child: CircleAvatar(
                radius: 17,
                backgroundColor: const Color(0xFFE2E8F0),
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryDark,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.directions_car_outlined),
            selectedIcon: Icon(Icons.directions_car),
            label: 'Estoque',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Resumo',
          ),
        ],
      ),
    );
  }
}
