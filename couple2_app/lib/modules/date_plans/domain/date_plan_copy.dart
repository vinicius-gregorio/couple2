import 'package:couple2_app/core/core.dart';

import 'entities/date_plan.dart';

const dateWeekdays = <int, String>{
  DateTime.monday: 'Segunda',
  DateTime.tuesday: 'Terça',
  DateTime.wednesday: 'Quarta',
  DateTime.thursday: 'Quinta',
  DateTime.friday: 'Sexta',
  DateTime.saturday: 'Sábado',
  DateTime.sunday: 'Domingo',
};

/// MOVIES and TRAVEL items can open the date form. Other list types cannot.
bool listTypeSupportsDatePlan(String type) =>
    type == 'MOVIES' || type == 'TRAVEL';

String datePlanWhen(DateTime scheduledAt) {
  final local = scheduledAt.toLocal();
  final weekday = dateWeekdays[local.weekday] ?? '';
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$weekday $hh:$mm';
}

/// Home card line. The clock is the device timezone.
String nextDateHeadline(DatePlan plan) {
  return 'Próximo encontro: ${datePlanWhen(plan.scheduledAt)} — ${plan.title}';
}

String datePlanErrorMessage(int? statusCode, {bool linkingItem = false}) {
  switch (statusCode) {
    case 400:
      return 'Escolha um horário no futuro.';
    case 403:
      return 'Essa ação não é sua.';
    case 404:
      return 'Esse encontro não está mais aqui.';
    case 409:
      return 'Esse encontro mudou. Atualize e tente de novo.';
    case 422:
      return linkingItem
          ? 'Esse item não pode virar um encontro.'
          : 'Ainda não dá para marcar como feito.';
    default:
      return 'Não consegui salvar agora.';
  }
}

/// Offline failures name the network. Other HTTP statuses keep the date copy.
String datePlanFailureMessage(Object error, {bool linkingItem = false}) {
  if (isOfflineFailure(error)) return offlineUserMessage;
  if (error is CPLHttpException) {
    return datePlanErrorMessage(
      error.response?.statusCode,
      linkingItem: linkingItem,
    );
  }
  return userFacingError(error, fallback: 'Não consegui salvar agora.');
}
