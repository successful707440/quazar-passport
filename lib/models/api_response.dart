class ApiResponse {
  final String status;
  final dynamic data;
  final String? error;

  const ApiResponse({
    required this.status,
    this.data,
    this.error,
  });

  bool get isSuccess => status == 'success';

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      status: json['status'] as String? ?? 'error',
      data: json['data'],
      error: json['error'] as String?,
    );
  }
}
