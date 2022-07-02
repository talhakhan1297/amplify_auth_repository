import 'package:equatable/equatable.dart';

/// {@template user}
/// User model
///
/// [User.empty] represents an unauthenticated user.
/// {@endtemplate}
class User extends Equatable {
  /// {@macro user}
  const User({
    required this.id,
    this.phoneNumber,
    this.photo,
    this.fullName,
    this.occupation,
    this.company,
    this.age,
    this.gender,
    this.sessionToken,
    this.identityId,
  });

  /// The current user's phone number.
  final String? phoneNumber;

  /// The current user's id.
  final String id;

  /// Url for the current user's photo.
  final String? photo;

  /// The current user's full name.
  final String? fullName;

  /// The current user's occupation.
  final String? occupation;

  /// The current user's company.
  final String? company;

  /// The current user's age.
  final int? age;

  /// The current user's gender.
  final int? gender;

  /// The current user's session token.
  final String? sessionToken;

  /// The current user's identity.
  final String? identityId;

  /// Empty user which represents an unauthenticated user.
  static const empty = User(id: '');

  /// Convenience getter to determine whether the current user is empty.
  bool get isEmpty => this == User.empty;

  /// Convenience getter to determine whether the current user is not empty.
  bool get isNotEmpty => this != User.empty;

  User copyWith({
    String? id,
    String? phoneNumber,
    String? photo,
    String? fullName,
    String? occupation,
    String? company,
    int? age,
    int? gender,
    String? sessionToken,
    String? identityId,
  }) {
    return User(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photo: photo ?? this.photo,
      fullName: fullName ?? this.fullName,
      occupation: occupation ?? this.occupation,
      company: company ?? this.company,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      sessionToken: sessionToken ?? this.sessionToken,
      identityId: identityId ?? this.identityId,
    );
  }

  @override
  List<Object?> get props => [
        id,
        phoneNumber,
        photo,
        fullName,
        occupation,
        company,
        age,
        gender,
        sessionToken,
        identityId,
      ];
}
