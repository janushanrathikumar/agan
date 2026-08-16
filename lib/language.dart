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

      // German Map - Start Page Slides
      'title_1': 'Kulinarische Spezialitäten',
      'text_1':
          'Schweizer Spezialitäten wie hausgemachte Rösti in der Pfanne & authentische sri-lankische Gerichte.',
      'title_2': 'Pizza & Erfrischung',
      'text_2':
          'Knusprige Pizza frisch aus dem Ofen und unser hausgemachter, frisch zubereiteter Eistee.',
      'title_3': 'Unsere Räumlichkeiten',
      'text_3':
          'Restaurant (80), Saal (70), Garten (60) & Bar/Fumoir (20 Plätze) für jeden Anlass.',
      'title_4': 'Anlässe & Partyservice',
      'text_4':
          'Ideal für Familienfeiern, Geburtstage, Firmenanlässe, Apéros und Saalvermietung.',
      'lang_toggle': 'EN',

      // Auth & Account
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
      'forgot_password': 'Passwort vergessen?',
      'forgot_password_desc':
          'Geben Sie Ihre registrierte E-Mail-Adresse ein, und wir senden Ihnen einen Link zum Zurücksetzen Ihres Passworts.',
      'email_address': 'E-Mail-Adresse',
      'send_link': 'Link senden',
      'change_password': 'Passwort ändern',
      'new_password': 'Neues Passwort',
      'update': 'Aktualisieren',
      'password_updated': 'Passwort erfolgreich aktualisiert!',
      'send_reset_email': 'Reset-E-Mail senden',
      'reset_email_sent':
          'Link zum Zurücksetzen des Passworts an Ihre E-Mail gesendet!',
      'no_email_associated': 'Keine E-Mail mit diesem Konto verknüpft.',
      'recent_auth_required':
          'Diese Aktion erfordert eine kürzliche Authentifizierung. Bitte melden Sie sich ab, wieder an und versuchen Sie es erneut.',
      'delete_account': 'Konto löschen',
      'delete_account_desc':
          'Möchten Sie Ihr Konto wirklich dauerhaft löschen? Alle Ihre Daten werden unwiderruflich gelöscht und dies kann nicht rückgängig gemacht werden.',
      'delete': 'Löschen',
      'cancel': 'Abbrechen',
      'logout_confirm_desc': 'Möchten Sie sich wirklich abmelden?',
      'unexpected_error': 'Ein unerwarteter Fehler ist aufgetreten.',

      // Errors
      'err_enter_name': 'Bitte geben Sie Ihren Namen ein',
      'err_enter_phone': 'Telefonnummer mit Ländercode eingeben (z.B. +49...)',
      'err_password_len': 'Das Passwort muss mindestens 6 Zeichen lang sein',
      'err_user_not_found': 'Benutzer nicht gefunden',
      'err_phone_not_found':
          'Telefonnummer für die Verifizierung nicht gefunden.',
      'err_reg_failed': 'Registrierung fehlgeschlagen',
      'Error:': 'Fehler:',

      // General UI & Navigation
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

      // Menu Page
      'Drinks': 'Getränke',
      'Foods': 'Speisen',
      'Combos': 'Kombis',
      'All': 'Alle',
      'no_categories': 'Keine Kategorien',
      'no_items': 'Keine Artikel',
      'Search all items...': 'Alle Artikel suchen...',
      'No matching items found.': 'Keine passenden Artikel gefunden.',
      'No items available.': 'Keine Artikel verfügbar.',
      'This item is currently not available for ':
          'Dieser Artikel ist derzeit nicht verfügbar für ',
      'Currently unavailable for ': 'Derzeit nicht verfügbar für ',
      'Please select a Portion / Size.':
          'Bitte wählen Sie eine Portion / Größe.',
      'Please select all required options.':
          'Bitte wählen Sie alle erforderlichen Optionen.',
      'Portion / Size': 'Portion / Größe',
      'This Combo Includes': 'Dieses Kombi beinhaltet',
      'You Save': 'Sie sparen',
      'Add special instructions...': 'Besondere Anweisungen hinzufügen...',
      'Choose add-ons...': 'Extras wählen...',
      'Search Add-ons...': 'Extras suchen...',
      'No add-ons found': 'Keine Extras gefunden',
      'Done': 'Fertig',
      'Free': 'Kostenlos',
      'type': 'Art',
      'sugar': 'Zucker',
      'note_optional': 'Notiz (optional)',
      'quantity': 'Menge',
      'total': 'Gesamt:',
      'add_to_cart': 'In den Warenkorb',
      'buy_now': 'Jetzt kaufen',
      'added_to_cart': 'Zum Warenkorb hinzugefügt',

      // Home & Table Picker
      'Table': 'Tisch',
      'Chair': 'Stuhl',
      'Special Offers & Combos': 'Sonderangebote & Kombis',
      'Today\'s best deals and combos for you':
          'Die besten Angebote und Kombis von heute für Sie',
      'Select Table': 'Tisch auswählen',
      'Scan the table QR code or type table number manually':
          'Scannen Sie den Tisch-QR-Code oder geben Sie die Tischnummer manuell ein',
      'Scan the table QR code to proceed':
          'Scannen Sie den Tisch-QR-Code, um fortzufahren',
      'Scan QR': 'QR scannen',
      'Type No.': 'Nr. eingeben',
      'Table:': 'Tisch:',
      'Next (Select Chair)': 'Weiter (Stuhl wählen)',
      'Scan again': 'Erneut scannen',
      'e.g. Table 5 or T5': 'z.B. Tisch 5 oder T5',
      'Select Chair / Seat': 'Stuhl / Platz auswählen',
      'Enter your chair number(s) below (e.g. 1, 2, 3)':
          'Geben Sie unten Ihre Stuhlnummer(n) ein (z.B. 1, 2, 3)',
      'e.g. 1, 2 or 1, 2, 3': 'z.B. 1, 2 oder 1, 2, 3',
      'Go to Menu': 'Zum Menü',
      'View Cart ': 'Warenkorb ansehen ',
      'How would you like to order?': 'Wie möchten Sie bestellen?',
      'Please select before adding to cart':
          'Bitte wählen Sie, bevor Sie zum Warenkorb hinzufügen',
      'Welcome to our Restaurant!': 'Willkommen in unserem Restaurant!',
      'Check out our menu for delicious meals.':
          'Sehen Sie sich unsere Speisekarte für leckere Gerichte an.',
      'Please login first': 'Bitte loggen Sie sich zuerst ein',
      'Select Portion / Size': 'Portion / Größe auswählen',
      'Any special requests...': 'Besondere Wünsche...',
      'Choose Option': 'Option wählen',
      'Add-ons': 'Extras',
      'Required': 'Erforderlich',
      'Optional': 'Optional',

      // Checkout & Payments
      'Order Summary': 'Bestellübersicht',
      'No items found in cart': 'Keine Artikel im Warenkorb gefunden',
      'Customer & Dining Details': 'Kunden- & Restaurantdetails',
      'Username': 'Benutzername',
      'Role': 'Rolle',
      'Method': 'Methode',
      'Table No': 'Tisch Nr.',
      'Your Items': 'Ihre Artikel',
      'Size': 'Größe',
      'Extras:': 'Extras:',
      'Note:': 'Notiz:',
      'Subtotal': 'Zwischensumme',
      'Service Charge': 'Servicegebühr',
      'Grand Total': 'Gesamtsumme',
      'Total Payment': 'Gesamtzahlung',
      'Confirm Order': 'Bestellung bestätigen',
      'Order Placed Successfully!': 'Bestellung erfolgreich aufgegeben!',
      'User:': 'Benutzer:',
      'Total:': 'Gesamt:',
      'Your Order': 'Ihre Bestellung',
      'Please select Dine-In or Take-Away before checkout':
          'Bitte wählen Sie Dine-In oder Take-Away vor dem Checkout',
      'Select': 'Auswählen',
      'Your cart is empty': 'Ihr Warenkorb ist leer',
      'Add items from the menu to get started':
          'Fügen Sie Artikel aus dem Menü hinzu, um zu beginnen',
      'No table selected — tap to select':
          'Kein Tisch ausgewählt — tippen zum Auswählen',
      'Take-Away order': 'Take-Away Bestellung',
      'Change': 'Ändern',
      'Checkout': 'Kasse',
      'QR scanning not supported on web.\nPlease use a mobile device.':
          'QR-Scannen wird im Web nicht unterstützt.\nBitte verwenden Sie ein mobiles Gerät.',
      'Scanned Table': 'Gescannter Tisch',
      'Enter Chair No. (e.g. 1, 2, A)': 'Stuhl Nr. eingeben (z.B. 1, 2, A)',
      'Confirm Table & Chair': 'Tisch & Stuhl bestätigen',
      'Table No. (e.g. T5 or 12)': 'Tisch Nr. (z.B. T5 oder 12)',
      'Chair No. (e.g. 1, 2, A)': 'Stuhl Nr. (z.B. 1, 2, A)',
      'Your order will be\nprepared for pickup':
          'Ihre Bestellung wird\nzur Abholung vorbereitet',
      'Continue as Take-Away': 'Als Take-Away fortfahren',

      // Orders Page
      'Please login to view orders.':
          'Bitte anmelden, um Bestellungen anzuzeigen.',
      'My Orders': 'Meine Bestellungen',
      'No orders found': 'Keine Bestellungen gefunden',
      'Pending': 'Ausstehend',
      'Items Breakdown': 'Artikelaufschlüsselung',
    },
    'en': {
      // Start Page
      'skip': 'Skip',
      'sign_up': 'Sign Up',
      'log_in': 'Log In',
      'next': 'Next',
      'title_1': 'Culinary Specialties',
      'text_1':
          'Swiss specialties like homemade pan-served Rösti & authentic Sri Lankan dishes.',
      'title_2': 'Fresh Pizza & Drinks',
      'text_2':
          'Crispy stone-baked pizza and our refreshing, freshly brewed homemade iced tea.',
      'title_3': 'Our Spaces & Seating',
      'text_3':
          'Restaurant (80), Hall (70), Garden (60), and Bar/Lounge (20 seats).',
      'title_4': 'Events & Catering',
      'text_4':
          'Perfect for private events, company celebrations, apéros, and venue booking.',
      'lang_toggle': 'DE',

      // Auth & Account
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
      'forgot_password': 'Forgot Password?',
      'forgot_password_desc':
          'Enter your registered email address, and we will send you a link to reset your password.',
      'email_address': 'Email Address',
      'send_link': 'Send Link',
      'change_password': 'Change Password',
      'new_password': 'New Password',
      'update': 'Update',
      'password_updated': 'Password updated successfully!',
      'send_reset_email': 'Send Reset Email',
      'reset_email_sent': 'Password reset link sent to your email!',
      'no_email_associated': 'No email associated with this account.',
      'recent_auth_required':
          'This action requires recent authentication. Please log out, log back in, and try again.',
      'delete_account': 'Delete Account',
      'delete_account_desc':
          'Are you sure you want to permanently delete your account? This will erase all your data and cannot be undone.',
      'delete': 'Delete',
      'cancel': 'Cancel',
      'logout_confirm_desc': 'Are you sure you want to log out?',
      'unexpected_error': 'An unexpected error occurred.',

      // Errors
      'err_enter_name': 'Please enter your name',
      'err_enter_phone': 'Enter phone number with country code (e.g. +49...)',
      'err_password_len': 'Password must be at least 6 characters',
      'err_user_not_found': 'User not found',
      'err_phone_not_found': 'Phone number not found for verification.',
      'err_reg_failed': 'Registration failed',
      'Error:': 'Error:',

      // General UI & Navigation
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

      // Menu Page
      'Drinks': 'Drinks',
      'Foods': 'Food',
      'Combos': 'Combos',
      'All': 'All',
      'no_categories': 'No categories',
      'no_items': 'No items',
      'Search all items...': 'Search all items...',
      'No matching items found.': 'No matching items found.',
      'No items available.': 'No items available.',
      'This item is currently not available for ':
          'This item is currently not available for ',
      'Currently unavailable for ': 'Currently unavailable for ',
      'Please select a Portion / Size.': 'Please select a Portion / Size.',
      'Please select all required options.':
          'Please select all required options.',
      'Portion / Size': 'Portion / Size',
      'This Combo Includes': 'This Combo Includes',
      'You Save': 'You Save',
      'Add special instructions...': 'Add special instructions...',
      'Choose add-ons...': 'Choose add-ons...',
      'Search Add-ons...': 'Search Add-ons...',
      'No add-ons found': 'No add-ons found',
      'Done': 'Done',
      'Free': 'Free',
      'type': 'Type',
      'sugar': 'Sugar',
      'note_optional': 'Note (optional)',
      'quantity': 'Quantity',
      'total': 'Total:',
      'add_to_cart': 'Add to Cart',
      'buy_now': 'Buy now',
      'added_to_cart': 'Added to cart',

      // Home & Table Picker
      'Table': 'Table',
      'Chair': 'Chair',
      'Special Offers & Combos': 'Special Offers & Combos',
      'Today\'s best deals and combos for you':
          'Today\'s best deals and combos for you',
      'Select Table': 'Select Table',
      'Scan the table QR code or type table number manually':
          'Scan the table QR code or type table number manually',
      'Scan the table QR code to proceed': 'Scan the table QR code to proceed',
      'Scan QR': 'Scan QR',
      'Type No.': 'Type No.',
      'Table:': 'Table:',
      'Next (Select Chair)': 'Next (Select Chair)',
      'Scan again': 'Scan again',
      'e.g. Table 5 or T5': 'e.g. Table 5 or T5',
      'Select Chair / Seat': 'Select Chair / Seat',
      'Enter your chair number(s) below (e.g. 1, 2, 3)':
          'Enter your chair number(s) below (e.g. 1, 2, 3)',
      'e.g. 1, 2 or 1, 2, 3': 'e.g. 1, 2 or 1, 2, 3',
      'Go to Menu': 'Go to Menu',
      'View Cart ': 'View Cart ',
      'How would you like to order?': 'How would you like to order?',
      'Please select before adding to cart':
          'Please select before adding to cart',
      'Welcome to our Restaurant!': 'Welcome to our Restaurant!',
      'Check out our menu for delicious meals.':
          'Check out our menu for delicious meals.',
      'Please login first': 'Please login first',
      'Select Portion / Size': 'Select Portion / Size',
      'Any special requests...': 'Any special requests...',
      'Choose Option': 'Choose Option',
      'Add-ons': 'Add-ons',
      'Required': 'Required',
      'Optional': 'Optional',

      // Checkout & Payments
      'Order Summary': 'Order Summary',
      'No items found in cart': 'No items found in cart',
      'Customer & Dining Details': 'Customer & Dining Details',
      'Username': 'Username',
      'Role': 'Role',
      'Method': 'Method',
      'Table No': 'Table No',
      'Your Items': 'Your Items',
      'Size': 'Size',
      'Extras:': 'Extras:',
      'Note:': 'Note:',
      'Subtotal': 'Subtotal',
      'Service Charge': 'Service Charge',
      'Grand Total': 'Grand Total',
      'Total Payment': 'Total Payment',
      'Confirm Order': 'Confirm Order',
      'Order Placed Successfully!': 'Order Placed Successfully!',
      'User:': 'User:',
      'Total:': 'Total:',
      'Your Order': 'Your Order',
      'Please select Dine-In or Take-Away before checkout':
          'Please select Dine-In or Take-Away before checkout',
      'Select': 'Select',
      'Your cart is empty': 'Your cart is empty',
      'Add items from the menu to get started':
          'Add items from the menu to get started',
      'No table selected — tap to select': 'No table selected — tap to select',
      'Take-Away order': 'Take-Away order',
      'Change': 'Change',
      'Checkout': 'Checkout',
      'QR scanning not supported on web.\nPlease use a mobile device.':
          'QR scanning not supported on web.\nPlease use a mobile device.',
      'Scanned Table': 'Scanned Table',
      'Enter Chair No. (e.g. 1, 2, A)': 'Enter Chair No. (e.g. 1, 2, A)',
      'Confirm Table & Chair': 'Confirm Table & Chair',
      'Table No. (e.g. T5 or 12)': 'Table No. (e.g. T5 or 12)',
      'Chair No. (e.g. 1, 2, A)': 'Chair No. (e.g. 1, 2, A)',
      'Your order will be\nprepared for pickup':
          'Your order will be\nprepared for pickup',
      'Continue as Take-Away': 'Continue as Take-Away',

      // Orders Page
      'Please login to view orders.': 'Please login to view orders.',
      'My Orders': 'My Orders',
      'No orders found': 'No orders found',
      'Pending': 'Pending',
      'Items Breakdown': 'Items Breakdown',
    },
  };

  static String getText(String key) {
    return _localizedValues[currentLanguage]?[key] ?? key;
  }
}
