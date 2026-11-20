import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/expense_repository.dart';
import '../../data/repositories/vehicle_repository.dart';
import '../../data/services/fipe_service.dart';
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
  final FipeService? fipeService;

  const HomeShell({
    super.key,
    this.workspaceId = AppConstants.defaultWorkspaceId,
    required this.userUid,
    this.userEmail,
    required this.authRepository,
    required this.vehicleRepository,
    required this.expenseRepository,
    this.fipeService,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  late List<Widget> _screens;
  final FocusNode _stockSearchFocusNode = FocusNode();
  final ValueNotifier<int> _newVehicleTrigger = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _screens = _buildScreens();
  }

  @override
  void dispose() {
    _stockSearchFocusNode.dispose();
    _newVehicleTrigger.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceId != widget.workspaceId ||
        oldWidget.userUid != widget.userUid ||
        oldWidget.userEmail != widget.userEmail ||
        oldWidget.vehicleRepository != widget.vehicleRepository ||
        oldWidget.expenseRepository != widget.expenseRepository ||
        oldWidget.fipeService != widget.fipeService) {
      _screens = _buildScreens();
    }
  }

  List<Widget> _buildScreens() {
    return [
      StockScreen(
        workspaceId: widget.workspaceId,
        userUid: widget.userUid,
        userEmail: widget.userEmail,
        vehicleRepository: widget.vehicleRepository,
        expenseRepository: widget.expenseRepository,
        fipeService: widget.fipeService,
        searchFocusNode: _stockSearchFocusNode,
        newVehicleTrigger: _newVehicleTrigger,
      ),
      MonthlySummaryScreen(
        workspaceId: widget.workspaceId,
        userUid: widget.userUid,
        userEmail: widget.userEmail,
        vehicleRepository: widget.vehicleRepository,
        expenseRepository: widget.expenseRepository,
        fipeService: widget.fipeService,
      ),
    ];
  }

  String get _userInitial =>
      (widget.userEmail != null && widget.userEmail!.isNotEmpty)
          ? widget.userEmail![0].toUpperCase()
          : 'U';

  String get _userDisplayName {
    final rawName = (widget.userEmail != null && widget.userEmail!.contains('@'))
        ? widget.userEmail!.split('@')[0]
        : 'Vendedor';
    final cleanName =
        RegExp(r'^[\p{L}]+', unicode: true).stringMatch(rawName) ?? rawName;
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
                  'Loja: AutoSaldo (Principal)',
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
              if (ResponsiveBreakpoints.isTabletOrDesktop(context)) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: const Text(
                    'Atalhos: Ctrl+K buscar • Alt+1 Estoque • Alt+2 Resumo • Alt+N Novo veículo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
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
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
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
            Expanded(
              child: InkWell(
                onTap: _showUserModal,
                borderRadius: BorderRadius.circular(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppTheme.accentSoft,
                          child: Text(
                            _userInitial,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.accentBlue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            'Olá, $_userDisplayName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textMain,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Lado direito: Minha Conta
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
              child: Tooltip(
                message: isExpanded ? '' : 'Minha Conta',
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

    final bodyContent = IndexedStack(
      index: _currentIndex,
      children: _screens,
    );

    final scaffold = isDesktopOrTablet
        ? Scaffold(
            body: Row(
              children: [
                _buildDesktopSidebar(isExpandedSidebar),
                Expanded(child: bodyContent),
              ],
            ),
          )
        : Scaffold(
            body: Column(
              children: [
                _buildAppHeader(),
                Expanded(child: bodyContent),
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

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.digit1, alt: true): () {
          if (_currentIndex != 0) setState(() => _currentIndex = 0);
        },
        const SingleActivator(LogicalKeyboardKey.digit2, alt: true): () {
          if (_currentIndex != 1) setState(() => _currentIndex = 1);
        },
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
          if (_currentIndex != 0) setState(() => _currentIndex = 0);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_stockSearchFocusNode.canRequestFocus) {
              _stockSearchFocusNode.requestFocus();
            }
          });
        },
        const SingleActivator(LogicalKeyboardKey.keyN, alt: true): () {
          if (_currentIndex != 0) setState(() => _currentIndex = 0);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _newVehicleTrigger.value++;
          });
        },
      },
      child: Focus(
        autofocus: true,
        child: scaffold,
      ),
    );
  }
}
