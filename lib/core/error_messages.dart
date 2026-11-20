/// Traduz exceções técnicas (Firebase, rede, HTTP) em mensagens claras para usuários finais.
class ErrorMessages {
  static const String defaultFallback =
      'Não foi possível concluir a operação. Tente novamente em instantes.';

  /// Retorna uma mensagem amigável em português para exibição na UI.
  static String friendly(
    Object error, {
    String fallback = defaultFallback,
  }) {
    var raw = error.toString().trim();
    if (raw.startsWith('Exception: ')) {
      raw = raw.substring('Exception: '.length).trim();
    }
    if (raw.isEmpty) return fallback;

    final lower = raw.toLowerCase();

    if (lower.contains('permission-denied') ||
        lower.contains('missing or insufficient permissions')) {
      return 'Você não tem permissão para realizar esta ação.';
    }

    if (lower.contains('unavailable') ||
        lower.contains('network') ||
        lower.contains('socketexception') ||
        lower.contains('timeoutexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('deadline-exceeded') ||
        lower.contains('clientexception')) {
      return 'Sem conexão com a internet ou servidor indisponível. Verifique seu sinal e tente novamente.';
    }

    if (lower.contains('firebase') ||
        lower.contains('cloud_firestore') ||
        raw.contains('[')) {
      return fallback;
    }

    return raw;
  }
}
