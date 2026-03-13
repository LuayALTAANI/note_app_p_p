import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'routing/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: NoteAppPP()));
}

class NoteAppPP extends ConsumerWidget {
  const NoteAppPP({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'Note App P P',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        ),
        routerConfig: router,
        
      ),
    );
  }
}