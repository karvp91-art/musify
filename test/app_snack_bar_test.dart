import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musify/core/utils/app_snack_bar.dart';
import 'package:toastification/toastification.dart';

Future<void> cleanUpToasts(WidgetTester tester) async {
  toastification.dismissAll(delayForAnimation: false);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('AppSnackBar renders toast with custom message and icon', (tester) async {
    await tester.pumpWidget(
      ToastificationWrapper(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AppSnackBar.show(
                    context,
                    message: 'Batch deleted 3 tracks',
                    type: AppSnackBarType.delete,
                  );
                },
                child: const Text('Show SnackBar'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Batch deleted 3 tracks'), findsNothing);

    await tester.tap(find.text('Show SnackBar'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Batch deleted 3 tracks'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);

    await cleanUpToasts(tester);
  });

  testWidgets('AppSnackBar with action button triggers callback on tap', (tester) async {
    bool actionTriggered = false;

    await tester.pumpWidget(
      ToastificationWrapper(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AppSnackBar.show(
                    context,
                    message: 'File removed',
                    type: AppSnackBarType.info,
                    actionLabel: 'Undo',
                    onAction: () => actionTriggered = true,
                  );
                },
                child: const Text('Show SnackBar'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show SnackBar'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Undo'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(actionTriggered, isTrue);

    await cleanUpToasts(tester);
  });
}
