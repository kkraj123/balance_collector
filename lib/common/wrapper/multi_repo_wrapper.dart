import 'package:collector_app/common/http/api_provider.dart';
import 'package:collector_app/feature/auth/resources/user_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MultiRepositoryWrapper extends StatelessWidget {
  final Widget child;
  final String env;
  const MultiRepositoryWrapper(
      {super.key, required this.child, required this.env});
  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ApiProvider>(
          create: (context) => ApiProvider(
            baseUrl: env,
          ),
          lazy: true,
        ),
        RepositoryProvider<UserRepository>(
          create: (context) => UserRepository(
            apiProvider: RepositoryProvider.of<ApiProvider>(context),
            baseUrl: env,
          )..initialState(),
          lazy: true,
        ),
      ],
      child: child,
    );
  }
}
