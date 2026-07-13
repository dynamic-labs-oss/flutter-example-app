import 'package:dynamic_sdk/dynamic_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/views/home_view.dart';

void main() {
  testWidgets('handles nullable wallet metadata', (tester) async {
    const wallet = BaseWallet(address: '0x1234', chain: 'EVM', id: 'wallet-1');

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: WalletCard(wallet: wallet)),
      ),
    );

    expect(find.text('Not Authenticated'), findsOneWidget);
    expect(find.byIcon(Icons.warning), findsOneWidget);
    expect(find.textContaining('Additional Addresses:'), findsNothing);
  });

  testWidgets('shows authenticated wallet metadata', (tester) async {
    const wallet = BaseWallet(
      additionalAddresses: [
        WalletAdditionalAddress(
          address: 'bc1qexample',
          type: WalletAddressType.payment,
        ),
      ],
      address: '0x1234',
      chain: 'EVM',
      id: 'wallet-1',
      isAuthenticated: true,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: WalletCard(wallet: wallet)),
      ),
    );

    expect(find.text('Authenticated'), findsOneWidget);
    expect(find.byIcon(Icons.verified), findsOneWidget);
    expect(find.text('Additional Addresses: 1'), findsOneWidget);
  });
}
