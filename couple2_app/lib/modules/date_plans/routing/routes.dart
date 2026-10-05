abstract final class DatePlanRoutes {
  static const list = '/dates';
  static const create = '/dates/new';

  static String detail(String id) => '/dates/$id';
}
