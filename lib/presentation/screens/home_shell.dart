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

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Encerrar Sessão'),
        content: Text('Deseja realmente sair da conta ${widget.userEmail ?? ""}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await widget.authRepository.signOut();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      StockScreen(
        workspaceId: widget.workspaceId,
        userUid: widget.userUid,
        vehicleRepository: widget.vehicleRepository,
        expenseRepository: widget.expenseRepository,
      ),
      MonthlySummaryScreen(
        workspaceId: widget.workspaceId,
        vehicleRepository: widget.vehicleRepository,
        expenseRepository: widget.expenseRepository,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.accentBlue,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.directions_car, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text('AutoSaldo'),
          ],
        ),
        actions: [
          if (widget.userEmail != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.userEmail!,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Encerrar sessão',
            onPressed: _confirmSignOut,
          ),
          const SizedBox(width: 4),
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

