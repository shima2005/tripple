import 'package:equatable/equatable.dart';
import 'package:new_tripple/models/post.dart';

enum DiscoverStatus { initial, loading, loaded, error }

class DiscoverState extends Equatable {
  final DiscoverStatus status;
  final List<Post> posts;
  final String errorMessage;

  const DiscoverState({
    this.status = DiscoverStatus.initial,
    this.posts = const [],
    this.errorMessage = '',
  });

  DiscoverState copyWith({
    DiscoverStatus? status,
    List<Post>? posts,
    String? errorMessage,
  }) {
    return DiscoverState(
      status: status ?? this.status,
      posts: posts ?? this.posts,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, posts, errorMessage];
}