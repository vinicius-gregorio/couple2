import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../modules/lists/routing/routes.dart';
import '../../../providers.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final logout = ref.read(logoutActionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const AppText('Home'),
        leading: userAsync.when(
          data: (user) {
            if (user?.profilePictureUrl == null) {
              return const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircleAvatar(child: Icon(Icons.person)),
              );
            }
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundImage: NetworkImage(user!.profilePictureUrl!),
                onBackgroundImageError: (_, __) {},
              ),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(8.0),
            child: CircleAvatar(child: Icon(Icons.person)),
          ),
          error: (_, __) => const Padding(
            padding: EdgeInsets.all(8.0),
            child: CircleAvatar(child: Icon(Icons.person)),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await logout();
              // if (context.mounted) {
              //   context.go('/auth/login');
              // }
            },
          ),
        ],
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: AppText('Usuário não encontrado'));
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (user.profilePictureUrl != null)
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: NetworkImage(user.profilePictureUrl!),
                    onBackgroundImageError: (_, __) {},
                  )
                else
                  const CircleAvatar(
                    radius: 50,
                    child: Icon(Icons.person, size: 50),
                  ),
                const SizedBox(height: 16),
                AppText(
                  'Bem-vindo, ${user.name}!',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.push(ListsRoutes.lists),
                  icon: const Icon(Icons.list),
                  label: const Text('Our Lists'),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: AppText('Erro ao carregar usuário: $error')),
      ),
    );
  }
}
