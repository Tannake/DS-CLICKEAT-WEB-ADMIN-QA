/// The `pagination` block `reports/sales-export`/`reports/orders-export` return
/// when `all_records` is omitted/false (100 rows per page). Absent
/// entirely when `all_records=true` is sent, since the backend then returns
/// every matching row in one shot with nothing to paginate.
class ReportPagination {
  final int currentPage;
  final int pageSize;
  final int totalRecords;
  final int totalPages;

  const ReportPagination({
    required this.currentPage,
    required this.pageSize,
    required this.totalRecords,
    required this.totalPages,
  });

  factory ReportPagination.fromJson(Map<String, dynamic> json) {
    return ReportPagination(
      currentPage: (json['current_page'] as num?)?.toInt() ?? 1,
      pageSize: (json['page_size'] as num?)?.toInt() ?? 0,
      totalRecords: (json['total_records'] as num?)?.toInt() ?? 0,
      totalPages: (json['total_pages'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A page of CSV-detail rows plus the pagination metadata that came with
/// it — `pagination` is null when the request asked for `allRecords: true`.
class PagedRows<T> {
  final List<T> rows;
  final ReportPagination? pagination;

  const PagedRows({required this.rows, this.pagination});
}
