import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../ui/screens/folder/folder_screen.dart';
import '../ui/screens//item/item_details_screen.dart';
import '../ui/screens/settings_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/folder/root',
    routes: [
      GoRoute(
        path: '/folder/:id',
        builder: (context, state) => FolderScreen(folderId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/item/:id',
        builder: (context, state) => ItemDetailsScreen(itemId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
