// Integration test — must run on a real device.
//
// `isAvailable()` is false on the simulator, so the only thing that can be
// asserted everywhere is that the call reaches the platform and comes back
// without throwing. That is exactly the failure this test exists to catch: a
// plugin that never got registered.
import 'package:flutter_test/flutter_test.dart';
import 'package:headless_compass/headless_compass.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('isAvailable answers without throwing', (tester) async {
    final available = await HeadingSource().isAvailable();

    expect(available, isA<bool>());
  });
}
