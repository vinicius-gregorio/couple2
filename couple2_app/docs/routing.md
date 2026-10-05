# Roteamento com GoRouter e Riverpod

Este projeto utiliza **go_router** para navegação e **Riverpod** para gerenciamento de estado.

## Estrutura de Arquivos

```
lib/
├── app/
│   └── routing/
│       ├── router.dart        # Configuração principal do router
│       └── routes.dart        # Rotas globais da aplicação
└── modules/
    └── auth/
        ├── routing/
        │   ├── routes.dart    # Constantes de rotas do módulo auth
        │   └── routing.dart   # Configuração de rotas do módulo auth
        └── ui/
            ├── pages/
            │   └── auth/
            │       └── auth_page.dart   # Tela de login
            └── viewmodels/
                └── auth_viewmodel.dart   # ViewModel com Riverpod
```

## Como Funciona

### 1. Router Principal (`app/routing/router.dart`)

O router principal é configurado com:
- **Redirecionamento automático**: Usuários não autenticados são redirecionados para `/auth/login`
- **Refresh Listenable**: Escuta mudanças no estado de autenticação
- **Integração com Riverpod**: Usa providers para gerenciar dependências

```dart
final routerProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  
  return GoRouter(
    initialLocation: APPRoutes.home,
    redirect: (context, state) => _redirect(context, state, authRepository),
    refreshListenable: AuthNotifier(authRepository),
    routes: [...],
  );
});
```

### 2. Rotas Modulares

Cada módulo tem suas próprias rotas definidas em `routing/routing.dart`:

```dart
final authRoutes = [
  GoRoute(
    path: AuthRoutes.login,
    builder: (context, state) {
      return const AuthPage();
    },
  ),
];
```

### 3. ViewModel com Riverpod

O `AuthViewModel` usa `Notifier<AuthState>`:

```dart
final authViewModelProvider =
    NotifierProvider<AuthViewModel, AuthState>(AuthViewModel.new);

class AuthViewModel extends Notifier<AuthState> {
  @override
  AuthState build() {
    return const AuthState();
  }

  Future<void> login(String username, String password) async {
    // Lógica de login
  }
}
```

### 4. Uso nas Páginas

As páginas usam `ConsumerWidget` ou `ConsumerStatefulWidget` para acessar o state:

```dart
class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);
    final authViewModel = ref.read(authViewModelProvider.notifier);
    
    // Use authState e authViewModel
  }
}
```

## Como Adicionar Novas Rotas

### 1. Defina as Constantes de Rota

No arquivo `routes.dart` do módulo:

```dart
abstract final class MyModuleRoutes {
  static const _root = '/my-module';
  static const myPage = '$_root/my-page';
}
```

### 2. Configure a Rota

No arquivo `routing.dart` do módulo:

```dart
final myModuleRoutes = [
  GoRoute(
    path: MyModuleRoutes.myPage,
    builder: (context, state) {
      return const MyPage();
    },
  ),
];
```

### 3. Adicione ao Router Principal

No arquivo `app/routing/router.dart`:

```dart
import '../../modules/my_module/routing/routing.dart';

routes: [
  // ... outras rotas
  ...myModuleRoutes,
],
```

### 4. Navegue para a Rota

Em qualquer lugar do código:

```dart
// Navegar para a rota
context.go(MyModuleRoutes.myPage);

// Ou empilhar a rota
context.push(MyModuleRoutes.myPage);
```

## Rotas com Parâmetros

Para rotas com parâmetros:

```dart
GoRoute(
  path: '/booking/:id',
  builder: (context, state) {
    final id = int.parse(state.pathParameters['id']!);
    return BookingScreen(id: id);
  },
),
```

## Rotas Aninhadas

Para rotas aninhadas (sub-rotas):

```dart
GoRoute(
  path: '/home',
  builder: (context, state) => const HomePage(),
  routes: [
    GoRoute(
      path: 'search', // será /home/search
      builder: (context, state) => const SearchPage(),
    ),
  ],
),
```

## Integração com ViewModels

### Criar um Provider

```dart
final myViewModelProvider =
    NotifierProvider<MyViewModel, MyState>(MyViewModel.new);
```

### Usar na Página

```dart
class MyPage extends ConsumerWidget {
  const MyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myViewModelProvider);
    final viewModel = ref.read(myViewModelProvider.notifier);
    
    return Scaffold(
      body: state.isLoading 
          ? const CircularProgressIndicator()
          : const YourContent(),
    );
  }
}
```

## Redirecionamento Condicional

O redirecionamento é feito na função `_redirect` em `router.dart`:

```dart
Future<String?> _redirect(
  BuildContext context,
  GoRouterState state,
  IAuthRepository authRepository,
) async {
  final isLoggedIn = await authRepository.isLoggedIn();
  final isLoggingIn = state.matchedLocation.startsWith('/auth');

  if (!isLoggedIn && !isLoggingIn) {
    return AuthRoutes.login; // Redireciona para login
  }

  if (isLoggedIn && isLoggingIn) {
    return APPRoutes.home; // Redireciona para home
  }

  return null; // Sem redirecionamento
}
```

## Dicas

1. **Use constantes para rotas**: Evite strings hardcoded
2. **Organize rotas por módulo**: Mantenha as rotas junto com o código do módulo
3. **Use Riverpod para ViewModels**: Facilita testes e gerenciamento de estado
4. **Teste o redirecionamento**: Certifique-se que os fluxos de autenticação funcionam
5. **Use relative paths em sub-rotas**: Para rotas aninhadas, use caminhos relativos

## Exemplos de Navegação

```dart
// Ir para uma rota (substitui a rota atual)
context.go('/home');

// Empilhar uma rota (adiciona à pilha)
context.push('/details');

// Voltar
context.pop();

// Ir com parâmetros
context.go('/booking/123');

// Substituir rota na pilha
context.replace('/login');
```
