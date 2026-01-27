import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/event_provider.dart';

/// Reusable Create Event Dialog
/// Shows a dialog to create a new event with all necessary fields
void showCreateEventDialog(BuildContext context) {
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
                        lastDate: DateTime.now().add(const Duration(days: 365)),
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
                      type: 'event', // Create as event (not playlist)
                    );
                    if (context.mounted) {
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
