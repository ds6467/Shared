import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/gmail_service.dart';

class GmailService {
  final String accessToken;

  GmailService(this.accessToken);

  // Fetch emails with a limit
  Future<List<Map<String, String>>> fetchEmails({int limit = 30}) async {
    final List<Map<String, String>> emails = [];

    final response = await http.get(
      Uri.parse("https://gmail.googleapis.com/gmail/v1/users/me/messages?maxResults=$limit"),
      headers: {"Authorization": "Bearer $accessToken"},
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to fetch message IDs: ${response.body}");
    }

    final messageList = jsonDecode(response.body)['messages'] as List<dynamic>?;
    if (messageList == null) return emails;

    for (final message in messageList) {
      final data = await _getEmailData(message['id']);
      if (data != null) emails.add(data);
    }

    return emails;
  }

  // Search emails from the last 'n' days with a query
  Future<List<Map<String, String>>> searchEmailsFromLastDays({required String query, int days = 90}) async {
    final List<Map<String, String>> emails = [];
    final afterEpoch = (DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch ~/ 1000).toString();

    final response = await http.get(
      Uri.parse("https://gmail.googleapis.com/gmail/v1/users/me/messages?q=after:$afterEpoch&maxResults=100"),
      headers: {"Authorization": "Bearer $accessToken"},
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to fetch message IDs: ${response.body}");
    }

    final messageList = jsonDecode(response.body)['messages'] as List<dynamic>?;
    if (messageList == null) return emails;

    for (final message in messageList) {
      final data = await _getEmailData(message['id']);
      if (data != null &&
          (data['subject']!.toLowerCase().contains(query.toLowerCase()) ||
              data['from']!.toLowerCase().contains(query.toLowerCase()))) {
        emails.add(data);
      }
    }

    return emails;
  }

  // Fetch and parse email details
  Future<Map<String, String>?> _getEmailData(String id) async {
    final response = await http.get(
      Uri.parse("https://gmail.googleapis.com/gmail/v1/users/me/messages/$id?format=full"),
      headers: {"Authorization": "Bearer $accessToken"},
    );

    if (response.statusCode != 200) return null;

    final messageDetail = jsonDecode(response.body);
    final headersList = messageDetail['payload']?['headers'] as List<dynamic>?;
    if (headersList == null) return null;

    String from = headersList.firstWhere(
      (h) => h['name'] == 'From',
      orElse: () => {'value': 'Unknown Sender'},
    )['value'];

    String subject = headersList.firstWhere(
      (h) => h['name'] == 'Subject',
      orElse: () => {'value': 'No Subject'},
    )['value'];

    bool hasAttachments = _hasAttachments(messageDetail['payload']?['parts']);
    String bodyText = _getBodyText(messageDetail['payload'] ?? {});
    bool hasUrl = _containsUrl(bodyText);

    return {
      'subject': subject,
      'from': from,
      'hasAttachment': hasAttachments ? 'true' : 'false',
      'hasUrl': hasUrl ? 'true' : 'false',
      'timestamp': messageDetail['internalDate'] ?? '0',
    };
  }

  // Recursive function to check for attachments
  bool _hasAttachments(dynamic parts) {
    if (parts == null) return false;
    for (var part in parts) {
      if (part['filename'] != null && part['filename'].toString().isNotEmpty) return true;
      if (part['parts'] != null && _hasAttachments(part['parts'])) return true;
    }
    return false;
  }

  // Extract body text from the email payload
  String _getBodyText(Map<String, dynamic> payload) {
    if (payload['body'] != null && payload['body']['data'] != null) {
      return utf8.decode(base64Url.decode(payload['body']['data']));
    }
    if (payload['parts'] != null) {
      for (var part in payload['parts']) {
        final result = _getBodyText(part);
        if (result.isNotEmpty) return result;
      }
    }
    return '';
  }

  // Check if the body text contains a URL
  bool _containsUrl(String text) {
    final urlRegex = RegExp(r'https?:\/\/[^"]+', caseSensitive: false);
    return urlRegex.hasMatch(text);
  }

  // Fetch email IDs
  Future<List<String>> fetchNewEmails() async {
    final url = Uri.parse('https://gmail.googleapis.com/gmail/v1/users/me/messages?maxResults=10');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final messages = data['messages'] as List<dynamic>? ?? [];
      return messages.map((message) => message['id'] as String).toList();
    } else {
      throw Exception('Failed to fetch emails: ${response.body}');
    }
  }

  // Get the last processed timestamp
  Future<int> getLastProcessedTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('lastProcessedTimestamp') ?? 0;
  }

  // Set the last processed timestamp
  Future<void> setLastProcessedTimestamp(int timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastProcessedTimestamp', timestamp);
  }
}

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
      final emails = await gmailService.fetchEmails();
      print("UI Emails: $emails");

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