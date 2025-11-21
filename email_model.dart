class EmailModel {
  final String id;
  final String subject;
  final String sender;
  final DateTime date;
  final String snippet;

  EmailModel({
    required this.id,
    required this.subject,
    required this.sender,
    required this.date,
    required this.snippet,
  });

  // Example from JSON if you fetch via Gmail API
  factory EmailModel.fromJson(Map<String, dynamic> json) {
    return EmailModel(
      id: json['id'],
      subject: json['payload']['headers']
          .firstWhere((header) => header['name'] == 'Subject', orElse: () => {'value': ''})['value'],
      sender: json['payload']['headers']
          .firstWhere((header) => header['name'] == 'From', orElse: () => {'value': ''})['value'],
      date: DateTime.parse(json['internalDate']),
      snippet: json['snippet'],
    );
  }
}

class Email {
  final String sender;
  final String subject;
  final String body;

  Email({required this.sender, required this.subject, required this.body});
}
