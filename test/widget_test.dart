import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';

import 'package:tc_moeckmuehl/main.dart';

void main() {
	testWidgets('renders the app shell', (tester) async {
		pb = PocketBase('http://127.0.0.1');

		await tester.pumpWidget(const TCMoeckmuehlApp());
		await tester.pump();

		expect(find.byType(MaterialApp), findsOneWidget);
		expect(find.byType(AuthWrapper), findsOneWidget);
	});
}
