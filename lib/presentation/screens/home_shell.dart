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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final initial = (widget.userEmail != null && widget.userEmail!.isNotEmpty)
            ? widget.userEmail![0].toUpperCase()
            : 'U';

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                CircleAvatar(
                  radius: 34,
                  backgroundColor: AppTheme.accentSoft,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.accentBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.userEmail ?? 'Usuário Autenticado',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textMain,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Workspace: AutoSaldo (Principal)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'AutoSaldo Web App • v1.2.1',
                  style: TextStyle(fontSize: 11, color: AppTheme.textLight),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.logout, size: 20),
                  label: const Text('Sair da Conta'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.dangerRed,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

  Widget _buildAppHeader() {
    final initial = (widget.userEmail != null && widget.userEmail!.isNotEmpty)
        ? widget.userEmail![0].toUpperCase()
        : 'U';

    final rawName = (widget.userEmail != null && widget.userEmail!.contains('@'))
        ? widget.userEmail!.split('@')[0]
        : 'Vendedor';
    final cleanName = RegExp(r'^[a-zA-Z]+').stringMatch(rawName) ?? rawName;
    final displayName = cleanName.isNotEmpty
        ? cleanName[0].toUpperCase() + cleanName.substring(1).toLowerCase()
        : 'Vendedor';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Perfil clicável estilo App
            InkWell(
              onTap: _showUserBottomSheet,
              borderRadius: BorderRadius.circular(24),
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFEFF6FF),
                        child: Text(
                          initial,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Olá, $displayName',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      Row(
                        children: const [
                          Text(
                            'AutoSaldo',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          Text(
                            ' • Garagem',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Lado direito: badge de versão e menu
            Row(
              children: [
                InkWell(
                  onTap: _showUserBottomSheet,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.check_circle, size: 13, color: Color(0xFF10B981)),
                        SizedBox(width: 5),
                        Text(
                          'v1.2 App',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.more_horiz_rounded, size: 24, color: Color(0xFF334155)),
                  tooltip: 'Minha Conta',
                  onPressed: _showUserBottomSheet,
                ),
              ],
            ),
          ],
        ),
      ),
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

    return Scaffold(
      body: Column(
        children: [
          _buildAppHeader(),
          Expanded(child: screens[_currentIndex]),
        ],
      ),
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
