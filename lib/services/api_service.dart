import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import 'storage_service.dart';

class ApiService {
  final Dio _dio;
  final StorageService _storageService;

  ApiService(this._storageService) : _dio = Dio() {
    _dio.options.baseUrl = ApiConstants.baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 15);

    // Request & Auth token Interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _storageService.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          options.headers['Accept'] = 'application/json';
          return handler.next(options);
        },
        onError: (DioException error, handler) {
          // Auto log-out on token expiration / unauthorized
          if (error.response?.statusCode == 401) {
            _storageService.clearAll();
          }
          return handler.next(error);
        },
      ),
    );
  }

  // Get request
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters, options: options);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Post request
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post(path, data: data, queryParameters: queryParameters, options: options);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Put request
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.put(path, data: data, queryParameters: queryParameters, options: options);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Delete request
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.delete(path, data: data, queryParameters: queryParameters, options: options);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException error) {
    // Print full error details to the debug console for easy local troubleshooting
    debugPrint("------------------- API ERROR DETAILS -------------------");
    debugPrint("Type: ${error.type}");
    debugPrint("Message: ${error.message}");
    debugPrint("Error detail: ${error.error}");
    debugPrint("Request path: ${error.requestOptions.path}");
    if (error.response != null) {
      debugPrint("Status Code: ${error.response?.statusCode}");
      debugPrint("Response Data: ${error.response?.data}");
    }
    debugPrint("---------------------------------------------------------");

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Please check your internet connectivity.';
    }
    
    if (error.response != null) {
      final data = error.response?.data;
      if (data is Map && data.containsKey('message')) {
        return data['message'].toString();
      }
      return 'Server error (${error.response?.statusCode}). Please try again.';
    }

    return 'An unexpected network error occurred: ${error.message ?? error.error ?? "No connection"}. Please try again.';
  }
}
