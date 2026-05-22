// lib/language.dart
import 'package:flutter/material.dart';

class AppLanguage {
  static String currentLanguage = 'de';

  static final Map<String, Map<String, String>> _localizedValues = {
    'de': {
      // Start Page
      'skip': 'Überspringen',
      'sign_up': 'Registrieren',
      'log_in': 'Anmelden',
      'next': 'Weiter',
      'title_1': 'Bestellen wie ein König',
      'text_1':
          'Ohne Anstehen. Bestellen Sie Ihre Lieblingsgerichte mit wenigen Klicks.',
      'title_2': 'Schnelle Lieferung',
      'text_2': 'Schnell an Ihren Tisch oder an die Tür geliefert.',
      'title_3': 'Prämien sammeln',
      'text_3': 'Punkte sammeln. Exklusive Angebote freischalten.',
      'title_4': 'Auf dem Laufenden bleiben',
      'text_4': 'Verfolgen Sie Bestellungen und erhalten Sie Updates.',
      'lang_toggle': 'EN',

      // Sign In & Sign Up Pages
      'sign_in_title': 'Anmelden',
      'welcome_back': 'Willkommen zurück',
      'email_or_phone': 'E-Mail oder Telefon (mit +)',
      'password': 'Passwort',
      'dont_have_account': 'Noch kein Konto? Registrieren',
      'sign_up_title': 'Registrieren',
      'create_account': 'Konto erstellen',
      'full_name': 'Vollständiger Name',
      'phone_hint': 'Telefonnummer (z.B. +49151234567)',
      'get_otp': 'OTP-Code erhalten',
      'already_have_account': 'Bereits ein Konto? Anmelden',

      // Error Messages
      'err_enter_name': 'Bitte geben Sie Ihren Namen ein',
      'err_enter_phone': 'Telefonnummer mit Ländercode eingeben (z.B. +49...)',
      'err_password_len': 'Das Passwort muss mindestens 6 Zeichen lang sein',
      'err_user_not_found': 'Benutzer nicht gefunden',
      'err_phone_not_found':
          'Telefonnummer für die Verifizierung nicht gefunden.',
      'err_reg_failed': 'Registrierung fehlgeschlagen',

      'take_away_selected': 'Zum Mitnehmen ausgewählt',
      'rewards': 'Prämien',
      'balance': 'Guthaben',
      'qr_scanner': 'QR-Scanner',
      'dine_in': 'Vor Ort essen',
      'take_away': 'Zum Mitnehmen',

      'welcome': 'Willkommen',
      'home': 'Startseite',
      'menu': 'Menü',
      'reward': 'Prämien',
      'account': 'Konto',
      'sign_in': 'Anmelden',
      'sign_up': 'Registrieren',
      'log_out': 'Abmelden',
      'logged_out': 'Erfolgreich abgemeldet',

      // Menu Page - Deutsch
      'drinks': 'Getränke',
      'foods': 'Speisen',
      'no_categories': 'Keine Kategorien',
      'no_items': 'Keine Artikel',
      'type': 'Art',
      'sugar': 'Zucker',
      'note_optional': 'Notiz (optional)',
      'quantity': 'Menge',
      'total': 'Gesamt:',
      'add_to_cart': 'In den Warenkorb', // (Add to chat என்பதற்கு பதிலாக)
      'buy_now': 'Jetzt kaufen',
      'added_to_cart': 'Zum Warenkorb hinzugefügt',
    },
    'en': {
      // Start Page
      'skip': 'Skip',
      'sign_up': 'Sign Up',
      'log_in': 'Log In',
      'next': 'Next',
      'title_1': 'Order like a King',
      'text_1': 'Skip the line. Order your favourite meals in a few taps.',
      'title_2': 'Fast Delivery',
      'text_2': 'Get it to your table or door quickly.',
      'title_3': 'Earn Rewards',
      'text_3': 'Collect points. Unlock exclusive offers.',
      'title_4': 'Stay Connected',
      'text_4': 'Track orders and get updates.',
      'lang_toggle': 'DE',

      // Sign In & Sign Up Pages
      'sign_in_title': 'Sign In',
      'welcome_back': 'Welcome back',
      'email_or_phone': 'Email or Phone (with +)',
      'password': 'Password',
      'dont_have_account': "Don't have an account? Sign up",
      'sign_up_title': 'Sign Up',
      'create_account': 'Create Account',
      'full_name': 'Full Name',
      'phone_hint': 'Phone Number (e.g. +49151234567)',
      'get_otp': 'Get OTP Code',
      'already_have_account': 'Already have an account? Sign in',

      // Error Messages
      'err_enter_name': 'Please enter your name',
      'err_enter_phone': 'Enter phone number with country code (e.g. +49...)',
      'err_password_len': 'Password must be at least 6 characters',
      'err_user_not_found': 'User not found',
      'err_phone_not_found': 'Phone number not found for verification.',
      'err_reg_failed': 'Registration failed',
      'take_away_selected': 'Take Away selected',
      'rewards': 'Rewards',
      'balance': 'Balance',
      'qr_scanner': 'QR Scanner',
      'dine_in': 'Dine In',
      'take_away': 'Take Away',
      'welcome': 'Welcome',
      'home': 'Home',
      'menu': 'Menu',
      'reward': 'Reward',
      'account': 'Account',
      'sign_in': 'Sign In',
      'sign_up': 'Sign Up',
      'log_out': 'Log Out',
      'logged_out': 'Successfully logged out',

      'drinks': 'Drinks',
      'foods': 'Food',
      'no_categories': 'No categories',
      'no_items': 'No items',
      'type': 'Type',
      'sugar': 'Sugar',
      'note_optional': 'Note (optional)',
      'quantity': 'Quantity',
      'total': 'Total:',
      'add_to_cart': 'Add to Cart',
      'buy_now': 'Buy now',
      'added_to_cart': 'Added to cart',
    },
  };

  static String getText(String key) {
    return _localizedValues[currentLanguage]?[key] ?? key;
  }
}
