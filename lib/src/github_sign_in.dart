import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'github_sign_in_page.dart';
import 'github_sign_in_result.dart';

class GitHubSignIn {
  final String clientId;
  final String clientSecret;
  final String redirectUrl;
  final String scope;
  final String title;
  final bool? centerTitle;
  final bool allowSignUp;
  final bool clearCache;
  final String? userAgent;

  final String _githubAuthorizedUrl =
      "https://github.com/login/oauth/authorize";
  final String _githubAccessTokenUrl =
      "https://github.com/login/oauth/access_token";

  GitHubSignIn({
    required this.clientId,
    required this.clientSecret,
    required this.redirectUrl,
    this.scope = "user,gist,user:email",
    this.title = "",
    this.centerTitle,
    this.allowSignUp = true,
    this.clearCache = true,
    this.userAgent,
  });

  Future<GitHubSignInResult> signIn(BuildContext context) async {
    Dio dio = Dio(); // Dio instance yaratamiz

    // let's authorize
    var authorizedResult;

    if (kIsWeb) {
      authorizedResult = await launchUrl(
        Uri.parse(_generateAuthorizedUrl()),
        webOnlyWindowName: '_self',
      );
      //push data into authorized result somehow
    } else {
      authorizedResult = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => GitHubSignInPage(
            url: _generateAuthorizedUrl(),
            redirectUrl: redirectUrl,
            userAgent: userAgent,
            clearCache: clearCache,
            title: title,
            centerTitle: centerTitle,
          ),
        ),
      );
    }

    if (authorizedResult == null ||
        authorizedResult.toString().contains('access_denied')) {
      return GitHubSignInResult(
        GitHubSignInResultStatus.cancelled,
        errorMessage: "Sign In attempt has been cancelled.",
      );
    } else if (authorizedResult is Exception) {
      return GitHubSignInResult(
        GitHubSignInResultStatus.failed,
        errorMessage: authorizedResult.toString(),
      );
    }

    // exchange for access token
    String code = authorizedResult;

    try {
      // Dio orqali POST so'rovini yuboramiz
      var response = await dio.post(
        _githubAccessTokenUrl,
        data: {
          "client_id": clientId,
          "client_secret": clientSecret,
          "code": code,
          "redirect_uri": redirectUrl,
        },
        options: Options(
          headers: {"Accept": "application/json"},
        ),
      );

      GitHubSignInResult result;
      if (response.statusCode == 200) {
        var body = response.data;
        result = GitHubSignInResult(
          GitHubSignInResultStatus.ok,
          token: body["access_token"],
        );
      } else {
        result = GitHubSignInResult(
          GitHubSignInResultStatus.failed,
          errorMessage:
              "Unable to obtain token. Received: ${response.statusCode}",
        );
      }
      return result;
    } catch (e) {
      return GitHubSignInResult(
        GitHubSignInResultStatus.failed,
        errorMessage: e.toString(),
      );
    }
  }

  String _generateAuthorizedUrl() {
    return "$_githubAuthorizedUrl?client_id=$clientId&redirect_uri=$redirectUrl&scope=$scope&allow_signup=$allowSignUp";
  }
}
