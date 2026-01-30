import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/index.dart';
import '../../../core/models/event.dart';
import '../widgets/create_event_dialog.dart';
import 'event_details_screen.dart';

/// Events screen - shows upcoming events
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

// MARK: - EventsScreenState
class _EventsScreenState extends State<EventsScreen> {
  // Filter states for events
  EventVisibility? _eventVisibilityFilter;
  EventLicenseType? _eventLicenseTypeFilter;
  late TextEditingController _eventSearchController;

  @override
  void initState() {
    super.initState();
    _eventSearchController = TextEditingController();
    _loadEvents();
  }

  @override
  void dispose() {
    _eventSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    final eventProvider = context.read<EventProvider>();
    // Only load if not already loaded
    if (eventProvider.myEvents.isEmpty) {
      await eventProvider.loadMyEvents();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EventProvider>(
      builder: (context, eventProvider, _) {
        if (eventProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        // Filter real events (non-playlists) using getter
        var events = eventProvider.realEvents;

        // Apply search filter
        final searchTerm = _eventSearchController.text.toLowerCase();
        if (searchTerm.isNotEmpty) {
          events = events
              .where((e) => e.name.toLowerCase().contains(searchTerm))
              .toList();
        }

        // Apply visibility filter
        if (_eventVisibilityFilter != null) {
          events = events
              .where((e) => e.visibility == _eventVisibilityFilter)
              .toList();
        }

        // Apply license type filter
        if (_eventLicenseTypeFilter != null) {
          events = events
              .where((e) => e.licenseType == _eventLicenseTypeFilter)
              .toList();
        }

        return Column(
          children: [
            // Search and Filter section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search field
                  TextField(
                    controller: _eventSearchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search events...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _eventSearchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _eventSearchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Filters',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  // Visibility filter
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: _eventVisibilityFilter == null,
                        onSelected: (_) {
                          setState(() => _eventVisibilityFilter = null);
                        },
                      ),
                      ...EventVisibility.values.map((visibility) {
                        return FilterChip(
                          label: Text(visibility.name),
                          selected: _eventVisibilityFilter == visibility,
                          onSelected: (_) {
                            setState(() => _eventVisibilityFilter = visibility);
                          },
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // License type filter
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('All types'),
                        selected: _eventLicenseTypeFilter == null,
                        onSelected: (_) {
                          setState(() => _eventLicenseTypeFilter = null);
                        },
                      ),
                      ...EventLicenseType.values.map((licenseType) {
                        return FilterChip(
                          label: Text(licenseType.name),
                          selected: _eventLicenseTypeFilter == licenseType,
                          onSelected: (_) {
                            setState(
                              () => _eventLicenseTypeFilter = licenseType,
                            );
                          },
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
            // List of events
            if (events.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event,
                        size: 80,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'No Events Found',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      const Text('Create your first event to get started'),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => showCreateEventDialog(context),
                        child: const Text('Create Event'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child:
                              event.coverImageUrl != null &&
                                  event.coverImageUrl!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    event.coverImageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                              Icons.event,
                                              color: Colors.blue,
                                              size: 30,
                                            ),
                                  ),
                                )
                              : const Icon(
                                  Icons.event,
                                  color: Colors.blue,
                                  size: 30,
                                ),
                        ),
                        title: Text(event.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (event.description != null &&
                                event.description!.isNotEmpty)
                              Text(event.description!),
                            if (event.eventDate != null)
                              Text(
                                'Starts: ${event.eventDate.toString().split('.')[0]}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            if (event.locationName != null &&
                                event.locationName!.isNotEmpty)
                              Text(
                                'Location: ${event.locationName}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  EventDetailsScreen(eventId: event.id),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
