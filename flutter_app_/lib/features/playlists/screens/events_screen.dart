import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/index.dart';
import 'event_details_screen.dart';

/// Events screen - shows upcoming events
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

// MARK: - EventsScreenState
class _EventsScreenState extends State<EventsScreen> {
  @override
  void initState() {
    super.initState();
    _loadEvents();
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
        final events = eventProvider.realEvents;

        if (events.isEmpty) {
          return Center(
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
                  'No Events Yet',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text('Create your first event to get started'),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _showCreateEventDialog,
                  child: const Text('Create Event'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
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
        );
      },
    );
  }

  // MARK: - CreateEventDialog
  void _showCreateEventDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final locationController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    bool isPublic = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Create Event'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Event Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (picked != null) {
                          setState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              selectedDate.toString().split(' ')[0],
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const Icon(Icons.calendar_today),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Visibility'),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(label: Text('Public'), value: true),
                            ButtonSegment(label: Text('Private'), value: false),
                          ],
                          selected: <bool>{isPublic},
                          onSelectionChanged: (Set<bool> newSelection) {
                            setState(() {
                              isPublic = newSelection.first;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.isNotEmpty) {
                      final eventProvider = context.read<EventProvider>();
                      final success = await eventProvider.createEvent(
                        name: titleController.text,
                        description: descriptionController.text.isNotEmpty
                            ? descriptionController.text
                            : null,
                        eventDate: selectedDate,
                        locationName: locationController.text.isNotEmpty
                            ? locationController.text
                            : null,
                        visibility: isPublic ? 'public' : 'private',
                        type: 'party', // Create as event (not playlist)
                      );
                      if (mounted) {
                        Navigator.pop(context);
                        if (success) {
                          await eventProvider.loadMyEvents();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Event created successfully!'),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: ${eventProvider.error}'),
                            ),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
