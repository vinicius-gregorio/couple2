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
  return 'Próximo date: ${datePlanWhen(plan.scheduledAt)} — ${plan.title}';
}

String datePlanErrorMessage(int? statusCode, {bool linkingItem = false}) {
  switch (statusCode) {
    case 400:
      return 'Escolha um horário no futuro.';
    case 403:
      return 'Essa ação não é sua.';
    case 404:
      return 'Esse date não está mais aqui.';
    case 409:
      return 'Esse date mudou. Atualize e tente de novo.';
    case 422:
      return linkingItem
          ? 'Esse item não pode virar um date.'
          : 'Ainda não dá para marcar como feito.';
    default:
      return 'Não consegui salvar agora.';
  }
}
