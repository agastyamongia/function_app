class Event {
  final String id;
  final String rsoId;
  final String rsoName;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final String location;
  final double? price;
  final DateTime createdAt;
  final bool isPublished;
  final String? qrCodeUrl;
  final String? shareableLink;
  final String creatorId;

  Event({
    required this.id,
    required this.rsoId,
    required this.rsoName,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.location,
    this.price,
    required this.createdAt,
    this.isPublished = false,
    this.qrCodeUrl,
    this.shareableLink,
    required this.creatorId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rso_id': rsoId,
      'rso_name': rsoName,
      'title': title,
      'description': description,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'location': location,
      'price': price,
      'created_at': createdAt.toIso8601String(),
      'is_published': isPublished,
      'qr_code_url': qrCodeUrl,
      'shareable_link': shareableLink,
      'creator_id': creatorId,
    };
  }

  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      id: map['id'],
      rsoId: map['rso_id'],
      rsoName: map['rso_name'],
      title: map['title'],
      description: map['description'],
      startTime: DateTime.parse(map['start_time']),
      endTime: DateTime.parse(map['end_time']),
      location: map['location'],
      price: map['price']?.toDouble(),
      createdAt: DateTime.parse(map['created_at']),
      isPublished: map['is_published'] ?? false,
      qrCodeUrl: map['qr_code_url'],
      shareableLink: map['shareable_link'],
      creatorId: map['creator_id'],
    );
  }

  Event copyWith({
    String? id,
    String? rsoId,
    String? rsoName,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    double? price,
    DateTime? createdAt,
    bool? isPublished,
    String? qrCodeUrl,
    String? shareableLink,
    String? creatorId,
  }) {
    return Event(
      id: id ?? this.id,
      rsoId: rsoId ?? this.rsoId,
      rsoName: rsoName ?? this.rsoName,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      price: price ?? this.price,
      createdAt: createdAt ?? this.createdAt,
      isPublished: isPublished ?? this.isPublished,
      qrCodeUrl: qrCodeUrl ?? this.qrCodeUrl,
      shareableLink: shareableLink ?? this.shareableLink,
      creatorId: creatorId ?? this.creatorId,
    );
  }
} 