import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/expense_repository.dart';
import '../../data/repositories/vehicle_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_layout.dart';
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

  String get _userInitial =>
      (widget.userEmail != null && widget.userEmail!.isNotEmpty)
          ? widget.userEmail![0].toUpperCase()
          : 'U';

  String get _userDisplayName {
    final rawName = (widget.userEmail != null && widget.userEmail!.contains('@'))
        ? widget.userEmail!.split('@')[0]
        : 'Vendedor';
    final cleanName = RegExp(r'^[a-zA-Z]+').stringMatch(rawName) ?? rawName;
    return cleanName.isNotEmpty
        ? cleanName[0].toUpperCase() + cleanName.substring(1).toLowerCase()
        : 'Vendedor';
  }

  void _showUserModal() {
    showAdaptiveModalSheet(
      context: context,
      builder: (ctx) {
        return AdaptiveModalContainer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: AppTheme.accentSoft,
                child: Text(
                  _userInitial,
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Text(
                  'AutoSaldo App • Versão 1.3.0',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2563EB),
                  ),
                ),
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
        );
      },
    );
  }

  Widget _buildAppHeader() {
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
              onTap: _showUserModal,
              borderRadius: BorderRadius.circular(24),
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFEFF6FF),
                        child: Text(
                          _userInitial,
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
                  const SizedBox(width: 12),
                  Text(
                    'Olá, $_userDisplayName',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
            ),

            // Lado direito: menu de 3 pontos
            IconButton(
              icon: const Icon(Icons.more_horiz_rounded, size: 26, color: Color(0xFF334155)),
              tooltip: 'Minha Conta',
              onPressed: _showUserModal,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopSidebar(bool isExpanded) {
    return Container(
      width: isExpanded ? 240 : 80,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: AppTheme.borderSubtle, width: 1),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment:
              isExpanded ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
          children: [
            // Marca
            Padding(
              padding: EdgeInsets.fromLTRB(
                isExpanded ? 20 : 12,
                20,
                isExpanded ? 20 : 12,
                20,
              ),
              child: Row(
                mainAxisAlignment:
                    isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryDark,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.directions_car,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  if (isExpanded) ...[
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AutoSaldo',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primaryDark,
                              letterSpacing: -0.4,
                            ),
                          ),
                          Text(
                            'Principal',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.borderSubtle),
            const SizedBox(height: 12),

            // Itens de navegação
            _buildSidebarItem(
              index: 0,
              icon: Icons.directions_car_outlined,
              selectedIcon: Icons.directions_car,
              label: 'Estoque',
              isExpanded: isExpanded,
            ),
            const SizedBox(height: 4),
            _buildSidebarItem(
              index: 1,
              icon: Icons.bar_chart_outlined,
              selectedIcon: Icons.bar_chart,
              label: 'Resumo',
              isExpanded: isExpanded,
            ),

            const Spacer(),
            const Divider(height: 1, color: AppTheme.borderSubtle),

            // Conta / Usuário no rodapé da barra lateral
            Padding(
              padding: EdgeInsets.all(isExpanded ? 12 : 10),
              child: InkWell(
                onTap: _showUserModal,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isExpanded ? 10 : 6,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Row(
                    mainAxisAlignment: isExpanded
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: AppTheme.accentSoft,
                        child: Text(
                          _userInitial,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.accentBlue,
                          ),
                        ),
                      ),
                      if (isExpanded) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _userDisplayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textMain,
                                ),
                              ),
                              Text(
                                widget.userEmail ?? 'Minha Conta',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.more_vert,
                          size: 18,
                          color: AppTheme.textMuted,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required bool isExpanded,
  }) {
    final isSelected = _currentIndex == index;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isExpanded ? 12 : 10),
      child: Material(
        color: isSelected ? AppTheme.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _currentIndex = index),
          child: Tooltip(
            message: isExpanded ? '' : label,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isExpanded ? 14 : 0,
                vertical: 12,
              ),
              child: Row(
                mainAxisAlignment: isExpanded
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  Icon(
                    isSelected ? selectedIcon : icon,
                    size: 22,
                    color: isSelected ? AppTheme.accentBlue : AppTheme.textMuted,
                  ),
                  if (isExpanded) ...[
                    const SizedBox(width: 12),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? AppTheme.accentBlue : AppTheme.textMain,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopOrTablet = ResponsiveBreakpoints.isTabletOrDesktop(context);
    final isExpandedSidebar = ResponsiveBreakpoints.isDesktop(context);

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

    if (isDesktopOrTablet) {
      return Scaffold(
        body: Row(
          children: [
            _buildDesktopSidebar(isExpandedSidebar),
            Expanded(child: screens[_currentIndex]),
          ],
        ),
      );
    }

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
