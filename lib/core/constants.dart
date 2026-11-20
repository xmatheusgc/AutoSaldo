class AppConstants {
  static const String defaultWorkspaceId = 'default';

  // Alertas de tempo em estoque (dias)
  static const int stagnantStockDaysThreshold = 45;
  static const int criticalStockDaysThreshold = 60;

  // Situação da documentação
  static const String docStatusPendingCheck = 'pending_check';
  static const String docStatusUpToDate = 'up_to_date';
  static const String docStatusWithIssue = 'with_issue';

  static const Map<String, String> docStatusLabels = {
    docStatusPendingCheck: 'A verificar',
    docStatusUpToDate: 'Em dia',
    docStatusWithIssue: 'Com pendência',
  };

  // Categorias de despesas
  static const String expenseCategoryWorkshop = 'workshop';
  static const String expenseCategoryParts = 'parts';
  static const String expenseCategoryDocumentation = 'documentation';
  static const String expenseCategoryTransport = 'transport';
  static const String expenseCategoryAdvertising = 'advertising';
  static const String expenseCategoryCommission = 'commission';
  static const String expenseCategoryCarWash = 'car_wash';
  static const String expenseCategoryOther = 'other';

  static const Map<String, String> expenseCategoryLabels = {
    expenseCategoryWorkshop: 'Oficina / Mecânica',
    expenseCategoryParts: 'Peças',
    expenseCategoryDocumentation: 'Documentação / Despachante',
    expenseCategoryTransport: 'Transporte / Guincho',
    expenseCategoryAdvertising: 'Anúncio',
    expenseCategoryCommission: 'Comissão',
    expenseCategoryCarWash: 'Lava-jato',
    expenseCategoryOther: 'Outros',
  };

  // Status de despesas e pagamentos
  static const String statusValid = 'valid';
  static const String statusReverted = 'reverted';

  // Status financeiro da venda
  static const String paymentStatusSettled = 'settled'; // Quitado
  static const String paymentStatusPartial = 'partial'; // Parcial
  static const String paymentStatusOpen = 'open'; // Em aberto

  static const Map<String, String> paymentStatusLabels = {
    paymentStatusSettled: 'Quitado',
    paymentStatusPartial: 'Parcial',
    paymentStatusOpen: 'Em aberto',
  };
}

