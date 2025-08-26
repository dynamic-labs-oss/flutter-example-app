import 'package:dynamic_sdk/dynamic_sdk.dart';
import 'package:flutter/material.dart';

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Login'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('Login with dynamic'),
            ElevatedButton(
              onPressed: () {
                DynamicSDK.instance.ui.showAuth();
              },
              child: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}
