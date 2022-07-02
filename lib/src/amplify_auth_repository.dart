import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_auth_repository/amplify_auth_repository.dart';
import 'package:amplify_auth_repository/config/amplifyconfiguration.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';

/// Enum to show auth status
enum AuthenticationStatus {
  unknown,
  authenticated,
  authenticatedOnSigup,
  unauthenticated
}

class AuthenticationException implements Exception {
  const AuthenticationException({required this.message});

  final String message;
}

/// {@template amplify_auth_repository}
/// Repository which manages user authentication.
/// {@endtemplate}
class AuthenticationRepository {
  /// {@macro amplify_auth_repository}
  AuthenticationRepository({
    AmplifyAuthCognito? amplifyAuth,
    AmplifyStorageS3? storage,
  })  : _amplifyAuth = amplifyAuth ?? AmplifyAuthCognito(),
        _storage = storage ?? AmplifyStorageS3();

  final AmplifyAuthCognito _amplifyAuth;
  final AmplifyStorageS3 _storage;
  late final StreamSubscription<HubEvent> subscription;
  final _controller = StreamController<AuthenticationStatus>();

  /// Current user
  User user = User.empty;

  /// Session token of current user
  String? get sessionToken => user.sessionToken;

  String? get identityId => user.identityId;

  Future<void> configureAmplify() async {
    await Amplify.addPlugins([_amplifyAuth, _storage]);
    if (!Amplify.isConfigured) {
      try {
        await Amplify.configure(amplifyconfig);
      } on AmplifyAlreadyConfiguredException {
        log(
          'Amplify was already configured. Looks like app restarted on android.',
        );
      }
    }
  }

  /// StreamSubscription of [HubEvent] which will listen to
  /// the authentication state changes and emits [AuthenticationStatus].
  StreamSubscription<AuthenticationStatus> listenAuthEvents(
    void Function(AuthenticationStatus)? onData,
  ) {
    subscription = Amplify.Hub.listen([HubChannel.Auth], (event) {
      log("AUTH EVENT: ${event.eventName}");
      switch (event.eventName) {
        case "SIGNED_OUT":
          _controller.add(AuthenticationStatus.unauthenticated);
          break;
        case "SESSION_EXPIRED":
          _controller.add(AuthenticationStatus.unauthenticated);
          break;
        case "USER_DELETED":
          _controller.add(AuthenticationStatus.unauthenticated);
          break;
        default:
          break;
      }
    });
    return _controller.stream.listen(onData);
  }

  void dispose() {
    subscription.cancel();
    _controller.close();
  }

  /// Returns the current user.
  Future<User> getCurrentUser() async {
    try {
      final authUser = await Amplify.Auth.getCurrentUser();
      user = user.copyWith(id: authUser.userId, phoneNumber: authUser.username);
      return User(id: authUser.userId, phoneNumber: authUser.username);
    } on AmplifyException catch (e) {
      throw AuthenticationException(message: e.message);
    }
  }

  Future<bool> isSignedIn() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      if (session.isSignedIn) {
        _controller.add(AuthenticationStatus.authenticated);
      } else {
        _controller.add(AuthenticationStatus.unauthenticated);
      }
      return session.isSignedIn;
    } on AmplifyException catch (_) {
      return false;
    }
  }

  Future<User?> fetchSession() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession(
        options: CognitoSessionOptions(getAWSCredentials: true),
      ) as CognitoAuthSession;
      return user = user.copyWith(
        sessionToken: session.userPoolTokens?.idToken,
        identityId: session.identityId,
      );
    } on AmplifyException catch (_) {
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await Amplify.Auth.signOut();
    } on AmplifyException catch (e) {
      throw AuthenticationException(message: e.message);
    }
  }

  Future<void> globalSignOut() async {
    try {
      await Amplify.Auth.signOut(
        options: const SignOutOptions(globalSignOut: true),
      );
    } on AmplifyException catch (e) {
      throw AuthenticationException(message: e.message);
    }
  }

  Future<void> deleteUser() => Amplify.Auth.deleteUser();

  /// Creates a new user with the provided [phoneNumber] and [password].
  ///
  /// Throws a [AmplifyException] if an exception occurs.
  Future<bool> signUp({
    required String phoneNumber,
    required String password,
  }) async {
    final userAttributes = {
      CognitoUserAttributeKey.phoneNumber: phoneNumber,
      CognitoUserAttributeKey.email: ""
    };
    try {
      final result = await Amplify.Auth.signUp(
        username: phoneNumber.trim(),
        password: password.trim(),
        options: CognitoSignUpOptions(userAttributes: userAttributes),
      );
      return result.isSignUpComplete;
    } on AmplifyException catch (e) {
      throw AuthenticationException(message: e.message);
    }
  }

  Future<bool> confirmSignUp({
    required String phoneNumber,
    required String confirmationCode,
  }) async {
    try {
      final result = await Amplify.Auth.confirmSignUp(
        username: phoneNumber.trim(),
        confirmationCode: confirmationCode.trim(),
      );
      return result.isSignUpComplete;
    } on AmplifyException catch (e) {
      throw AuthenticationException(message: e.message);
    }
  }

  Future<void> resendSignUpCode({required String phoneNumber}) async {
    try {
      await Amplify.Auth.resendSignUpCode(
        username: phoneNumber.trim(),
      );
    } on AmplifyException catch (e) {
      throw AuthenticationException(message: e.message);
    }
  }

  /// Signs in with the provided [phoneNumber] and [password].
  ///
  /// Throws a [AmplifyException] if an exception occurs.
  Future<bool> signIn({
    required String phoneNumber,
    required String password,
    bool signUpFlow = false,
  }) async {
    try {
      final result = await Amplify.Auth.signIn(
        username: phoneNumber.trim(),
        password: password.trim(),
      );
      if (result.isSignedIn) {
        if (signUpFlow) {
          _controller.add(AuthenticationStatus.authenticatedOnSigup);
        } else {
          _controller.add(AuthenticationStatus.authenticated);
        }
      }
      return result.isSignedIn;
    } on AmplifyException catch (e) {
      throw AuthenticationException(message: e.message);
    }
  }

  Future<bool> confirmSignIn({required String confirmationCode}) async {
    try {
      final result = await Amplify.Auth.confirmSignIn(
        confirmationValue: confirmationCode.trim(),
      );
      return result.isSignedIn;
    } on AmplifyException catch (e) {
      throw AuthenticationException(message: e.message);
    }
  }

  Future<bool> resetPassword({required String phoneNumber}) async {
    try {
      final result = await Amplify.Auth.resetPassword(
        username: phoneNumber.trim(),
      );
      return result.isPasswordReset;
    } on AmplifyException catch (e) {
      throw AuthenticationException(message: e.message);
    }
  }

  Future<void> confirmReset({
    required String phoneNumber,
    required String password,
    required String confirmationCode,
  }) async {
    try {
      await Amplify.Auth.confirmResetPassword(
        username: phoneNumber.trim(),
        newPassword: password.trim(),
        confirmationCode: confirmationCode.trim(),
      );
    } on AmplifyException catch (e) {
      throw AuthenticationException(message: e.message);
    }
  }

  Future<void> updatePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      await Amplify.Auth.updatePassword(
        oldPassword: oldPassword.trim(),
        newPassword: newPassword.trim(),
      );
    } on AmplifyException catch (e) {
      throw AuthenticationException(message: e.message);
    }
  }

  Future<bool> updateAttributes({
    required String picture,
    required String fullName,
    required String occupation,
    required String company,
    required String age,
    required String gender,
  }) async {
    final pictureKey = CognitoUserAttributeKey.parse("picture");
    final nameKey = CognitoUserAttributeKey.parse("name");
    const occupationKey = CognitoUserAttributeKey.custom("occupation");
    const companyKey = CognitoUserAttributeKey.custom("company");
    const ageKey = CognitoUserAttributeKey.custom("age");
    const genderKey = CognitoUserAttributeKey.custom("gender");

    final attributes = [
      AuthUserAttribute(userAttributeKey: pictureKey, value: picture),
      AuthUserAttribute(userAttributeKey: nameKey, value: fullName),
      AuthUserAttribute(userAttributeKey: occupationKey, value: occupation),
      AuthUserAttribute(userAttributeKey: companyKey, value: company),
      AuthUserAttribute(userAttributeKey: ageKey, value: age),
      AuthUserAttribute(userAttributeKey: genderKey, value: gender),
    ];
    try {
      final result =
          await Amplify.Auth.updateUserAttributes(attributes: attributes);
      return result.values
          .toList()
          .every((element) => element.isUpdated == true);
    } on AmplifyException catch (e) {
      throw AuthenticationException(message: e.message);
    }
  }

  Future<void> getAllAttributes() async {
    try {
      final result = await Amplify.Auth.fetchUserAttributes();
      for (final e in result) {
        log("User Attr: ${e.userAttributeKey}:${e.value}");
      }
    } on AmplifyException catch (e) {
      throw AuthenticationException(message: e.message);
    }
  }

  Future<String?> upload(File file) async {
    try {
      final Map<String, String> metadata = <String, String>{};
      metadata['name'] = user.id;
      metadata['desc'] = 'Users profile picture';

      final options = S3UploadFileOptions(
        accessLevel: StorageAccessLevel.private,
        metadata: metadata,
      );

      final result = await Amplify.Storage.uploadFile(
        key: user.id,
        local: file,
        options: options,
        onProgress: (progress) {},
      );
      return result.key;
    } on AmplifyException catch (e) {
      throw AuthenticationException(message: e.message);
    }
  }

  Future<String> getUrl(String key) async {
    try {
      final options = S3GetUrlOptions(
        accessLevel: StorageAccessLevel.private,
        expires: 10000,
      );
      final result = await Amplify.Storage.getUrl(key: key, options: options);

      return result.url;
    } on AmplifyException catch (e) {
      throw AuthenticationException(message: e.message);
    }
  }
}
