import 'package:flutter/material.dart';

class ResponsiveBreakpoints {
  static const double modalDialog = 600;
  static const double tablet = 768;
  static const double detailTwoColumn = 960;
  static const double desktop = 1040;
  static const double wideGrid = 1120;
  static const double maxContentWidth = 1200;

  static bool isTabletOrDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktop;

  static bool useDialogModals(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= modalDialog;
}

/// Abre como BottomSheet em dispositivos móveis (< 600px) e como Dialog
/// centralizado em telas maiores (>= 600px), preservando o fluxo mobile.
Future<T?> showAdaptiveModalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  if (ResponsiveBreakpoints.useDialogModals(context)) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: builder(ctx),
        ),
      ),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: builder,
  );
}

/// Container padrão dos formulários modais (Expense, Sale, Payment, Price):
/// arredondamento completo em Dialog no desktop e sheet no topo no mobile.
class AdaptiveModalContainer extends StatelessWidget {
  final Widget child;

  const AdaptiveModalContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDialog = ResponsiveBreakpoints.useDialogModals(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isDialog
            ? BorderRadius.circular(20)
            : const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: isDialog ? 24 : 20,
        right: isDialog ? 24 : 20,
        top: isDialog ? 20 : 12,
        bottom: isDialog ? 24 : MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!isDialog)
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
