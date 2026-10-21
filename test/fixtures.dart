Map<String, Object?> verifiedResponse({String role = 'admin'}) => {
  'accessToken': 'test-access',
  'refreshToken': 'test-refresh',
  'accessExpiresAt': '2099-01-01T00:00:00Z',
  'user': {
    'id': 'test-user',
    'name': 'Demo',
    'email': 'demo@example.test',
    'username': 'demo',
    'department': '',
    'role': role,
    'shiftId': null,
    'active': true,
  },
};
