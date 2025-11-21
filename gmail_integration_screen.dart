// filepath: c:\Users\Infosec\Desktop\Flutter Projects\mobile_ai_scams\lib\screens\gmail_integration_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/gmail_service.dart';

class GmailIntegrationScreen extends StatefulWidget {
  const GmailIntegrationScreen({super.key});

  @override
  _GmailIntegrationScreenState createState() => _GmailIntegrationScreenState();
}

class _GmailIntegrationScreenState extends State<GmailIntegrationScreen> {
  final AuthService _authService = AuthService();
  List<Map<String, String>> _emails = [];
  String _sortOption = 'flagged'; // 'flagged' or 'date'
  String _searchQuery = '';
  bool _isLoading = false;
  bool _showOnlyFlagged = false;
  String _status = "Welcome to Scam Shield!";

  @override
  void initState() {
    super.initState();
    _loadFilterPreference();
  }

  Future<void> _loadFilterPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showOnlyFlagged = prefs.getBool('showOnlyFlagged') ?? false;
    });
  }

  Future<void> _saveFilterPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showOnlyFlagged', value);
  }

  Future<void> fetchEmailSubjects() async {
    setState(() {
      _isLoading = true;
      _status = "Fetching emails...";
    });

    try {
      final accessToken = await _authService.signInAndGetAccessToken();
      if (accessToken == null) {
        setState(() {
          _status = "Sign-in failed.";
          _isLoading = false;
        });
        return;
      }

      final gmailService = GmailService(accessToken);
      final emails = _searchQuery.isEmpty
          ? await gmailService.fetchEmails(limit: 30)
          : await gmailService.searchEmailsFromLastDays(query: _searchQuery, days: 90);

      setState(() {
        if (_sortOption == 'flagged') {
          emails.sort((a, b) => (b['hasUrl'] == 'true' ? 1 : 0).compareTo(a['hasUrl'] == 'true' ? 1 : 0));
        } else if (_sortOption == 'date') {
          emails.sort((a, b) => (b['timestamp'] ?? '0').compareTo(a['timestamp'] ?? '0'));
        }
        _emails = emails;
        _status = "Fetched ${emails.length} emails.";
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching emails: $e");
      setState(() {
        _status = "Error: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scam Shield Home")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Red: Contains URL or Attachment',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Green: No URL or Attachment',
                    style: TextStyle(color: Colors.green),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: fetchEmailSubjects,
              child: const Text("Sign in and Fetch Emails"),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search by Subject or Sender',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
            const SizedBox(height: 16),
            Text(_status),
            Row(
              children: [
                Checkbox(
                  value: _showOnlyFlagged,
                  onChanged: (val) async {
                    final updated = val ?? false;
                    setState(() {
                      _showOnlyFlagged = updated;
                    });
                    await _saveFilterPreference(updated);
                  },
                ),
                const Text("Show only flagged emails"),
                const SizedBox(width: 20),
                const Text("Sort by: "),
                DropdownButton<String>(
                  value: _sortOption,
                  items: const [
                    DropdownMenuItem(value: 'flagged', child: Text('Flagged')),
                    DropdownMenuItem(value: 'date', child: Text('Date')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _sortOption = value ?? 'flagged';
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            _isLoading
                ? const CircularProgressIndicator()
                : Expanded(
                    child: ListView.builder(
                      itemCount: _emails.where((e) {
                        final isFlagged = !_showOnlyFlagged || (e['hasUrl'] == 'true' || e['hasAttachment'] == 'true');
                        final matchesSearch = _searchQuery.isEmpty ||
                            (e['subject']?.toLowerCase().contains(_searchQuery) ?? false) ||
                            (e['from']?.toLowerCase().contains(_searchQuery) ?? false);
                        return isFlagged && matchesSearch;
                      }).length,
                      itemBuilder: (context, index) {
                        final filteredEmails = _emails.where((e) {
                          final isFlagged = !_showOnlyFlagged || (e['hasUrl'] == 'true' || e['hasAttachment'] == 'true');
                          final matchesSearch = _searchQuery.isEmpty ||
                              (e['subject']?.toLowerCase().contains(_searchQuery) ?? false) ||
                              (e['from']?.toLowerCase().contains(_searchQuery) ?? false);
                          return isFlagged && matchesSearch;
                        }).toList();
                        final email = filteredEmails[index];
                        final hasUrl = email['hasUrl'] == 'true';
                        final hasAttachment = email['hasAttachment'] == 'true';
                        final isFlagged = hasUrl || hasAttachment;
                        return Container(
                          color: isFlagged ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.05),
                          child: Column(
                            children: [
                              ListTile(
                                title: RichText(
                                  text: TextSpan(
                                    text: 'Subject: ',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: email['subject'] ?? 'No Subject',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text(
                                          'Received: ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                        Text(
                                          email['timestamp'] != null
                                              ? DateFormat('MMM d, yyyy – h:mm a').format(
                                                  DateTime.fromMillisecondsSinceEpoch(
                                                    int.parse(email['timestamp']!),
                                                  ).toLocal(),
                                                )
                                              : 'Unknown',
                                          style: const TextStyle(fontWeight: FontWeight.normal),
                                        ),
                                      ],
                                    ),
                                    RichText(
                                      text: TextSpan(
                                        text: 'From: ',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: email['from'] ?? 'Unknown Sender',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        const Text(
                                          'Attachment: ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                        Text(
                                          hasAttachment ? 'Yes' : 'No',
                                          style: TextStyle(
                                            fontWeight: FontWeight.normal,
                                            color: hasAttachment ? Colors.red : Colors.green,
                                          ),
                                        ),
                                        if (hasAttachment)
                                          const Padding(
                                            padding: EdgeInsets.only(left: 4.0),
                                            child: Icon(Icons.warning, color: Colors.red, size: 18),
                                          ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        const Text(
                                          'URL Detected: ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                        Text(
                                          hasUrl ? 'Yes' : 'No',
                                          style: TextStyle(
                                            fontWeight: FontWeight.normal,
                                            color: hasUrl ? Colors.red : Colors.green,
                                          ),
                                        ),
                                        if (hasUrl)
                                          const Padding(
                                            padding: EdgeInsets.only(left: 4.0),
                                            child: Icon(Icons.warning, color: Colors.red, size: 18),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                leading: const Icon(Icons.email_outlined),
                              ),
                              const Divider(thickness: 1),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}