import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/event.dart';
import '../../../core/providers/index.dart';

/// Event Details screen with full edit capabilities
class EventDetailsScreen extends StatefulWidget {
  final String eventId;

  const EventDetailsScreen({
    super.key,
    required this.eventId,
  });

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  bool _isEditMode = false;
  
  // Text Controllers
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationNameController;
  late TextEditingController _playlistNameController;

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
    _loadEvent();
  }

  void _initControllers() {
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _locationNameController = TextEditingController();
    _playlistNameController = TextEditingController();
    
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

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationNameController.dispose();
    _playlistNameController.dispose();
    super.dispose();
  }

  Future<void> _loadEvent() async {
    final eventProvider = context.read<EventProvider>();
    await eventProvider.loadEventDetails(widget.eventId);
  }

  void _toggleEditMode(Event event) {
    _nameController.text = event.name;
    _descriptionController.text = event.description ?? '';
    _locationNameController.text = event.locationName ?? '';
    _playlistNameController.text = event.playlistName ?? '';
    
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

  Future<void> _saveEvent(EventProvider eventProvider) async {
    final success = await eventProvider.updateEvent(
      widget.eventId,
      name: _nameController.text,
      description: _descriptionController.text,
      type: _enumToJsonValue(_selectedType),
      visibility: _enumToJsonValue(_selectedVisibility),
      licenseType: _enumToJsonValue(_selectedLicenseType),
      votingEnabled: _votingEnabled,
      locationName: _locationNameController.text.isNotEmpty ? _locationNameController.text : null,
      playlistName: _playlistNameController.text.isNotEmpty ? _playlistNameController.text : null,
      votingStartTime: _formatTimeToString(_selectedVotingStartTime),
      votingEndTime: _formatTimeToString(_selectedVotingEndTime),
      eventDate: _selectedEventDate,
      startDate: _selectedStartDate,
      endDate: _selectedEndDate,
      selectedPlaylistId: _selectedPlaylistId,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event updated successfully')),
        );
        setState(() {
          _isEditMode = false;
        });
        // Reload event details to reflect changes
        await _loadEvent();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${eventProvider.error}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<EventProvider, AuthProvider>(
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
    );
  }

  Widget _buildEditForm(EventProvider eventProvider, Event event) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Edit Event',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
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
          
          // Event Type & Settings
          _buildSectionTitle('Event Type & Settings'),
          DropdownButton<EventType>(
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
          const SizedBox(height: 12),
          
          DropdownButton<EventVisibility>(
            isExpanded: true,
            value: _selectedVisibility,
            hint: const Text('Select Visibility'),
            onChanged: (EventVisibility? newValue) {
              setState(() => _selectedVisibility = newValue);
            },
            items: EventVisibility.values.map((EventVisibility visibility) {
              return DropdownMenuItem<EventVisibility>(
                value: visibility,
                child: Text(_getEnumLabel(visibility)),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          
          DropdownButton<EventLicenseType>(
            isExpanded: true,
            value: _selectedLicenseType,
            hint: const Text('Select License Type'),
            onChanged: (EventLicenseType? newValue) {
              setState(() => _selectedLicenseType = newValue);
            },
            items: EventLicenseType.values.map((EventLicenseType license) {
              return DropdownMenuItem<EventLicenseType>(
                value: license,
                child: Text(_getEnumLabel(license)),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          
          CheckboxListTile(
            title: const Text('Voting Enabled'),
            value: _votingEnabled,
            onChanged: (bool? value) {
              setState(() => _votingEnabled = value ?? true);
            },
          ),
          const SizedBox(height: 24),
          
          // Dates & Times
          _buildSectionTitle('Dates & Times'),
          _buildDateField(
            'Event Date',
            _selectedEventDate,
            (DateTime? date) => setState(() => _selectedEventDate = date),
          ),
          const SizedBox(height: 12),
          _buildDateField(
            'Start Date',
            _selectedStartDate,
            (DateTime? date) => setState(() => _selectedStartDate = date),
          ),
          const SizedBox(height: 12),
          _buildDateField(
            'End Date',
            _selectedEndDate,
            (DateTime? date) => setState(() => _selectedEndDate = date),
          ),
          const SizedBox(height: 12),
          
          _buildTimeField(
            'Voting Start Time',
            _selectedVotingStartTime,
            (DateTime? time) => setState(() => _selectedVotingStartTime = time),
            startDate: _selectedStartDate,
            endDate: _selectedEndDate,
          ),
          const SizedBox(height: 12),
          _buildTimeField(
            'Voting End Time',
            _selectedVotingEndTime,
            (DateTime? time) => setState(() => _selectedVotingEndTime = time),
            startDate: _selectedStartDate,
            endDate: _selectedEndDate,
          ),
          const SizedBox(height: 24),
          
          // Location Info
          _buildSectionTitle('Location Information'),
          TextField(
            controller: _locationNameController,
            decoration: const InputDecoration(
              labelText: 'Location Name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_on),
            ),
          ),
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
                hint: const Text('Copy tracks from existing playlist (optional)'),
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
          const SizedBox(height: 24),
          
          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.close),
                label: const Text('Cancel'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () => _toggleEditMode(event),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save Changes'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
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
    Function(DateTime?) onTimeSelected,
    {DateTime? startDate, DateTime? endDate}
  ) {
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
                const SnackBar(content: Text('Voting time must be after event start')),
              );
              return;
            }
            if (end != null && newDateTime.isAfter(end)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Voting time must be before event end')),
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
    return SingleChildScrollView(
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
                colors: [
                  Colors.blue.shade700,
                  Colors.blue.shade400,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.event,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  event.name,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (isAdmin)
                  Chip(
                    label: const Text('You are the admin'),
                    backgroundColor: Colors.amber,
                    labelStyle: const TextStyle(color: Colors.black),
                  ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (event.description != null && event.description!.isNotEmpty) ...[
                  _buildDetailSection('Description', event.description!),
                  const SizedBox(height: 24),
                ],
                
                _buildDetailSection('Type', _getEnumLabel(event.type)),
                _buildDetailSection('Visibility', _getEnumLabel(event.visibility)),
                if (event.licenseType != null)
                  _buildDetailSection('License Type', _getEnumLabel(event.licenseType!)),
                _buildDetailSection('Voting Enabled', (event.votingEnabled ?? true) ? 'Yes' : 'No'),
                
                if (event.eventDate != null)
                  _buildDetailSection('Event Date', event.eventDate.toString().split('.')[0]),
                if (event.startDate != null)
                  _buildDetailSection('Start Date', event.startDate.toString().split('.')[0]),
                if (event.endDate != null)
                  _buildDetailSection('End Date', event.endDate.toString().split('.')[0]),
                
                if (event.locationName != null && event.locationName!.isNotEmpty)
                  _buildDetailSection('Location', event.locationName!),
                
                if (event.votingStartTime != null)
                  _buildDetailSection('Voting Start Time', event.votingStartTime!),
                if (event.votingEndTime != null)
                  _buildDetailSection('Voting End Time', event.votingEndTime!),
                
                if (event.playlistName != null && event.playlistName!.isNotEmpty)
                  _buildDetailSection('Playlist Name', event.playlistName!),
                
                if (event.trackCount != null && event.trackCount! > 0)
                  _buildDetailSection('Track Count', event.trackCount.toString()),
                
                const SizedBox(height: 24),
                Text(
                  'Participants (${event.participants?.length ?? 0})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (event.participants != null && event.participants!.isNotEmpty)
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: event.participants!.length,
                    itemBuilder: (context, index) {
                      final participant = event.participants![index];
                      final name = participant.displayName ?? 'Unknown User';
                      final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
                      return ListTile(
                        leading: CircleAvatar(child: Text(initial)),
                        title: Text(name),
                        subtitle: Text(participant.email ?? 'No email'),
                      );
                    },
                  )
                else
                  const Text('No participants yet'),
                
                const SizedBox(height: 24),
                if (isAdmin) ...[
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    'Admin Actions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.red,
                    ),
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
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(EventProvider eventProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text('Are you sure you want to delete this event? This action cannot be undone.'),
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
}
