const String kSessionKey = 'clickeat.admin.session';

class Session {
  final String accessToken;
  final int userId;
  final String userName;
  final String userLastname;

  const Session({
    required this.accessToken,
    required this.userId,
    required this.userName,
    required this.userLastname,
  });

  factory Session.fromBackend(Map<String, dynamic> result) {
    return Session(
      accessToken: (result['accessToken'] ?? '') as String,
      userId: (result['user_id'] as num?)?.toInt() ?? 0,
      userName: (result['user_name'] ?? '') as String,
      userLastname: (result['user_lastname'] ?? '') as String,
    );
  }

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      accessToken: json['accessToken'] as String,
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      userName: (json['userName'] ?? '') as String,
      userLastname: (json['userLastname'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'userId': userId,
        'userName': userName,
        'userLastname': userLastname,
      };
}
