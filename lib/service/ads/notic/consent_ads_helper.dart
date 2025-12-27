import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class ConsentAdsHelper {
  Future<FormError?> initializeConsent() async {
    final completer = Completer<FormError?>();
    final params = ConsentRequestParameters();

    ConsentInformation.instance.requestConsentInfoUpdate(params, () async {
      // Success callback
      bool formAvailable = await ConsentInformation.instance.isConsentFormAvailable();
      if (formAvailable) {
        await _loadConsentForm();
      } else {
        await MobileAds.instance.initialize();
      }
      completer.complete();
    }, (error) {
      // Failure callback
      completer.complete(error);
    });

    return completer.future;
  }

  Future<FormError?> _loadConsentForm() async {
    final completer = Completer<FormError?>();
    ConsentForm.loadConsentForm((consentForm) async {
      final status = await ConsentInformation.instance.getConsentStatus();
      if (status == ConsentStatus.required) {
        consentForm.show((formError) async {
          await _loadConsentForm();
          completer.complete(formError);
        });
      } else {
        await MobileAds.instance.initialize();
        completer.complete();
      }
    }, (FormError? error) {
      completer.complete(error);
    });

    return completer.future;
  }
}
