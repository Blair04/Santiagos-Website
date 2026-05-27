
import 'package:flutter_test/flutter_test.dart';

// Import your main application entry point
import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('Login screen elements load test', (WidgetTester tester) async {
    // Pass 'false' to satisfy the required initialization parameter
    await tester.pumpWidget(const MyApp(isAdminLoggedIn: false));

    // Verify that your application's actual login elements are present
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
  });
}