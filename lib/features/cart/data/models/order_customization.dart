enum CustomizationType {
  text,
  voice,
}

class OrderCustomization {
  final CustomizationType type;
  final String content; // Text message or audio file path
  final DateTime timestamp;
  final int? durationSeconds; // For voice messages

  OrderCustomization({
    required this.type,
    required this.content,
    required this.timestamp,
    this.durationSeconds,
  });

  OrderCustomization copyWith({
    CustomizationType? type,
    String? content,
    DateTime? timestamp,
    int? durationSeconds,
  }) {
    return OrderCustomization(
      type: type ?? this.type,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString().split('.').last,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'durationSeconds': durationSeconds,
    };
  }

  factory OrderCustomization.fromJson(Map<String, dynamic> json) {
    return OrderCustomization(
      type: CustomizationType.values.firstWhere(
        (e) => e.toString() == 'CustomizationType.${json['type']}',
        orElse: () => CustomizationType.text,
      ),
      content: json['content'] ?? '',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      durationSeconds: json['durationSeconds'],
    );
  }
}
