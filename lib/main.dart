import 'package:dynamic_sdk/dynamic_sdk.dart';
import 'package:flutter/material.dart';
import 'package:my_app/views/login_view.dart';
import 'package:my_app/views/home_view.dart';
import 'package:my_app/views/loading_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  DynamicSDK.init(
    props: ClientProps(
      // Find your environment id at https://app.dynamic.xyz/dashboard/developer
      environmentId: '0322a696-4207-48c6-9ed4-ffb0aa896090',
      appLogoUrl: 'https://demo.dynamic.xyz/favicon-32x32.png',
      appName: 'Dynamic Demo',
      redirectUrl: "flutterdemo://",
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: Stack(
        children: [
          StreamBuilder(
            stream: DynamicSDK.instance.sdk.readyChanges,
            builder: (context, readySnapshot) {
              if (!readySnapshot.hasData || !readySnapshot.data!) {
                return const LoadingView();
              }

              return StreamBuilder(
                stream: DynamicSDK.instance.auth.authenticatedUserChanges,
                builder: (context, snapshot) {
                  if (snapshot.data == null) {
                    return const LoginView();
                  }

                  return const HomeView();
                },
              );
            },
          ),
          DynamicSDK.instance.dynamicWidget,
        ],
      ),
    );
  }
}
