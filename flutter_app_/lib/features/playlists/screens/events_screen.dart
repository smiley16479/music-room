import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/index.dart';
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
                  onPressed: () => showCreateEventDialog(context),
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
}
