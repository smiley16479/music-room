import 'package:flutter/material.dart';

import '../models/index.dart';
import '../services/index.dart';

/// Event Provider - manages event state
class EventProvider extends ChangeNotifier {
  final EventService eventService;

  List<Event> _events = [];
  List<Event> _myEvents = [];
  Event? _currentEvent;
  bool _isLoading = false;
  String? _error;

  EventProvider({required this.eventService});

  // Getters
  List<Event> get events => _events;
  List<Event> get myEvents => _myEvents;
  Event? get currentEvent => _currentEvent;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load all events
  Future<void> loadEvents({int page = 1, int limit = 20}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _events = await eventService.getEvents(
        page: page,
        limit: limit,
      );
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load my events
  Future<void> loadMyEvents({int page = 1, int limit = 20}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _myEvents = await eventService.getMyEvents(
        page: page,
        limit: limit,
      );
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load event details
  Future<void> loadEventDetails(String eventId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentEvent = await eventService.getEvent(eventId);
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Create event
  Future<bool> createEvent({
    required String name,
    String? description,
    required DateTime eventDate,
    DateTime? eventEndDate,
    String? locationName,
    String? visibility,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final event = await eventService.createEvent(
        name: name,
        description: description,
        eventDate: eventDate,
        eventEndDate: eventEndDate,
        locationName: locationName,
        visibility: visibility,
      );
      _myEvents.add(event);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Update event
  Future<bool> updateEvent(
    String id, {
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    String? location,
    bool? isPublic,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updated = await eventService.updateEvent(
        id,
        title: title,
        description: description,
        startDate: startDate,
        endDate: endDate,
        location: location,
        isPublic: isPublic,
      );

      final index = _myEvents.indexWhere((e) => e.id == id);
      if (index != -1) {
        _myEvents[index] = updated;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Delete event
  Future<bool> deleteEvent(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await eventService.deleteEvent(id);
      _myEvents.removeWhere((e) => e.id == id);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
