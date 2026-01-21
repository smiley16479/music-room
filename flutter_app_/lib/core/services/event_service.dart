import '../../config/app_config.dart';
import '../models/index.dart';
import 'api_service.dart';

/// Event Service - manages event operations
class EventService {
  final ApiService apiService;

  EventService({required this.apiService});

  /// Get all events
  Future<List<Event>> getEvents({
    int page = 1,
    int limit = 20,
  }) async {
    final params = {
      'page': page.toString(),
      'limit': limit.toString(),
    };

    final queryString = params.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');
    
    final endpoint = '${AppConfig.eventsEndpoint}?$queryString';
    final response = await apiService.get(endpoint);

    // Handle both wrapped response (with 'data' field) and direct data response
    List<dynamic> dataList;
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      dataList = response['data'] as List;
    } else if (response is List) {
      dataList = response;
    } else {
      throw Exception('Invalid response format: expected List but got ${response.runtimeType}');
    }
    
    return dataList.map((e) => Event.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Get my events
  Future<List<Event>> getMyEvents({
    int page = 1,
    int limit = 20,
  }) async {
    final params = {
      'page': page.toString(),
      'limit': limit.toString(),
    };

    final queryString = params.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');
    
    final endpoint = '${AppConfig.eventsEndpoint}/my-event?$queryString';
    final response = await apiService.get(endpoint);

    // Handle both wrapped response (with 'data' field) and direct data response
    List<dynamic> dataList;
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      dataList = response['data'] as List;
    } else if (response is List) {
      dataList = response;
    } else {
      throw Exception('Invalid response format: expected List but got ${response.runtimeType}');
    }
    
    return dataList.map((e) => Event.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Get event by ID
  Future<Event> getEvent(String id) async {
    final response = await apiService.get('${AppConfig.eventsEndpoint}/$id');
    
    print('Get event response: $response');
    print('Response type: ${response.runtimeType}');

    // Handle both wrapped response (with 'data' field) and direct data response
    Map<String, dynamic> eventData;
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      eventData = response['data'] as Map<String, dynamic>;
    } else if (response is Map<String, dynamic>) {
      eventData = response;
    } else {
      throw Exception('Invalid response format: expected Map but got ${response.runtimeType}');
    }
    
    try {
      return Event.fromJson(eventData);
    } catch (e) {
      print('Error parsing Event.fromJson for getEvent: $e');
      print('Event data: $eventData');
      rethrow;
    }
  }

  /// Create new event
  Future<Event> createEvent({
    required String name,
    String? description,
    required DateTime eventDate,
    DateTime? eventEndDate,
    String? locationName,
    String? visibility,
  }) async {
    final response = await apiService.post(
      AppConfig.eventsEndpoint,
      body: {
        'name': name,
        if (description != null && description.isNotEmpty) 'description': description,
        'eventDate': eventDate.toIso8601String(),
        if (eventEndDate != null) 'eventEndDate': eventEndDate.toIso8601String(),
        if (locationName != null && locationName.isNotEmpty) 'locationName': locationName,
        if (visibility != null) 'visibility': visibility,
      },
    );

    print('Event creation response: $response');
    print('Response type: ${response.runtimeType}');

    // Handle both wrapped response (with 'data' field) and direct data response
    Map<String, dynamic> eventData;
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      eventData = response['data'] as Map<String, dynamic>;
    } else if (response is Map<String, dynamic>) {
      eventData = response;
    } else {
      throw Exception('Invalid response format: expected Map but got ${response.runtimeType}');
    }
    
    try {
      return Event.fromJson(eventData);
    } catch (e) {
      print('Error parsing Event.fromJson: $e');
      print('Event data: $eventData');
      rethrow;
    }
  }

  /// Update event
  Future<Event> updateEvent(
    String id, {
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    String? location,
    bool? isPublic,
  }) async {
    final response = await apiService.patch(
      '${AppConfig.eventsEndpoint}/$id',
      body: {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
        if (location != null) 'location': location,
        if (isPublic != null) 'isPublic': isPublic,
      },
    );

    // Handle both wrapped response (with 'data' field) and direct data response
    Map<String, dynamic> eventData;
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      eventData = response['data'] as Map<String, dynamic>;
    } else if (response is Map<String, dynamic>) {
      eventData = response;
    } else {
      throw Exception('Invalid response format: expected Map but got ${response.runtimeType}');
    }
    
    return Event.fromJson(eventData);
  }

  /// Delete event
  Future<void> deleteEvent(String id) async {
    await apiService.delete('${AppConfig.eventsEndpoint}/$id');
  }
}
