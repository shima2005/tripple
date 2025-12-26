import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:new_tripple/core/theme/app_theme.dart';
import 'package:new_tripple/features/discover/data/discover_repository.dart';
import 'package:new_tripple/features/discover/domain/discover_cubit.dart';
import 'package:new_tripple/firebase_options.dart'; // flutterfire configureで生成される
import 'package:new_tripple/features/trip/data/trip_repository.dart';
import 'package:new_tripple/features/trip/domain/trip_cubit.dart';
import 'package:new_tripple/main_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:new_tripple/features/auth/data/auth_repository.dart';
import 'package:new_tripple/features/auth/presentation/screens/login_screen.dart';
import 'package:new_tripple/features/settings/domain/settings_cubit.dart';
import 'package:new_tripple/features/settings/domain/settings_state.dart';
import 'package:new_tripple/features/user/data/user_repository.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  //TODO Web開発中は永続化をOFFにするとキャッシュトラブルが減る
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (_) => AuthRepository()),
        RepositoryProvider(create: (_) => TripRepository()),
        RepositoryProvider(create: (_) => UserRepository()),
        RepositoryProvider(create: (_) => DiscoverRepository()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => TripCubit(tripRepository: context.read<TripRepository>()),
          ),
          BlocProvider(
            create: (context) => SettingsCubit(userRepository: context.read<UserRepository>())..loadSettings(),
          ),
          BlocProvider(
            create: (context) => DiscoverCubit(discoverRepository: context.read<DiscoverRepository>())
          ),
        ],
        child: BlocBuilder<SettingsCubit, SettingsState>(
          buildWhen: (previous, current) {
            return previous.themeColor != current.themeColor || 
                   previous.themeMode != current.themeMode;
          },
          builder: (context, settingsState) {
            return MaterialApp(
              title: 'tripple',
              // 👇 テーマを動的に変更
              theme: AppTheme.light,// ライト
        
              // 👇 ここでログイン状態を監視！
              home: StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (context, snapshot) {
                  // 1. 読み込み中
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(body: Center(child: CircularProgressIndicator()));
                  }

                  // 2. ログイン済みなら MainScreen へ
                  if (snapshot.hasData) {
                    // ログインユーザーIDでデータをロード
                    final userId = snapshot.data!.uid;
                    context.read<TripCubit>().loadMyTrips(userId); 

                    return const MainScreen();
                  }

                  // 3. 未ログインなら LoginScreen へ
                  return const LoginScreen();
                },
              ),
            );
          }
        )
      ),
    );
  }
}