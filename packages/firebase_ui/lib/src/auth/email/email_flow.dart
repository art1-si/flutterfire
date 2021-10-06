import 'package:firebase_auth/firebase_auth.dart'
    show
        AuthCredential,
        EmailAuthCredential,
        EmailAuthProvider,
        FirebaseAuth,
        UserCredential;
import 'package:firebase_ui/firebase_ui.dart';

import 'package:firebase_ui/src/auth/auth_controller.dart';

import 'email_provider_configuration.dart';
import '../auth_flow.dart';
import '../auth_state.dart';

class AwaitingEmailAndPassword extends AuthState {}

class UserCreated extends AuthState {
  final UserCredential credential;

  UserCreated(this.credential);
}

class AwaitingEmailVerification extends AuthState {}

class EmailVerificationFailed extends AuthState {
  final Exception exception;

  EmailVerificationFailed(this.exception);
}

class EmailVerified extends AuthState {}

abstract class EmailFlowController extends AuthController {
  void setEmailAndPassword(String email, String password);
  Future<void> verifyEmail();
}

class EmailFlow extends AuthFlow implements EmailFlowController {
  EmailFlow({
    required FirebaseAuth auth,
    required AuthAction action,
  }) : super(
          action: action,
          initialState: AwaitingEmailAndPassword(),
          auth: auth,
        );

  @override
  void setEmailAndPassword(String email, String password) {
    setCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );
  }

  @override
  Future<void> verifyEmail() async {
    final authInitializer = resolveInitializer<FirebaseUIAuthInitializer>();
    final deepLinks = resolveInitializer<FirebaseUIDynamicLinksInitializer>();

    final settings = authInitializer
        .configOf<EmailProviderConfiguration>(EMAIL_PROVIDER_ID)
        .actionCodeSettings;

    value = AwaitingEmailVerification();
    await authInitializer.auth.currentUser!.sendEmailVerification(settings);

    final link = await deepLinks.awaitLink();

    try {
      final code = link.queryParameters['oobCode']!;
      await auth.checkActionCode(code);
      await auth.applyActionCode(code);
      await auth.currentUser!.reload();

      value = EmailVerified();
    } on Exception catch (e) {
      value = EmailVerificationFailed(e);
    }
  }

  @override
  Future<void> onCredentialReceived(AuthCredential credential) async {
    try {
      if (action == AuthAction.signUp) {
        final userCredential = await auth.createUserWithEmailAndPassword(
          email: (credential as EmailAuthCredential).email,
          password: credential.password!,
        );

        value = UserCreated(userCredential);

        // TODO(@lesnitsky): handle email verification
        await signIn(credential);
      } else {
        await super.onCredentialReceived(credential);
      }
    } on Exception catch (e) {
      value = AuthFailed(e);
    }
  }
}