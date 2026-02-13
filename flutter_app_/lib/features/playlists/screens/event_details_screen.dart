import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/event.dart';
import '../../../core/providers/index.dart';
import '../../../core/services/index.dart';
import '../../../core/navigation/route_observer.dart';
import '../widgets/invite_friends_dialog.dart';
import 'playlist_details_screen.dart';
import '../widgets/mini_player_scaffold.dart';

/// Event Details screen with full edit capabilities
class EventDetailsScreen extends StatefulWidget {
  final String eventId;

  const EventDetailsScreen({super.key, required this.eventId});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> with RouteAware {
  ModalRoute<dynamic>? _modalRoute;
  WebSocketService? _wsService;
  bool _isEditMode = false;
  Event? _localEvent; // Local copy to avoid provider being overwritten
  bool _hasJoinedRoom = false;
  bool _hasLoadedEvent = false;

  // Connected users currently in the event detail / playlist rooms
  List<Map<String, dynamic>> _connectedUsers = [];

  // Text Controllers
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationNameController;
  late TextEditingController _playlistNameController;
  late TextEditingController _radiusController;
  late TextEditingController _latitudeController;
  late TextEditingController _longitudeController;

  // Geolocation
  double? _latitude;
  double? _longitude;

  // Form state
  late EventType? _selectedType;
  late EventVisibility? _selectedVisibility;
  late EventLicenseType? _selectedLicenseType;
  late bool _votingEnabled;
  late DateTime? _selectedEventDate;
  late DateTime? _selectedStartDate;
  late DateTime? _selectedEndDate;
  late DateTime? _selectedVotingStartTime;
  late DateTime? _selectedVotingEndTime;
  late String? _selectedPlaylistId;

  @override
  void initState() {
    super.initState();
    _initControllers();

    // Load event and join room after the first frame to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasLoadedEvent) {
        _hasLoadedEvent = true;
        _loadEvent();
        _joinEventDetailRoom();
      }
    });
  }

  void _initControllers() {
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _locationNameController = TextEditingController();
    _playlistNameController = TextEditingController();
    _radiusController = TextEditingController();
    _latitudeController = TextEditingController();
    _longitudeController = TextEditingController();

    _selectedType = null;
    _selectedVisibility = null;
    _selectedLicenseType = null;
    _votingEnabled = true;
    _selectedEventDate = null;
    _selectedStartDate = null;
    _selectedEndDate = null;
    _selectedVotingStartTime = null;
    _selectedVotingEndTime = null;
    _selectedPlaylistId = null;
  }

  void _joinEventDetailRoom() {
    if (_hasJoinedRoom) return;

    try {
      final ws = _wsService ?? context.read<WebSocketService>();
      _wsService ??= ws;
      ws.joinEventDetail(widget.eventId);
      _hasJoinedRoom = true;

      // Receive the full list of currently connected users when joining
      ws.on('current-participants-detail', (data) {
        if (mounted) {
          final participants = data['participants'] as List<dynamic>? ?? [];
          setState(() {
            _connectedUsers = participants
                .map((p) => Map<String, dynamic>.from(p as Map))
                .toList();
          });
          debugPrint('📋 Received ${_connectedUsers.length} current detail participants');
        }
      });

      // Listen for users joining/leaving the detail room
      ws.on('user-joined-detail', (data) {
        if (mounted) {
          final userId = data['userId'] as String?;
          if (userId == null) return;
          debugPrint('📋 User joined event detail: ${data['displayName']}');
          setState(() {
            // Avoid duplicates
            _connectedUsers.removeWhere((u) => u['userId'] == userId);
            _connectedUsers.add(Map<String, dynamic>.from(data as Map));
          });
        }
      });

      ws.on('user-left-detail', (data) {
        if (mounted) {
          final userId = data['userId'] as String?;
          if (userId == null) return;
          debugPrint('📋 User left event detail: ${data['displayName']}');
          setState(() {
            _connectedUsers.removeWhere((u) => u['userId'] == userId);
          });
        }
      });
    } catch (e) {
      debugPrint('Error joining event detail room: $e');
    }
  }

  void _leaveEventDetailRoom() {
    try {
      final ws = _wsService ?? context.read<WebSocketService>();
      ws.leaveEventDetail(widget.eventId);

      // Clean up listeners
      ws.off('user-joined-detail');
      ws.off('user-left-detail');
      ws.off('current-participants-detail');
      _hasJoinedRoom = false;
    } catch (e) {
      debugPrint('Error leaving event detail room: $e');
    }
  }

  @override
  void dispose() {
    // Safely leave room using cached websocket service (avoid context in dispose)
    try {
      if (_wsService != null) {
        _wsService!.leaveEventDetail(widget.eventId);
        _wsService!.off('user-joined-detail');
        _wsService!.off('user-left-detail');
        _wsService!.off('current-participants-detail');
        _hasJoinedRoom = false;
      }
    } catch (e) {
      debugPrint('Error leaving event detail room from dispose: $e');
    }

    // Unsubscribe from route observer using stored reference (safe in dispose)
    try {
      if (_modalRoute != null) {
        routeObserver.unsubscribe(this);
      }
    } catch (_) {}
    _nameController.dispose();
    _descriptionController.dispose();
    _locationNameController.dispose();
    _playlistNameController.dispose();
    _radiusController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route changes so we can leave the socket room when the
    // screen is no longer visible (covered or popped)
    _modalRoute = ModalRoute.of(context);
    if (_modalRoute != null) {
      routeObserver.subscribe(this, _modalRoute!);
    }
    // Cache websocket service to avoid using context in dispose
    try {
      _wsService ??= context.read<WebSocketService>();
    } catch (_) {}
  }

  @override
  void didPush() {
    // Screen was just pushed — ensure we're joined
    _joinEventDetailRoom();
  }

  @override
  void didPopNext() {
    // Returned to this screen — re-join room if needed
    _joinEventDetailRoom();
  }

  @override
  void didPushNext() {
    // Another route was pushed on top (e.g., dialog or playlist details)
    // Don't leave here - let dispose handle cleanup when truly navigating away
    debugPrint('📋 Route pushed on top, staying in detail room');
  }

  Future<void> _loadEvent() async {
    final eventProvider = context.read<EventProvider>();
    await eventProvider.loadEventDetails(widget.eventId);
    // Store local copy to avoid it being overwritten
    if (mounted && eventProvider.currentEvent != null) {
      setState(() {
        _localEvent = eventProvider.currentEvent;
      });
    }
  }

  void _navigateToPlaylist(BuildContext context, String eventId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaylistDetailsScreen(playlistId: eventId),
      ),
    );
  }

  void _toggleEditMode(Event event) {
    _nameController.text = event.name;
    _descriptionController.text = event.description ?? '';
    _locationNameController.text = event.locationName ?? '';
    _playlistNameController.text = event.playlistName ?? '';
    _radiusController.text = event.locationRadius?.toString() ?? '';
    _latitudeController.text = event.latitude?.toString() ?? '';
    _longitudeController.text = event.longitude?.toString() ?? '';

    setState(() {
      _selectedType = event.type;
      _selectedVisibility = event.visibility;
      _selectedLicenseType = event.licenseType;
      _votingEnabled = event.votingEnabled ?? true;
      _selectedEventDate = event.eventDate;
      _selectedStartDate = event.startDate;
      _selectedEndDate = event.endDate;
      _selectedVotingStartTime = event.votingStartTime != null
          ? _parseTimeString(event.votingStartTime!)
          : null;
      _selectedVotingEndTime = event.votingEndTime != null
          ? _parseTimeString(event.votingEndTime!)
          : null;
      _latitude = event.latitude;
      _longitude = event.longitude;
      _isEditMode = !_isEditMode;
    });
  }

  /// Parse voting time string (HH:MM) to DateTime
  DateTime _parseTimeString(String timeString) {
    try {
      final parts = timeString.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      return DateTime(2000, 1, 1, hour, minute);
    } catch (e) {
      return DateTime(2000, 1, 1, 0, 0);
    }
  }

  /// Convert DateTime to HH:MM format for backend
  String _formatTimeToString(DateTime? dateTime) {
    if (dateTime == null) return '';
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Get display name for any enum (just the part after the last dot)
  String _getEnumLabel(dynamic enumValue) {
    return enumValue.toString().split('.').last;
  }

  /// Convert enum to its JSON value
  String? _enumToJsonValue(dynamic enumValue) {
    if (enumValue == null) return null;
    // The enum's toJson value based on @JsonValue annotation
    if (enumValue is EventType) {
      // json_serializable will use the @JsonValue
      final jsonValue = enumValue.toString().split('.').last;
      // Convert camelCase to snake_case
      return jsonValue.replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'),
        (m) => '${m.group(1)}_${m.group(2)}'.toLowerCase(),
      );
    } else if (enumValue is EventVisibility || enumValue is EventLicenseType) {
      // These are already lowercase
      return enumValue.toString().split('.').last;
    }
    return null;
  }

  /// Geocode a place name to get coordinates
  Future<void> _geocodeLocation() async {
    if (_locationNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a location name')),
      );
      return;
    }

    final geocodingService = GeocodingService();
    final coords = await geocodingService.getCoordinatesFromPlace(
      _locationNameController.text,
    );

    if (coords != null) {
      setState(() {
        _latitude = coords['latitude'];
        _longitude = coords['longitude'];
        _latitudeController.text = _latitude.toString();
        _longitudeController.text = _longitude.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Location found: ${_latitude?.toStringAsFixed(4)}, ${_longitude?.toStringAsFixed(4)}',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Location not found')));
    }
  }

  Future<void> _saveEvent(EventProvider eventProvider) async {
    final int? radius =
        (_selectedLicenseType == EventLicenseType.locationBased &&
            _radiusController.text.isNotEmpty)
        ? int.tryParse(_radiusController.text)
        : null;
    final success = await eventProvider.updateEvent(
      widget.eventId,
      name: _nameController.text,
      description: _descriptionController.text,
      locationName: _locationNameController.text.isNotEmpty
          ? _locationNameController.text
          : null,
      playlistName: _playlistNameController.text.isNotEmpty
          ? _playlistNameController.text
          : null,
      votingStartTime: _formatTimeToString(_selectedVotingStartTime),
      eventDate: _selectedEventDate,
      startDate: _selectedStartDate,
      endDate: _selectedEndDate,
      selectedPlaylistId: _selectedPlaylistId,
      visibility: _selectedVisibility != null
        ? (_selectedVisibility == EventVisibility.public ? 'public' : 'private')
        : null,
      licenseType: _selectedLicenseType != null
        ? (_selectedLicenseType == EventLicenseType.invited
          ? 'invited'
          : (_selectedLicenseType == EventLicenseType.locationBased
            ? 'location_based'
            : 'none'))
        : null,
      locationRadius: radius,
      latitude: _latitude,
      longitude: _longitude,
    );

    if (mounted) {
      if (success) {
        // Reload event to get updated data
        await _loadEvent();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event updated successfully')),
        );
        setState(() {
          _isEditMode = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${eventProvider.error}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MiniPlayerScaffold(
      child: Consumer2<EventProvider, AuthProvider>(
        builder: (context, eventProvider, authProvider, _) {
          if (eventProvider.isLoading) {
            return Scaffold(
              appBar: AppBar(title: const Text('Event Details')),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          if (eventProvider.error != null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Event Details')),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading event',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        eventProvider.error ?? 'Unknown error',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final event = eventProvider.currentEvent;
          if (event == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Event Details')),
              body: const Center(child: Text('Event not found')),
            );
          }

          final currentUser = authProvider.currentUser;
          final isAdmin = currentUser?.id == event.creatorId;

          return Scaffold(
            appBar: AppBar(
              title: Text(event.name),
              elevation: 0,
              actions: [
                if (isAdmin)
                  IconButton(
                    icon: Icon(_isEditMode ? Icons.close : Icons.edit),
                    onPressed: () => _toggleEditMode(event),
                    tooltip: _isEditMode ? 'Cancel' : 'Edit Event',
                  ),
              ],
            ),
            body: _isEditMode
                ? _buildEditForm(eventProvider, event)
                : _buildViewMode(context, event, isAdmin, eventProvider),
          );
        },
      ),
    );
  }

  Widget _buildEditForm(EventProvider eventProvider, Event event) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Edit Event', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),

          // Basic Info
          _buildSectionTitle('Basic Information'),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Event Name *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.event),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.description),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),

          // Location Info
          _buildSectionTitle('Location Information'),
          TextField(
            controller: _locationNameController,
            decoration: InputDecoration(
              labelText: 'Location Name (City)',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.location_on),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                tooltip: 'Find coordinates',
                onPressed: _geocodeLocation,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Latitude & Longitude côte à côte
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _latitudeController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Latitude',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.public),
                  ),
                  readOnly: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _longitudeController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Longitude',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.public),
                  ),
                  readOnly: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Event Type & Settings
          _buildSectionTitle('Event Type'),
          /* DropdownButton<EventType>( ⚠️ Change Private/public Disabled for now
            isExpanded: true,
            value: _selectedType,
            hint: const Text('Select Event Type'),
            onChanged: (EventType? newValue) {
              setState(() => _selectedType = newValue);
            },
            items: EventType.values.map((EventType type) {
              return DropdownMenuItem<EventType>(
                value: type,
                child: Text(_getEnumLabel(type)),
              );
            }).toList(),
          ),
          const SizedBox(height: 12), */
          DropdownButton<EventVisibility>(
            isExpanded: true,
            value: _selectedVisibility,
            hint: const Text('Select Visibility'),
            onChanged: (EventVisibility? newValue) {
              setState(() {
                _selectedVisibility = newValue;
                // If visibility is set to private, invited-only access is redundant
                if (_selectedVisibility == EventVisibility.private &&
                    _selectedLicenseType == EventLicenseType.invited) {
                  _selectedLicenseType = EventLicenseType.none;
                }
              });
            },
            items: EventVisibility.values.map((EventVisibility visibility) {
              return DropdownMenuItem<EventVisibility>(
                value: visibility,
                child: Text(_getEnumLabel(visibility)),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          _buildSectionTitle('Voting Settings'),
          const SizedBox(height: 8),

          Text(
            'Access Control',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          DropdownButton<EventLicenseType>(
            isExpanded: true,
            value: _selectedLicenseType,
            hint: const Text('Select access control'),
            onChanged: (EventLicenseType? newValue) {
              // Prevent selecting invited-only when visibility is private
              if (_selectedVisibility == EventVisibility.private &&
                  newValue == EventLicenseType.invited) {
                return;
              }
              setState(() => _selectedLicenseType = newValue);
            },
            items: (EventLicenseType.values
                    .where((l) => !(_selectedVisibility == EventVisibility.private && l == EventLicenseType.invited))
                    .toList())
                .map((EventLicenseType license) {
              String label;
              String description;
              switch (license) {
                case EventLicenseType.none:
                  label = 'Open Access';
                  description = 'Anyone can participate and vote';
                  break;
                case EventLicenseType.invited:
                  label = 'Invited Only';
                  description = 'Only invited guests can vote';
                  break;
                case EventLicenseType.locationBased:
                  label = 'Location-Based';
                  description = 'Access based on location';
                  break;
              }
              return DropdownMenuItem<EventLicenseType>(
                value: license,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          if (_selectedLicenseType == EventLicenseType.locationBased)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: TextField(
                controller: _radiusController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Voting radius (m)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.circle),
                ),
              ),
            ),
          const SizedBox(height: 12),

          // Dates & Times
          _buildSectionTitle('Dates & Times'),
          // Event Date sur toute la largeur
          SizedBox(
            width: double.infinity,
            child: _buildDateField(
              'Event Date',
              _selectedEventDate,
              (DateTime? date) => setState(() => _selectedEventDate = date),
            ),
          ),
          const SizedBox(width: double.infinity, height: 12),
          // Start Date & End Date côte à côte
          Row(
            children: [
              Expanded(
                child: _buildDateField(
                  'Start Date',
                  _selectedStartDate,
                  (DateTime? date) => setState(() => _selectedStartDate = date),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDateField(
                  'End Date',
                  _selectedEndDate,
                  (DateTime? date) => setState(() => _selectedEndDate = date),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Voting Start Time & Voting End Time côte à côte
          Row(
            children: [
              Expanded(
                child: _buildTimeField(
                  'Voting Start Time',
                  _selectedVotingStartTime,
                  (DateTime? time) =>
                      setState(() => _selectedVotingStartTime = time),
                  startDate: _selectedStartDate,
                  endDate: _selectedEndDate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTimeField(
                  'Voting End Time',
                  _selectedVotingEndTime,
                  (DateTime? time) =>
                      setState(() => _selectedVotingEndTime = time),
                  startDate: _selectedStartDate,
                  endDate: _selectedEndDate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const SizedBox(height: 24),

          // Playlist Info
          _buildSectionTitle('Playlist Information'),
          TextField(
            controller: _playlistNameController,
            decoration: const InputDecoration(
              labelText: 'Playlist Name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.music_note),
            ),
          ),
          const SizedBox(height: 12),

          // Playlist selector - show existing playlists
          Consumer<EventProvider>(
            builder: (context, eventProvider, _) {
              final playlists = eventProvider.myPlaylists;
              return DropdownButton<String>(
                isExpanded: true,
                value: _selectedPlaylistId,
                hint: const Text(
                  'Copy tracks from existing playlist (optional)',
                ),
                onChanged: (String? newValue) {
                  setState(() => _selectedPlaylistId = newValue);
                },
                items: playlists.map((Event playlist) {
                  return DropdownMenuItem<String>(
                    value: playlist.id,
                    child: Text(playlist.name),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.delete),
              label: const Text('Delete Event'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => _showDeleteConfirmation(eventProvider),
            ),
          ),
          const SizedBox(height: 24),
          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.close),
                label: const Text('Cancel'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                onPressed: () => _toggleEditMode(event),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save Changes'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  backgroundColor: Colors.green,
                ),
                onPressed: () => _saveEvent(eventProvider),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDateField(
    String label,
    DateTime? selectedDate,
    Function(DateTime?) onDateSelected,
  ) {
    return ElevatedButton(
      onPressed: () async {
        final DateTime? pickedDate = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (pickedDate != null) {
          // Ask for time
          if (mounted) {
            final TimeOfDay? pickedTime = await showTimePicker(
              context: context,
              initialTime: selectedDate != null
                  ? TimeOfDay.fromDateTime(selectedDate)
                  : const TimeOfDay(hour: 0, minute: 0),
            );
            if (pickedTime != null) {
              final combined = DateTime(
                pickedDate.year,
                pickedDate.month,
                pickedDate.day,
                pickedTime.hour,
                pickedTime.minute,
              );
              onDateSelected(combined);
            }
          }
        }
      },
      child: Text(
        selectedDate != null
            ? '$label: ${selectedDate.toLocal()}'.split('.')[0]
            : label,
      ),
    );
  }

  Widget _buildTimeField(
    String label,
    DateTime? selectedDateTime,
    Function(DateTime?) onTimeSelected, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return ElevatedButton(
      onPressed: () async {
        final TimeOfDay? pickedTime = await showTimePicker(
          context: context,
          initialTime: selectedDateTime != null
              ? TimeOfDay.fromDateTime(selectedDateTime)
              : const TimeOfDay(hour: 0, minute: 0),
        );
        if (pickedTime != null) {
          // Create DateTime with today's date and selected time
          DateTime newDateTime = DateTime(
            selectedDateTime?.year ?? 2000,
            selectedDateTime?.month ?? 1,
            selectedDateTime?.day ?? 1,
            pickedTime.hour,
            pickedTime.minute,
          );

          // Validation: votingStartTime and votingEndTime must be during event
          if (startDate != null || endDate != null) {
            final start = startDate ?? _selectedStartDate;
            final end = endDate ?? _selectedEndDate;

            if (start != null && newDateTime.isBefore(start)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Voting time must be after event start'),
                ),
              );
              return;
            }
            if (end != null && newDateTime.isAfter(end)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Voting time must be before event end'),
                ),
              );
              return;
            }
          }

          onTimeSelected(newDateTime);
        }
      },
      child: Text(
        selectedDateTime != null
            ? '$label: ${_formatTimeToString(selectedDateTime)}'
            : label,
      ),
    );
  }

  Widget _buildViewMode(
    BuildContext context,
    Event event,
    bool isAdmin,
    EventProvider eventProvider,
  ) {
    // Get cover image from event or first track
    final String? eventCover =
      event.coverImageUrl ??
      ((eventProvider.currentPlaylistTracks != null &&
          eventProvider.currentPlaylistTracks.isNotEmpty)
        ? eventProvider.currentPlaylistTracks.first.coverUrl
        : null);

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.blue.shade700, Colors.blue.shade400],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Event Icon/Cover
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: eventCover != null && eventCover.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    eventCover,
                                    fit: BoxFit.cover,
                                    width: 120,
                                    height: 120,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Center(
                                              child: Icon(
                                                Icons.event,
                                                size: 60,
                                                color: Colors.white,
                                              ),
                                            ),
                                  ),
                                )
                              : const Icon(
                                  Icons.event,
                                  size: 60,
                                  color: Colors.white,
                                ),
                        ),
                        const SizedBox(width: 16),

                        // Event Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Event name
                              Text(
                                event.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),

                              // Description
                              if (event.description != null &&
                                  event.description!.isNotEmpty)
                                Text(
                                  event.description!,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: Colors.white70),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Invite/Manage Button
                        Consumer<AuthProvider>(
                          builder: (context, authProvider, _) {
                            final currentUser = authProvider.currentUser;
                            final isOwner = currentUser?.id == event.creatorId;

                            if (isOwner) {
                              return Material(
                                color: Colors.white.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () =>
                                      _showInviteFriendsDialog(context, event),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    child: const Icon(
                                      Icons.person_add,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Details in banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildBannerDetail(
                                  context,
                                  icon: Icons.calendar_today,
                                  label: 'Event Date',
                                  value: event.eventDate != null
                                      ? _formatDate(event.eventDate!)
                                      : 'Not set',
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildBannerDetail(
                                  context,
                                  icon: Icons.people,
                                  label: 'Participants',
                                  value: '${event.participants?.length ?? 0}',
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildBannerDetail(
                                  context,
                                  icon: Icons.visibility,
                                  label: 'Visibility',
                                  value: _getEnumLabel(event.visibility),
                                ),
                              ),
                            ],
                          ),
                          if (event.locationName != null &&
                              event.locationName!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildBannerDetail(
                              context,
                              icon: Icons.location_on,
                              label: 'Location',
                              value: event.locationName!,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Action Button
                    if (!event.isPlaylist)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _navigateToPlaylist(context, event.id),
                          icon: const Icon(Icons.queue_music),
                          label: const Text('View Event Playlist'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.blue.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Event Details Section
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Additional Details
                    Text(
                      'Additional Information',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow('Type', _getEnumLabel(event.type)),
                          if (event.licenseType != null) ...[
                            const Divider(height: 16),
                            _buildDetailRow(
                              'Access',
                              _getEnumLabel(event.licenseType!),
                            ),
                          ],
                          const Divider(height: 16),
                          _buildDetailRow(
                            'Voting',
                            (event.votingEnabled ?? true)
                                ? 'Enabled'
                                : 'Disabled',
                          ),
                          if (event.votingStartTime != null) ...[
                            const Divider(height: 16),
                            _buildDetailRow(
                              'Voting Start',
                              event.votingStartTime!,
                            ),
                          ],
                          if (event.votingEndTime != null) ...[
                            const Divider(height: 16),
                            _buildDetailRow('Voting End', event.votingEndTime!),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Connected Users Section (live from WebSocket rooms)
                    Text(
                      'Connected Users (${_connectedUsers.length})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_connectedUsers.isNotEmpty)
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _connectedUsers.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final user = _connectedUsers[index];
                            final name = user['displayName'] as String? ?? 'Unknown User';
                            final avatarUrl = user['avatarUrl'] as String?;
                            final userId = user['userId'] as String?;
                            final isCreator = userId == event.creatorId;

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.green.shade100,
                                child: avatarUrl != null && avatarUrl.isNotEmpty
                                    ? ClipOval(
                                        child: Image.network(
                                          avatarUrl,
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Icon(
                                                    Icons.person,
                                                    color: Colors.green.shade700,
                                                  ),
                                        ),
                                      )
                                    : Icon(
                                        Icons.person,
                                        color: Colors.green.shade700,
                                      ),
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                isCreator ? 'Creator' : 'Online',
                                style: TextStyle(
                                  color: isCreator
                                      ? Colors.blue.shade700
                                      : Colors.green.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              trailing: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    else
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No one else connected',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBannerDetail(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.blue.shade700, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.blue.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showDeleteConfirmation(EventProvider eventProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text(
          'Are you sure you want to delete this event? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await eventProvider.deleteEvent(widget.eventId);
              if (mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Event deleted successfully')),
                  );
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${eventProvider.error}')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showInviteFriendsDialog(BuildContext context, Event event) {
    showDialog(
      context: context,
      builder: (context) => InviteFriendsDialog(
        eventId: event.id,
        eventName: event.name,
        isPlaylist: event.isPlaylist,
      ),
    );
  }
}
