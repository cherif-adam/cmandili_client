import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('fr')
  ];

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot your password?'**
  String get forgotPassword;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @pwdIntro.
  ///
  /// In en, this message translates to:
  /// **'Enter your current password, then choose a new one. You will stay signed in on this device.'**
  String get pwdIntro;

  /// No description provided for @pwdCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get pwdCurrent;

  /// No description provided for @pwdNew.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get pwdNew;

  /// No description provided for @pwdConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get pwdConfirm;

  /// No description provided for @pwdErrorRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get pwdErrorRequired;

  /// No description provided for @pwdErrorWrongCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current password is wrong'**
  String get pwdErrorWrongCurrent;

  /// No description provided for @pwdErrorTooShort.
  ///
  /// In en, this message translates to:
  /// **'At least {min} characters'**
  String pwdErrorTooShort(int min);

  /// No description provided for @pwdErrorMismatch.
  ///
  /// In en, this message translates to:
  /// **'The two passwords do not match'**
  String get pwdErrorMismatch;

  /// No description provided for @pwdErrorSameAsOld.
  ///
  /// In en, this message translates to:
  /// **'The new password is the same as the old one'**
  String get pwdErrorSameAsOld;

  /// No description provided for @pwdErrorReauthNeeded.
  ///
  /// In en, this message translates to:
  /// **'For security, confirm your identity again before changing your password'**
  String get pwdErrorReauthNeeded;

  /// No description provided for @pwdErrorNoSession.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Sign in again.'**
  String get pwdErrorNoSession;

  /// No description provided for @pwdErrorFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not change the password. Try again.'**
  String get pwdErrorFailed;

  /// No description provided for @pwdChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get pwdChangedTitle;

  /// No description provided for @pwdChangedBody.
  ///
  /// In en, this message translates to:
  /// **'Other devices are still signed in with the old session. Sign them out?'**
  String get pwdChangedBody;

  /// No description provided for @pwdKeepOtherDevices.
  ///
  /// In en, this message translates to:
  /// **'Keep them'**
  String get pwdKeepOtherDevices;

  /// No description provided for @pwdSignOutOthers.
  ///
  /// In en, this message translates to:
  /// **'Sign out other devices'**
  String get pwdSignOutOthers;

  /// No description provided for @pwdOtherDevicesSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Other devices have been signed out'**
  String get pwdOtherDevicesSignedOut;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Amana'**
  String get appTitle;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get or;

  /// No description provided for @pleaseEnter.
  ///
  /// In en, this message translates to:
  /// **'Please enter your {field}'**
  String pleaseEnter(Object field);

  /// No description provided for @validEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get validEmail;

  /// No description provided for @passwordLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordLength;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightMode;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @cart.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get cart;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search for food...'**
  String get search;

  /// No description provided for @chooseOnMap.
  ///
  /// In en, this message translates to:
  /// **'Choose on the map'**
  String get chooseOnMap;

  /// No description provided for @chooseOnMapSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Drop the pin exactly where you want the delivery'**
  String get chooseOnMapSubtitle;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @popular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get popular;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See All'**
  String get seeAll;

  /// No description provided for @deliverTo.
  ///
  /// In en, this message translates to:
  /// **'Deliver to'**
  String get deliverTo;

  /// No description provided for @currentLocation.
  ///
  /// In en, this message translates to:
  /// **'Current Location'**
  String get currentLocation;

  /// No description provided for @searchRestaurants.
  ///
  /// In en, this message translates to:
  /// **'Search for restaurants...'**
  String get searchRestaurants;

  /// No description provided for @popularRestaurants.
  ///
  /// In en, this message translates to:
  /// **'Popular Restaurants'**
  String get popularRestaurants;

  /// No description provided for @noFavoritesYet.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get noFavoritesYet;

  /// No description provided for @myCart.
  ///
  /// In en, this message translates to:
  /// **'My Cart'**
  String get myCart;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// No description provided for @deliveryFee.
  ///
  /// In en, this message translates to:
  /// **'Delivery Fee'**
  String get deliveryFee;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @proceedToCheckout.
  ///
  /// In en, this message translates to:
  /// **'Proceed to Checkout'**
  String get proceedToCheckout;

  /// No description provided for @clearCart.
  ///
  /// In en, this message translates to:
  /// **'Clear Cart'**
  String get clearCart;

  /// No description provided for @clearCartConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove all items from your cart?'**
  String get clearCartConfirmation;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @cartEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty'**
  String get cartEmpty;

  /// No description provided for @addItemsToGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Add items to get started'**
  String get addItemsToGetStarted;

  /// No description provided for @browseRestaurants.
  ///
  /// In en, this message translates to:
  /// **'Browse Restaurants'**
  String get browseRestaurants;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get markAllRead;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get noNotifications;

  /// No description provided for @notificationsWillAppearHere.
  ///
  /// In en, this message translates to:
  /// **'Notifications will appear here'**
  String get notificationsWillAppearHere;

  /// No description provided for @specialInstructions.
  ///
  /// In en, this message translates to:
  /// **'Special Instructions'**
  String get specialInstructions;

  /// No description provided for @typeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get typeMessage;

  /// No description provided for @voiceMessage.
  ///
  /// In en, this message translates to:
  /// **'Voice Message'**
  String get voiceMessage;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @typeInstructionsHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., No onions, extra cheese...'**
  String get typeInstructionsHint;

  /// No description provided for @microphonePermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission denied'**
  String get microphonePermissionDenied;

  /// No description provided for @tapToRecord.
  ///
  /// In en, this message translates to:
  /// **'Tap to record'**
  String get tapToRecord;

  /// No description provided for @tapAgainToStop.
  ///
  /// In en, this message translates to:
  /// **'Tap again to stop'**
  String get tapAgainToStop;

  /// No description provided for @addSpecialInstructions.
  ///
  /// In en, this message translates to:
  /// **'Add Special Instructions'**
  String get addSpecialInstructions;

  /// No description provided for @customization.
  ///
  /// In en, this message translates to:
  /// **'Customization'**
  String get customization;

  /// No description provided for @orderTracking.
  ///
  /// In en, this message translates to:
  /// **'Order Tracking'**
  String get orderTracking;

  /// No description provided for @activeOrder.
  ///
  /// In en, this message translates to:
  /// **'Active Order'**
  String get activeOrder;

  /// No description provided for @confirmReceipt.
  ///
  /// In en, this message translates to:
  /// **'Confirm Receipt'**
  String get confirmReceipt;

  /// No description provided for @orderMarkedDelivered.
  ///
  /// In en, this message translates to:
  /// **'Order marked as delivered!'**
  String get orderMarkedDelivered;

  /// No description provided for @errorLoadingOrder.
  ///
  /// In en, this message translates to:
  /// **'Error loading order'**
  String get errorLoadingOrder;

  /// No description provided for @errorLoadingRestaurants.
  ///
  /// In en, this message translates to:
  /// **'Error loading restaurants'**
  String get errorLoadingRestaurants;

  /// No description provided for @errorLoadingMenu.
  ///
  /// In en, this message translates to:
  /// **'Error loading menu'**
  String get errorLoadingMenu;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @selectDeliveryAddress.
  ///
  /// In en, this message translates to:
  /// **'Select delivery address'**
  String get selectDeliveryAddress;

  /// No description provided for @deliveryAddress.
  ///
  /// In en, this message translates to:
  /// **'Delivery Address'**
  String get deliveryAddress;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get paymentMethod;

  /// No description provided for @cashOnDelivery.
  ///
  /// In en, this message translates to:
  /// **'Cash on Delivery'**
  String get cashOnDelivery;

  /// No description provided for @payWhenYouReceive.
  ///
  /// In en, this message translates to:
  /// **'Pay when you receive'**
  String get payWhenYouReceive;

  /// No description provided for @payWithKonnect.
  ///
  /// In en, this message translates to:
  /// **'Pay with Konnect'**
  String get payWithKonnect;

  /// No description provided for @secureOnlinePayment.
  ///
  /// In en, this message translates to:
  /// **'Secure online payment (Tunisia)'**
  String get secureOnlinePayment;

  /// No description provided for @orderNotes.
  ///
  /// In en, this message translates to:
  /// **'Order Notes'**
  String get orderNotes;

  /// No description provided for @specialDeliveryInstructions.
  ///
  /// In en, this message translates to:
  /// **'Add any special instructions for delivery...'**
  String get specialDeliveryInstructions;

  /// No description provided for @orderSummary.
  ///
  /// In en, this message translates to:
  /// **'Order Summary'**
  String get orderSummary;

  /// No description provided for @placeOrder.
  ///
  /// In en, this message translates to:
  /// **'Place Order'**
  String get placeOrder;

  /// No description provided for @myOrders.
  ///
  /// In en, this message translates to:
  /// **'My Orders'**
  String get myOrders;

  /// No description provided for @noOrdersYet.
  ///
  /// In en, this message translates to:
  /// **'No orders yet'**
  String get noOrdersYet;

  /// No description provided for @startOrderingMessage.
  ///
  /// In en, this message translates to:
  /// **'Your order history will appear here'**
  String get startOrderingMessage;

  /// No description provided for @helpSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpSupport;

  /// No description provided for @supportTicketSent.
  ///
  /// In en, this message translates to:
  /// **'Support ticket sent! We will contact you soon.'**
  String get supportTicketSent;

  /// No description provided for @savedAddresses.
  ///
  /// In en, this message translates to:
  /// **'Saved Addresses'**
  String get savedAddresses;

  /// No description provided for @noAddressesSaved.
  ///
  /// In en, this message translates to:
  /// **'No addresses saved'**
  String get noAddressesSaved;

  /// No description provided for @addNewAddress.
  ///
  /// In en, this message translates to:
  /// **'Add New Address'**
  String get addNewAddress;

  /// No description provided for @addressRemoved.
  ///
  /// In en, this message translates to:
  /// **'Address removed'**
  String get addressRemoved;

  /// No description provided for @setDefault.
  ///
  /// In en, this message translates to:
  /// **'Set Default'**
  String get setDefault;

  /// No description provided for @noPaymentMethods.
  ///
  /// In en, this message translates to:
  /// **'No payment methods saved'**
  String get noPaymentMethods;

  /// No description provided for @addNewCard.
  ///
  /// In en, this message translates to:
  /// **'Add New Card'**
  String get addNewCard;

  /// No description provided for @noRestaurantsFound.
  ///
  /// In en, this message translates to:
  /// **'No restaurants found'**
  String get noRestaurantsFound;

  /// No description provided for @confirmPasswordShort.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPasswordShort;

  /// No description provided for @pleaseEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get pleaseEnterEmail;

  /// No description provided for @sendResetCode.
  ///
  /// In en, this message translates to:
  /// **'Send the code'**
  String get sendResetCode;

  /// No description provided for @haveCodeEnterIt.
  ///
  /// In en, this message translates to:
  /// **'Already have a code? Enter it →'**
  String get haveCodeEnterIt;

  /// No description provided for @resetCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'The code is invalid or has expired. Request a new one.'**
  String get resetCodeInvalid;

  /// No description provided for @passwordUpdatedBody.
  ///
  /// In en, this message translates to:
  /// **'Your password has been changed. Sign in with your new password.'**
  String get passwordUpdatedBody;

  /// No description provided for @backToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get backToSignIn;

  /// No description provided for @enterResetCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the code'**
  String get enterResetCode;

  /// No description provided for @pleaseEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter a password'**
  String get pleaseEnterPassword;

  /// No description provided for @resetPasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPasswordButton;

  /// No description provided for @eightDigitCode.
  ///
  /// In en, this message translates to:
  /// **'8-digit code'**
  String get eightDigitCode;

  /// No description provided for @enterEightDigitCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the 8-digit code from your email'**
  String get enterEightDigitCode;

  /// No description provided for @callUs.
  ///
  /// In en, this message translates to:
  /// **'Call us'**
  String get callUs;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get somethingWentWrong;

  /// No description provided for @codeSentTo.
  ///
  /// In en, this message translates to:
  /// **'Code sent to {email}'**
  String codeSentTo(String email);

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @cuisinePastry.
  ///
  /// In en, this message translates to:
  /// **'Pastries'**
  String get cuisinePastry;

  /// No description provided for @cuisinePizza.
  ///
  /// In en, this message translates to:
  /// **'Pizza'**
  String get cuisinePizza;

  /// No description provided for @cuisineBurgers.
  ///
  /// In en, this message translates to:
  /// **'Burgers'**
  String get cuisineBurgers;

  /// No description provided for @cuisineSushi.
  ///
  /// In en, this message translates to:
  /// **'Sushi'**
  String get cuisineSushi;

  /// No description provided for @cuisineMexican.
  ///
  /// In en, this message translates to:
  /// **'Mexican'**
  String get cuisineMexican;

  /// No description provided for @cuisineItalian.
  ///
  /// In en, this message translates to:
  /// **'Italian'**
  String get cuisineItalian;

  /// No description provided for @cuisineFastFood.
  ///
  /// In en, this message translates to:
  /// **'Fast food'**
  String get cuisineFastFood;

  /// No description provided for @shopOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get shopOpen;

  /// No description provided for @shopClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get shopClosed;

  /// No description provided for @newShopBadge.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newShopBadge;

  /// No description provided for @deliveryLabel.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get deliveryLabel;

  /// No description provided for @minOrderLabel.
  ///
  /// In en, this message translates to:
  /// **'Min. order'**
  String get minOrderLabel;

  /// No description provided for @deliveryTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Delivery time'**
  String get deliveryTimeLabel;

  /// No description provided for @couldNotLoadShops.
  ///
  /// In en, this message translates to:
  /// **'Could not load shops'**
  String get couldNotLoadShops;

  /// No description provided for @newShopsSoon.
  ///
  /// In en, this message translates to:
  /// **'Check back soon — new shops are on the way.'**
  String get newShopsSoon;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get timeJustNow;

  /// No description provided for @reviewsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} reviews'**
  String reviewsCount(int count);

  /// No description provided for @timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min ago'**
  String timeMinutesAgo(int minutes);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours} h ago'**
  String timeHoursAgo(int hours);

  /// No description provided for @noRestaurantsNearby.
  ///
  /// In en, this message translates to:
  /// **'No restaurant within {km} km of you yet.'**
  String noRestaurantsNearby(int km);

  /// No description provided for @noSupermarketsNearby.
  ///
  /// In en, this message translates to:
  /// **'No supermarket within {km} km of you yet.'**
  String noSupermarketsNearby(int km);

  /// No description provided for @couldNotLoadSupermarkets.
  ///
  /// In en, this message translates to:
  /// **'Could not load supermarkets'**
  String get couldNotLoadSupermarkets;

  /// No description provided for @couldNotGetLocation.
  ///
  /// In en, this message translates to:
  /// **'Unable to get current location. Please enable location services.'**
  String get couldNotGetLocation;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @orderHistory.
  ///
  /// In en, this message translates to:
  /// **'Order History'**
  String get orderHistory;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @paymentMethods.
  ///
  /// In en, this message translates to:
  /// **'Payment Methods'**
  String get paymentMethods;

  /// No description provided for @user.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get user;

  /// No description provided for @viewDeals.
  ///
  /// In en, this message translates to:
  /// **'View Deals'**
  String get viewDeals;

  /// No description provided for @saveUpTo60.
  ///
  /// In en, this message translates to:
  /// **'Save up to 60% on food & groceries!'**
  String get saveUpTo60;

  /// No description provided for @happyHour.
  ///
  /// In en, this message translates to:
  /// **'HAPPY HOUR'**
  String get happyHour;

  /// No description provided for @happyHourLive.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get happyHourLive;

  /// No description provided for @receiptQuestion.
  ///
  /// In en, this message translates to:
  /// **'Did you receive your order?'**
  String get receiptQuestion;

  /// No description provided for @receiptQuestionParcel.
  ///
  /// In en, this message translates to:
  /// **'Was your parcel handed over?'**
  String get receiptQuestionParcel;

  /// No description provided for @receiptYesParcel.
  ///
  /// In en, this message translates to:
  /// **'Yes, delivered'**
  String get receiptYesParcel;

  /// No description provided for @receiptNoParcel.
  ///
  /// In en, this message translates to:
  /// **'No, not delivered'**
  String get receiptNoParcel;

  /// No description provided for @receiptNotDeliveredParcelLink.
  ///
  /// In en, this message translates to:
  /// **'My parcel was not delivered'**
  String get receiptNotDeliveredParcelLink;

  /// No description provided for @receiptReportBodyParcel.
  ///
  /// In en, this message translates to:
  /// **'We will tell our support team that this parcel was not handed over.'**
  String get receiptReportBodyParcel;

  /// No description provided for @receiptAutoIn.
  ///
  /// In en, this message translates to:
  /// **'Confirms automatically in {time}'**
  String receiptAutoIn(String time);

  /// No description provided for @receiptYes.
  ///
  /// In en, this message translates to:
  /// **'Yes, received'**
  String get receiptYes;

  /// No description provided for @receiptNo.
  ///
  /// In en, this message translates to:
  /// **'No, not received'**
  String get receiptNo;

  /// No description provided for @receiptConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Receipt confirmed. Thank you!'**
  String get receiptConfirmed;

  /// No description provided for @receiptAutoConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Receipt confirmed automatically'**
  String get receiptAutoConfirmed;

  /// No description provided for @receiptNotReceivedLink.
  ///
  /// In en, this message translates to:
  /// **'I did not receive my order'**
  String get receiptNotReceivedLink;

  /// No description provided for @receiptReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report a problem?'**
  String get receiptReportTitle;

  /// No description provided for @receiptReportBody.
  ///
  /// In en, this message translates to:
  /// **'We will tell our support team that you did not receive this order.'**
  String get receiptReportBody;

  /// No description provided for @receiptReportConfirm.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get receiptReportConfirm;

  /// No description provided for @receiptReported.
  ///
  /// In en, this message translates to:
  /// **'Reported. Our support team will contact you.'**
  String get receiptReported;

  /// No description provided for @receiptSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save your answer. Please try again.'**
  String get receiptSaveFailed;

  /// No description provided for @receiptTapToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Tap to confirm'**
  String get receiptTapToConfirm;

  /// No description provided for @rateDriverTitle.
  ///
  /// In en, this message translates to:
  /// **'Rate your driver'**
  String get rateDriverTitle;

  /// No description provided for @rateDriverButton.
  ///
  /// In en, this message translates to:
  /// **'Rate the driver'**
  String get rateDriverButton;

  /// No description provided for @rateDriverHint.
  ///
  /// In en, this message translates to:
  /// **'A comment? (optional)'**
  String get rateDriverHint;

  /// No description provided for @rateDriverSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get rateDriverSend;

  /// No description provided for @rateDriverLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get rateDriverLater;

  /// No description provided for @rateDriverThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks for your review!'**
  String get rateDriverThanks;

  /// No description provided for @rateDriverFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send your review right now.'**
  String get rateDriverFailed;

  /// No description provided for @happyHourDealsSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 deal · up to -{percent}%} other{{count} deals · up to -{percent}%}}'**
  String happyHourDealsSummary(int count, int percent);

  /// No description provided for @happyHourEndsIn.
  ///
  /// In en, this message translates to:
  /// **'Ends in {time}'**
  String happyHourEndsIn(String time);

  /// No description provided for @happyHourNoDealsNow.
  ///
  /// In en, this message translates to:
  /// **'No deals right now, check back soon'**
  String get happyHourNoDealsNow;

  /// No description provided for @happyHourUnitsLeft.
  ///
  /// In en, this message translates to:
  /// **'Only {count} left!'**
  String happyHourUnitsLeft(int count);

  /// No description provided for @happyHourShopsTab.
  ///
  /// In en, this message translates to:
  /// **'Shops'**
  String get happyHourShopsTab;

  /// No description provided for @addedToCartWithQuantity.
  ///
  /// In en, this message translates to:
  /// **'{quantity} x {item} added to cart'**
  String addedToCartWithQuantity(int quantity, String item);

  /// No description provided for @chooseAnOption.
  ///
  /// In en, this message translates to:
  /// **'Choose an option'**
  String get chooseAnOption;

  /// No description provided for @errorLoadingItems.
  ///
  /// In en, this message translates to:
  /// **'Could not load the products'**
  String get errorLoadingItems;

  /// No description provided for @supermarketClosedNow.
  ///
  /// In en, this message translates to:
  /// **'This supermarket is closed right now.'**
  String get supermarketClosedNow;

  /// No description provided for @restaurantClosedLabel.
  ///
  /// In en, this message translates to:
  /// **'Restaurant closed'**
  String get restaurantClosedLabel;

  /// No description provided for @organic.
  ///
  /// In en, this message translates to:
  /// **'Organic'**
  String get organic;

  /// No description provided for @happyHourSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The best prices on your favourite dishes'**
  String get happyHourSubtitle;

  /// No description provided for @promos.
  ///
  /// In en, this message translates to:
  /// **'DEALS'**
  String get promos;

  /// No description provided for @promosSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Percentage off at your favourite shops'**
  String get promosSubtitle;

  /// No description provided for @promosBannerCta.
  ///
  /// In en, this message translates to:
  /// **'See the deals'**
  String get promosBannerCta;

  /// No description provided for @happyHourGrab.
  ///
  /// In en, this message translates to:
  /// **'Grab it!'**
  String get happyHourGrab;

  /// No description provided for @addedToCart.
  ///
  /// In en, this message translates to:
  /// **'{item} added to cart'**
  String addedToCart(String item);

  /// No description provided for @happyHourLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load the deals'**
  String get happyHourLoadError;

  /// No description provided for @viewCart.
  ///
  /// In en, this message translates to:
  /// **'View cart'**
  String get viewCart;

  /// No description provided for @cartFromAnotherShopTitle.
  ///
  /// In en, this message translates to:
  /// **'Cart from another shop'**
  String get cartFromAnotherShopTitle;

  /// No description provided for @cartFromAnotherShopMessage.
  ///
  /// In en, this message translates to:
  /// **'Your cart already contains items from another shop. Empty it to add this item?'**
  String get cartFromAnotherShopMessage;

  /// No description provided for @emptyAndAdd.
  ///
  /// In en, this message translates to:
  /// **'Empty and add'**
  String get emptyAndAdd;

  /// No description provided for @newItemBadge.
  ///
  /// In en, this message translates to:
  /// **'NEW'**
  String get newItemBadge;

  /// No description provided for @restaurants.
  ///
  /// In en, this message translates to:
  /// **'Restaurants'**
  String get restaurants;

  /// No description provided for @supermarkets.
  ///
  /// In en, this message translates to:
  /// **'Supermarkets'**
  String get supermarkets;

  /// No description provided for @noDealsRightNow.
  ///
  /// In en, this message translates to:
  /// **'No deals right now. Check back later!'**
  String get noDealsRightNow;

  /// No description provided for @confirmPickupRequest.
  ///
  /// In en, this message translates to:
  /// **'Confirm Pickup Request'**
  String get confirmPickupRequest;

  /// No description provided for @amountToCollect.
  ///
  /// In en, this message translates to:
  /// **'Amount to Collect:'**
  String get amountToCollect;

  /// No description provided for @confirmPickup.
  ///
  /// In en, this message translates to:
  /// **'Confirm Pickup'**
  String get confirmPickup;

  /// No description provided for @pleaseSignInToContinue.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to continue'**
  String get pleaseSignInToContinue;

  /// No description provided for @billPayments.
  ///
  /// In en, this message translates to:
  /// **'Bill Payments'**
  String get billPayments;

  /// No description provided for @internet.
  ///
  /// In en, this message translates to:
  /// **'Internet'**
  String get internet;

  /// No description provided for @electricity.
  ///
  /// In en, this message translates to:
  /// **'Electricity'**
  String get electricity;

  /// No description provided for @water.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get water;

  /// No description provided for @selectProvider.
  ///
  /// In en, this message translates to:
  /// **'Select Provider'**
  String get selectProvider;

  /// No description provided for @noProvidersAvailable.
  ///
  /// In en, this message translates to:
  /// **'No providers available for this category yet.'**
  String get noProvidersAvailable;

  /// No description provided for @howMuchToPay.
  ///
  /// In en, this message translates to:
  /// **'How much to pay?'**
  String get howMuchToPay;

  /// No description provided for @driverWillCollect.
  ///
  /// In en, this message translates to:
  /// **'A driver will come to collect this exact amount from you.'**
  String get driverWillCollect;

  /// No description provided for @amountDt.
  ///
  /// In en, this message translates to:
  /// **'Amount (DT)'**
  String get amountDt;

  /// No description provided for @pleaseEnterAmount.
  ///
  /// In en, this message translates to:
  /// **'Please enter amount'**
  String get pleaseEnterAmount;

  /// No description provided for @pleaseEnterValidAmount.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid amount'**
  String get pleaseEnterValidAmount;

  /// No description provided for @requestDriverForPickup.
  ///
  /// In en, this message translates to:
  /// **'Request Driver for Pickup'**
  String get requestDriverForPickup;

  /// No description provided for @serviceFeeNote.
  ///
  /// In en, this message translates to:
  /// **'Fees: 2.000 DT service fee will be added by driver'**
  String get serviceFeeNote;

  /// No description provided for @pleaseSelectAddress.
  ///
  /// In en, this message translates to:
  /// **'Please select a delivery address'**
  String get pleaseSelectAddress;

  /// No description provided for @pleaseEnterPhone.
  ///
  /// In en, this message translates to:
  /// **'Please enter your phone number so the driver can reach you'**
  String get pleaseEnterPhone;

  /// No description provided for @checkout.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkout;

  /// No description provided for @contactInfo.
  ///
  /// In en, this message translates to:
  /// **'Contact Info'**
  String get contactInfo;

  /// No description provided for @phoneHint.
  ///
  /// In en, this message translates to:
  /// **'Phone number (e.g. +216 12 345 678)'**
  String get phoneHint;

  /// No description provided for @fullNameHint.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullNameHint;

  /// No description provided for @selectAddress.
  ///
  /// In en, this message translates to:
  /// **'Select Address'**
  String get selectAddress;

  /// No description provided for @useCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use Current Location'**
  String get useCurrentLocation;

  /// No description provided for @gettingLocation.
  ///
  /// In en, this message translates to:
  /// **'Getting location...'**
  String get gettingLocation;

  /// No description provided for @enableLocationToDeliver.
  ///
  /// In en, this message translates to:
  /// **'Enable location to deliver here'**
  String get enableLocationToDeliver;

  /// No description provided for @addNew.
  ///
  /// In en, this message translates to:
  /// **'Add New'**
  String get addNew;

  /// No description provided for @defaultLabel.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultLabel;

  /// No description provided for @couldNotGeocode.
  ///
  /// In en, this message translates to:
  /// **'Could not geocode address. Please check the address and try again.'**
  String get couldNotGeocode;

  /// No description provided for @labelHint.
  ///
  /// In en, this message translates to:
  /// **'Label (e.g., Home, Work)'**
  String get labelHint;

  /// No description provided for @fullAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Full Address'**
  String get fullAddressLabel;

  /// No description provided for @apartment.
  ///
  /// In en, this message translates to:
  /// **'Apartment'**
  String get apartment;

  /// No description provided for @floor.
  ///
  /// In en, this message translates to:
  /// **'Floor'**
  String get floor;

  /// No description provided for @saveAddress.
  ///
  /// In en, this message translates to:
  /// **'Save Address'**
  String get saveAddress;

  /// No description provided for @pleaseSelectPickupDropoff.
  ///
  /// In en, this message translates to:
  /// **'Please select both pickup and dropoff locations'**
  String get pleaseSelectPickupDropoff;

  /// No description provided for @recipientDetails.
  ///
  /// In en, this message translates to:
  /// **'Recipient Details'**
  String get recipientDetails;

  /// No description provided for @friendsName.
  ///
  /// In en, this message translates to:
  /// **'Friend\'s Name'**
  String get friendsName;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @packageDetails.
  ///
  /// In en, this message translates to:
  /// **'Package Details'**
  String get packageDetails;

  /// No description provided for @whatAreYouSending.
  ///
  /// In en, this message translates to:
  /// **'What are you sending?'**
  String get whatAreYouSending;

  /// No description provided for @locations.
  ///
  /// In en, this message translates to:
  /// **'Locations'**
  String get locations;

  /// No description provided for @pickupLocation.
  ///
  /// In en, this message translates to:
  /// **'Pickup location'**
  String get pickupLocation;

  /// No description provided for @dropoffLocation.
  ///
  /// In en, this message translates to:
  /// **'Dropoff Location'**
  String get dropoffLocation;

  /// No description provided for @requestCourier.
  ///
  /// In en, this message translates to:
  /// **'Request Courier'**
  String get requestCourier;

  /// No description provided for @recipientAccepted.
  ///
  /// In en, this message translates to:
  /// **'Recipient has accepted the package'**
  String get recipientAccepted;

  /// No description provided for @yourCourier.
  ///
  /// In en, this message translates to:
  /// **'Your Courier'**
  String get yourCourier;

  /// No description provided for @recipient.
  ///
  /// In en, this message translates to:
  /// **'Recipient'**
  String get recipient;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @item.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get item;

  /// No description provided for @driverPhoneNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Driver phone not available yet'**
  String get driverPhoneNotAvailable;

  /// No description provided for @unableToStartCall.
  ///
  /// In en, this message translates to:
  /// **'Unable to start phone call'**
  String get unableToStartCall;

  /// No description provided for @sendParcelTitle.
  ///
  /// In en, this message translates to:
  /// **'Send a parcel'**
  String get sendParcelTitle;

  /// No description provided for @sendParcelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send any item from point A to point B'**
  String get sendParcelSubtitle;

  /// No description provided for @parcelSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Your parcel is on its way!'**
  String get parcelSuccessTitle;

  /// No description provided for @orderSuccessTrackingRef.
  ///
  /// In en, this message translates to:
  /// **'Order #{ref}'**
  String orderSuccessTrackingRef(String ref);

  /// No description provided for @trackMyParcel.
  ///
  /// In en, this message translates to:
  /// **'Track my parcel'**
  String get trackMyParcel;

  /// No description provided for @trackMyOrder.
  ///
  /// In en, this message translates to:
  /// **'Track my order'**
  String get trackMyOrder;

  /// No description provided for @backToHome.
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get backToHome;

  /// No description provided for @foodHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Order a meal'**
  String get foodHeroTitle;

  /// No description provided for @supermarketHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Get your groceries'**
  String get supermarketHeroTitle;

  /// No description provided for @factureHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Pay a bill'**
  String get factureHeroTitle;

  /// No description provided for @supermarketSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Your order is on its way!'**
  String get supermarketSuccessTitle;

  /// No description provided for @factureSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Your bill is being handled!'**
  String get factureSuccessTitle;

  /// No description provided for @cardholderName.
  ///
  /// In en, this message translates to:
  /// **'Cardholder Name'**
  String get cardholderName;

  /// No description provided for @cardNumber.
  ///
  /// In en, this message translates to:
  /// **'Card Number'**
  String get cardNumber;

  /// No description provided for @expiryDate.
  ///
  /// In en, this message translates to:
  /// **'Expiry Date (MM/YY)'**
  String get expiryDate;

  /// No description provided for @phoneNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumberLabel;

  /// No description provided for @bio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get bio;

  /// No description provided for @subject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get subject;

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// No description provided for @submitTicket.
  ///
  /// In en, this message translates to:
  /// **'Submit Ticket'**
  String get submitTicket;

  /// No description provided for @howCanWeHelp.
  ///
  /// In en, this message translates to:
  /// **'How can we help you?'**
  String get howCanWeHelp;

  /// No description provided for @fillFormDescription.
  ///
  /// In en, this message translates to:
  /// **'Fill out the form below and our team will get back to you within 24 hours.'**
  String get fillFormDescription;

  /// No description provided for @failedToSendTicket.
  ///
  /// In en, this message translates to:
  /// **'Failed to send ticket. Please try again.'**
  String get failedToSendTicket;

  /// No description provided for @removedFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Removed from favorites'**
  String get removedFromFavorites;

  /// No description provided for @addedToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Added to favorites'**
  String get addedToFavorites;

  /// No description provided for @addressRemovedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Address removed'**
  String get addressRemovedSuccess;

  /// No description provided for @pleaseEnterSubject.
  ///
  /// In en, this message translates to:
  /// **'Please enter a subject'**
  String get pleaseEnterSubject;

  /// No description provided for @pleaseEnterMessage.
  ///
  /// In en, this message translates to:
  /// **'Please enter your message'**
  String get pleaseEnterMessage;

  /// No description provided for @pleaseEnterName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get pleaseEnterName;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully!'**
  String get profileUpdated;

  /// No description provided for @failedToUpdateProfile.
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile'**
  String get failedToUpdateProfile;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @addYourPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Add your phone number'**
  String get addYourPhoneNumber;

  /// No description provided for @phoneRequiredExplain.
  ///
  /// In en, this message translates to:
  /// **'We need your phone number so drivers can reach you about deliveries. This is a one-time step.'**
  String get phoneRequiredExplain;

  /// No description provided for @phoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid 8-digit Tunisian number'**
  String get phoneInvalid;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @promoCode.
  ///
  /// In en, this message translates to:
  /// **'Promo Code'**
  String get promoCode;

  /// No description provided for @promoCodePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter your promo code'**
  String get promoCodePlaceholder;

  /// No description provided for @billTypeElectricity.
  ///
  /// In en, this message translates to:
  /// **'STEG (electricity)'**
  String get billTypeElectricity;

  /// No description provided for @billTypeWater.
  ///
  /// In en, this message translates to:
  /// **'SONEDE (water)'**
  String get billTypeWater;

  /// No description provided for @billTypeInternet.
  ///
  /// In en, this message translates to:
  /// **'Topnet (internet)'**
  String get billTypeInternet;

  /// No description provided for @packageFallback.
  ///
  /// In en, this message translates to:
  /// **'Package'**
  String get packageFallback;

  /// No description provided for @orderStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get orderStatusPending;

  /// No description provided for @orderStatusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get orderStatusConfirmed;

  /// No description provided for @orderStatusPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get orderStatusPreparing;

  /// No description provided for @orderStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get orderStatusReady;

  /// No description provided for @orderStatusPickedUp.
  ///
  /// In en, this message translates to:
  /// **'Picked up'**
  String get orderStatusPickedUp;

  /// No description provided for @orderStatusOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'On the way'**
  String get orderStatusOnTheWay;

  /// No description provided for @orderStatusDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get orderStatusDelivered;

  /// No description provided for @orderStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get orderStatusCancelled;

  /// No description provided for @timelineOrderConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Order confirmed'**
  String get timelineOrderConfirmed;

  /// No description provided for @timelinePreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get timelinePreparing;

  /// No description provided for @timelineReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get timelineReady;

  /// No description provided for @timelineOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'On the way'**
  String get timelineOnTheWay;

  /// No description provided for @timelineDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get timelineDelivered;

  /// No description provided for @timelineRequestConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Request confirmed'**
  String get timelineRequestConfirmed;

  /// No description provided for @timelinePickedUp.
  ///
  /// In en, this message translates to:
  /// **'Picked up'**
  String get timelinePickedUp;

  /// No description provided for @timelineDriverComing.
  ///
  /// In en, this message translates to:
  /// **'Driver on the way to you'**
  String get timelineDriverComing;

  /// No description provided for @timelineCashCollected.
  ///
  /// In en, this message translates to:
  /// **'Cash collected'**
  String get timelineCashCollected;

  /// No description provided for @timelineBillPaid.
  ///
  /// In en, this message translates to:
  /// **'Bill paid'**
  String get timelineBillPaid;

  /// No description provided for @estimatedDeliveryAt.
  ///
  /// In en, this message translates to:
  /// **'Estimated delivery: {time}'**
  String estimatedDeliveryAt(String time);

  /// No description provided for @orderDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Order details'**
  String get orderDetailsTitle;

  /// No description provided for @billDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Bill details'**
  String get billDetailsTitle;

  /// No description provided for @deliveryLocation.
  ///
  /// In en, this message translates to:
  /// **'Delivery location'**
  String get deliveryLocation;

  /// No description provided for @paymentOffice.
  ///
  /// In en, this message translates to:
  /// **'Payment office'**
  String get paymentOffice;

  /// No description provided for @yourAddress.
  ///
  /// In en, this message translates to:
  /// **'Your address'**
  String get yourAddress;

  /// No description provided for @driverLabel.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get driverLabel;

  /// No description provided for @routeLabel.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get routeLabel;

  /// No description provided for @billTypeField.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get billTypeField;

  /// No description provided for @billReferenceField.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get billReferenceField;

  /// No description provided for @billAmountField.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get billAmountField;

  /// No description provided for @billPhotoLabel.
  ///
  /// In en, this message translates to:
  /// **'Bill photo'**
  String get billPhotoLabel;

  /// No description provided for @paymentReceiptLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment receipt'**
  String get paymentReceiptLabel;

  /// No description provided for @paymentMethodCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get paymentMethodCash;

  /// No description provided for @cancelOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel the order'**
  String get cancelOrderTitle;

  /// No description provided for @cancelDriverAssigned.
  ///
  /// In en, this message translates to:
  /// **'A driver has already been assigned to your order. Cancel anyway?'**
  String get cancelDriverAssigned;

  /// No description provided for @cancelReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason for cancelling:'**
  String get cancelReasonLabel;

  /// No description provided for @cancelReasonWrongOrder.
  ///
  /// In en, this message translates to:
  /// **'Ordering mistake'**
  String get cancelReasonWrongOrder;

  /// No description provided for @cancelReasonTooLong.
  ///
  /// In en, this message translates to:
  /// **'Taking too long'**
  String get cancelReasonTooLong;

  /// No description provided for @cancelReasonChangedMind.
  ///
  /// In en, this message translates to:
  /// **'I changed my mind'**
  String get cancelReasonChangedMind;

  /// No description provided for @cancelReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get cancelReasonOther;

  /// No description provided for @backAction.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get backAction;

  /// No description provided for @confirmAction.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmAction;

  /// No description provided for @orderCancelledOk.
  ///
  /// In en, this message translates to:
  /// **'Order cancelled.'**
  String get orderCancelledOk;

  /// No description provided for @cancelTooLatePreparing.
  ///
  /// In en, this message translates to:
  /// **'Too late to cancel — the order is already being prepared.'**
  String get cancelTooLatePreparing;

  /// No description provided for @cancelTooLateOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'The order is already on its way. Contact support to cancel.'**
  String get cancelTooLateOnTheWay;

  /// No description provided for @placeOrderWithTotal.
  ///
  /// In en, this message translates to:
  /// **'Place order — {total}'**
  String placeOrderWithTotal(String total);

  /// No description provided for @venueClosedNow.
  ///
  /// In en, this message translates to:
  /// **'This shop is currently closed and cannot take orders.'**
  String get venueClosedNow;

  /// No description provided for @paymentFailedOrderCancelled.
  ///
  /// In en, this message translates to:
  /// **'Payment failed. Order cancelled.'**
  String get paymentFailedOrderCancelled;

  /// No description provided for @loyaltyFreeDelivery.
  ///
  /// In en, this message translates to:
  /// **'Loyalty — free delivery'**
  String get loyaltyFreeDelivery;

  /// No description provided for @loyaltyHalfDelivery.
  ///
  /// In en, this message translates to:
  /// **'Loyalty — 50% off delivery'**
  String get loyaltyHalfDelivery;

  /// No description provided for @genericErrorWith.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String genericErrorWith(String message);

  /// No description provided for @promoOnEligible.
  ///
  /// In en, this message translates to:
  /// **'− {discount} on {eligible} eligible'**
  String promoOnEligible(String discount, String eligible);

  /// No description provided for @promoErrorNotFound.
  ///
  /// In en, this message translates to:
  /// **'This promo code does not exist'**
  String get promoErrorNotFound;

  /// No description provided for @promoErrorInactive.
  ///
  /// In en, this message translates to:
  /// **'This promo code is no longer active'**
  String get promoErrorInactive;

  /// No description provided for @promoErrorExpired.
  ///
  /// In en, this message translates to:
  /// **'This code has expired or is not valid yet'**
  String get promoErrorExpired;

  /// No description provided for @promoErrorMaxUses.
  ///
  /// In en, this message translates to:
  /// **'This code is no longer available'**
  String get promoErrorMaxUses;

  /// No description provided for @promoErrorAlreadyUsed.
  ///
  /// In en, this message translates to:
  /// **'You have already used this promo code'**
  String get promoErrorAlreadyUsed;

  /// No description provided for @promoErrorMinOrder.
  ///
  /// In en, this message translates to:
  /// **'Your order is below this code\'s minimum'**
  String get promoErrorMinOrder;

  /// No description provided for @promoErrorMinOrderAmount.
  ///
  /// In en, this message translates to:
  /// **'This code needs a minimum order of {amount}'**
  String promoErrorMinOrderAmount(String amount);

  /// No description provided for @promoErrorAllOnPromo.
  ///
  /// In en, this message translates to:
  /// **'Your items are already discounted, so this code does not apply'**
  String get promoErrorAllOnPromo;

  /// No description provided for @promoErrorNotFirstOrder.
  ///
  /// In en, this message translates to:
  /// **'This code is for your first order only'**
  String get promoErrorNotFirstOrder;

  /// No description provided for @promoErrorEmptyCart.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty'**
  String get promoErrorEmptyCart;

  /// No description provided for @promoErrorNotLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in to use a promo code'**
  String get promoErrorNotLoggedIn;

  /// No description provided for @promoErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please try again.'**
  String get promoErrorNetwork;

  /// No description provided for @promoErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Invalid or expired code'**
  String get promoErrorGeneric;

  /// No description provided for @applyPromoCode.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get applyPromoCode;

  /// No description provided for @removePromoCode.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removePromoCode;

  /// No description provided for @promoApplied.
  ///
  /// In en, this message translates to:
  /// **'Discount applied!'**
  String get promoApplied;

  /// No description provided for @promoDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount ({code})'**
  String promoDiscount(String code);

  /// No description provided for @loyaltyCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Loyalty card'**
  String get loyaltyCardTitle;

  /// No description provided for @loyaltyPendingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stamp pending — confirmed at delivery'**
  String get loyaltyPendingSubtitle;

  /// No description provided for @loyaltyProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'Your progress'**
  String get loyaltyProgressLabel;

  /// No description provided for @loyaltyRemainingHalf.
  ///
  /// In en, this message translates to:
  /// **'{count} more orders for half-price delivery'**
  String loyaltyRemainingHalf(int count);

  /// No description provided for @loyaltyRemainingFree.
  ///
  /// In en, this message translates to:
  /// **'{count} more orders for free delivery'**
  String loyaltyRemainingFree(int count);

  /// No description provided for @loyaltyCelebrationHalf.
  ///
  /// In en, this message translates to:
  /// **'This is your 5th order — your delivery is half price!'**
  String get loyaltyCelebrationHalf;

  /// No description provided for @loyaltyCelebrationFree.
  ///
  /// In en, this message translates to:
  /// **'10th order — your delivery is free!'**
  String get loyaltyCelebrationFree;

  /// No description provided for @loyaltyViewRewards.
  ///
  /// In en, this message translates to:
  /// **'See my rewards'**
  String get loyaltyViewRewards;

  /// No description provided for @loyaltyCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Order cancelled'**
  String get loyaltyCancelTitle;

  /// No description provided for @loyaltyCancelMessage.
  ///
  /// In en, this message translates to:
  /// **'Got it! We hope to see you again soon. Thanks for your trust!'**
  String get loyaltyCancelMessage;

  /// No description provided for @loyaltyCancelNote.
  ///
  /// In en, this message translates to:
  /// **'This order\'s stamp has been removed from your card.'**
  String get loyaltyCancelNote;

  /// No description provided for @loyaltyCancelPrimaryCta.
  ///
  /// In en, this message translates to:
  /// **'Order again'**
  String get loyaltyCancelPrimaryCta;

  /// No description provided for @loyaltyCancelSecondaryCta.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get loyaltyCancelSecondaryCta;

  /// No description provided for @loyaltyRewardsTitle.
  ///
  /// In en, this message translates to:
  /// **'My rewards'**
  String get loyaltyRewardsTitle;

  /// No description provided for @loyaltyMilestoneHalfTitle.
  ///
  /// In en, this message translates to:
  /// **'5th order'**
  String get loyaltyMilestoneHalfTitle;

  /// No description provided for @loyaltyMilestoneHalfSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Half-price delivery'**
  String get loyaltyMilestoneHalfSubtitle;

  /// No description provided for @loyaltyMilestoneFreeTitle.
  ///
  /// In en, this message translates to:
  /// **'10th order'**
  String get loyaltyMilestoneFreeTitle;

  /// No description provided for @loyaltyMilestoneFreeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Free delivery'**
  String get loyaltyMilestoneFreeSubtitle;

  /// No description provided for @loyaltyStateAchieved.
  ///
  /// In en, this message translates to:
  /// **'Achieved'**
  String get loyaltyStateAchieved;

  /// No description provided for @loyaltyStateCurrent.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get loyaltyStateCurrent;

  /// No description provided for @loyaltyStateLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get loyaltyStateLocked;

  /// No description provided for @loyaltyHowItWorksTitle.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get loyaltyHowItWorksTitle;

  /// No description provided for @loyaltyHowItWorks1.
  ///
  /// In en, this message translates to:
  /// **'Each delivered order = 1 stamp'**
  String get loyaltyHowItWorks1;

  /// No description provided for @loyaltyHowItWorks2.
  ///
  /// In en, this message translates to:
  /// **'Discounts apply automatically to the delivery fee of the order that reaches the milestone'**
  String get loyaltyHowItWorks2;

  /// No description provided for @loyaltyHowItWorks3.
  ///
  /// In en, this message translates to:
  /// **'Cancelled orders don\'t count'**
  String get loyaltyHowItWorks3;

  /// No description provided for @loyaltyHowItWorks4.
  ///
  /// In en, this message translates to:
  /// **'After the 10th order, the card resets and a new cycle begins'**
  String get loyaltyHowItWorks4;

  /// No description provided for @optionGroupRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get optionGroupRequired;

  /// No description provided for @optionGroupOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optionGroupOptional;

  /// No description provided for @optionGroupSelectExact.
  ///
  /// In en, this message translates to:
  /// **'Select {count}'**
  String optionGroupSelectExact(int count);

  /// No description provided for @optionGroupSelectUpTo.
  ///
  /// In en, this message translates to:
  /// **'Select up to {max}'**
  String optionGroupSelectUpTo(int max);

  /// No description provided for @optionGroupSelectRange.
  ///
  /// In en, this message translates to:
  /// **'Select {min} to {max}'**
  String optionGroupSelectRange(int min, int max);

  /// No description provided for @addToCartWithTotal.
  ///
  /// In en, this message translates to:
  /// **'Add to Cart · {total}'**
  String addToCartWithTotal(String total);

  /// No description provided for @completeRequiredSelections.
  ///
  /// In en, this message translates to:
  /// **'Please complete the required selections'**
  String get completeRequiredSelections;

  /// No description provided for @variantGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose an option'**
  String get variantGroupTitle;

  /// No description provided for @aiSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Search'**
  String get aiSearchTitle;

  /// No description provided for @aiSearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'N7eb nekel 7aja 7arra… ou décris ce que tu veux'**
  String get aiSearchPlaceholder;

  /// No description provided for @aiSearchCameraTooltip.
  ///
  /// In en, this message translates to:
  /// **'Search by photo'**
  String get aiSearchCameraTooltip;

  /// No description provided for @aiSearchVisualSearchBadge.
  ///
  /// In en, this message translates to:
  /// **'Visual Search'**
  String get aiSearchVisualSearchBadge;

  /// No description provided for @aiSearchResultCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 result found} other{{count} results found}}'**
  String aiSearchResultCount(int count);

  /// No description provided for @aiSearchLoadingPhoto.
  ///
  /// In en, this message translates to:
  /// **'Analyzing your photo…'**
  String get aiSearchLoadingPhoto;

  /// No description provided for @aiSearchLoadingText.
  ///
  /// In en, this message translates to:
  /// **'Understanding your request…'**
  String get aiSearchLoadingText;

  /// No description provided for @aiSearchPoweredBy.
  ///
  /// In en, this message translates to:
  /// **'Powered by AI'**
  String get aiSearchPoweredBy;

  /// No description provided for @aiSearchEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Describe what you want'**
  String get aiSearchEmptyTitle;

  /// No description provided for @aiSearchEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Type in Darija, French or Arabic — or upload a photo of a dish you want to find.'**
  String get aiSearchEmptyDescription;

  /// No description provided for @aiSearchExampleQuery1.
  ///
  /// In en, this message translates to:
  /// **'N7eb chapati w ma tfoutch 10 dinar'**
  String get aiSearchExampleQuery1;

  /// No description provided for @aiSearchExampleQuery2.
  ///
  /// In en, this message translates to:
  /// **'Une pizza pas chère'**
  String get aiSearchExampleQuery2;

  /// No description provided for @aiSearchExampleQuery3.
  ///
  /// In en, this message translates to:
  /// **'A malfouf under 12 dinars'**
  String get aiSearchExampleQuery3;

  /// No description provided for @aiSearchExampleQueryPhoto.
  ///
  /// In en, this message translates to:
  /// **'Upload a food photo'**
  String get aiSearchExampleQueryPhoto;

  /// No description provided for @aiSearchNoResultsPhoto.
  ///
  /// In en, this message translates to:
  /// **'No restaurants found for \"{dishName}\"'**
  String aiSearchNoResultsPhoto(String dishName);

  /// No description provided for @aiSearchNoResultsText.
  ///
  /// In en, this message translates to:
  /// **'No dishes match your request'**
  String get aiSearchNoResultsText;

  /// No description provided for @aiSearchFallbackMessage.
  ///
  /// In en, this message translates to:
  /// **'No exact match — here are some popular dishes'**
  String get aiSearchFallbackMessage;

  /// No description provided for @aiSearchModalTitle.
  ///
  /// In en, this message translates to:
  /// **'Search by Photo'**
  String get aiSearchModalTitle;

  /// No description provided for @aiSearchModalHint.
  ///
  /// In en, this message translates to:
  /// **'Upload a photo of a dish to find it in {city}'**
  String aiSearchModalHint(String city);

  /// No description provided for @aiSearchCameraLabel.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get aiSearchCameraLabel;

  /// No description provided for @aiSearchGalleryLabel.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get aiSearchGalleryLabel;

  /// No description provided for @aiSearchTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get aiSearchTryAgain;

  /// No description provided for @aiSearchErrorCouldNotOpen.
  ///
  /// In en, this message translates to:
  /// **'Could not open image'**
  String get aiSearchErrorCouldNotOpen;

  /// No description provided for @aiSearchIdentified.
  ///
  /// In en, this message translates to:
  /// **'Identified: \"{dishName}\" · {count, plural, =1{1 restaurant} other{{count} restaurants}}'**
  String aiSearchIdentified(String dishName, int count);

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'Kairouan'**
  String get city;

  /// No description provided for @colisHandoverSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'How does the driver hand over your parcel?'**
  String get colisHandoverSectionTitle;

  /// No description provided for @colisModeRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get colisModeRecommended;

  /// No description provided for @colisModeCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'With a code'**
  String get colisModeCodeTitle;

  /// No description provided for @colisModeCodeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The safest option for you. You get a 4-digit code. Send it to the person receiving the parcel. On arrival, they give the code to the driver. Without the right code, the driver cannot complete the delivery. So you know your parcel reaches the right person.'**
  String get colisModeCodeSubtitle;

  /// No description provided for @colisModeNoCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Hand over without a code'**
  String get colisModeNoCodeTitle;

  /// No description provided for @colisModeNoCodeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'For when the person has no phone (a child at school, a caretaker…). The driver takes a photo at the moment of handover, with their location. It is less safe than with a code.'**
  String get colisModeNoCodeSubtitle;

  /// No description provided for @colisCodeHeadline.
  ///
  /// In en, this message translates to:
  /// **'Your delivery code: {code}'**
  String colisCodeHeadline(String code);

  /// No description provided for @colisCodeExplain.
  ///
  /// In en, this message translates to:
  /// **'Send this code to the recipient. They will give it to the driver when they receive the parcel.'**
  String get colisCodeExplain;

  /// No description provided for @colisShareMessage.
  ///
  /// In en, this message translates to:
  /// **'Hello, an Amana parcel is on its way to you. Give this code to the driver on arrival: {code}'**
  String colisShareMessage(String code);

  /// No description provided for @colisShareSubject.
  ///
  /// In en, this message translates to:
  /// **'Amana delivery code'**
  String get colisShareSubject;

  /// No description provided for @mapGpsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get your GPS position'**
  String get mapGpsUnavailable;

  /// No description provided for @mapUseCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use my current location'**
  String get mapUseCurrentLocation;

  /// No description provided for @mapOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get mapOr;

  /// No description provided for @mapSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search for an address or place…'**
  String get mapSearchHint;

  /// No description provided for @mapTypeStreetHint.
  ///
  /// In en, this message translates to:
  /// **'Type a street, neighbourhood or place…'**
  String get mapTypeStreetHint;

  /// No description provided for @mapNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get mapNoResults;

  /// No description provided for @mapLocating.
  ///
  /// In en, this message translates to:
  /// **'Locating…'**
  String get mapLocating;

  /// No description provided for @mapLocatingInProgress.
  ///
  /// In en, this message translates to:
  /// **'Finding your location…'**
  String get mapLocatingInProgress;

  /// No description provided for @mapDragToAdjust.
  ///
  /// In en, this message translates to:
  /// **'Drag to adjust the position'**
  String get mapDragToAdjust;

  /// No description provided for @mapDragToPlace.
  ///
  /// In en, this message translates to:
  /// **'Drag the map to the spot you want'**
  String get mapDragToPlace;

  /// No description provided for @mapConfirmLocation.
  ///
  /// In en, this message translates to:
  /// **'Confirm this location'**
  String get mapConfirmLocation;

  /// No description provided for @authErrorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password'**
  String get authErrorInvalidCredentials;

  /// No description provided for @authErrorAccountExists.
  ///
  /// In en, this message translates to:
  /// **'An account already exists with this email'**
  String get authErrorAccountExists;

  /// No description provided for @authErrorEmailNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your email before signing in'**
  String get authErrorEmailNotConfirmed;

  /// No description provided for @authErrorNoInternet.
  ///
  /// In en, this message translates to:
  /// **'Internet connection problem'**
  String get authErrorNoInternet;

  /// No description provided for @authErrorTimeout.
  ///
  /// In en, this message translates to:
  /// **'The server is taking too long to respond. Try again.'**
  String get authErrorTimeout;

  /// No description provided for @authErrorServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The service is temporarily unavailable. Try again in a moment.'**
  String get authErrorServiceUnavailable;

  /// No description provided for @authErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong, please try again'**
  String get authErrorGeneric;

  /// No description provided for @authCheckFormFields.
  ///
  /// In en, this message translates to:
  /// **'Check the form fields'**
  String get authCheckFormFields;

  /// No description provided for @authAccountCreatedConfirmEmail.
  ///
  /// In en, this message translates to:
  /// **'Account created! Open the confirmation email we just sent, then sign in.'**
  String get authAccountCreatedConfirmEmail;

  /// No description provided for @billsTitle.
  ///
  /// In en, this message translates to:
  /// **'My bills'**
  String get billsTitle;

  /// No description provided for @billsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your bills'**
  String get billsLoadError;

  /// No description provided for @billsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No bills paid yet'**
  String get billsEmptyTitle;

  /// No description provided for @billsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your bill payments will appear here'**
  String get billsEmptySubtitle;

  /// No description provided for @billsReference.
  ///
  /// In en, this message translates to:
  /// **'Ref: {reference}'**
  String billsReference(String reference);

  /// No description provided for @billsReceiptAvailable.
  ///
  /// In en, this message translates to:
  /// **'Receipt available'**
  String get billsReceiptAvailable;

  /// No description provided for @billsLabelSteg.
  ///
  /// In en, this message translates to:
  /// **'STEG — Electricity'**
  String get billsLabelSteg;

  /// No description provided for @billsLabelSonede.
  ///
  /// In en, this message translates to:
  /// **'SONEDE — Water'**
  String get billsLabelSonede;

  /// No description provided for @billsLabelTopnet.
  ///
  /// In en, this message translates to:
  /// **'Topnet — Internet'**
  String get billsLabelTopnet;

  /// No description provided for @billsLabelOther.
  ///
  /// In en, this message translates to:
  /// **'Other bill'**
  String get billsLabelOther;

  /// No description provided for @billStatusPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get billStatusPaid;

  /// No description provided for @billStatusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get billStatusInProgress;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonInvalidAmount.
  ///
  /// In en, this message translates to:
  /// **'Invalid amount'**
  String get commonInvalidAmount;

  /// No description provided for @commonInvalidPhone8.
  ///
  /// In en, this message translates to:
  /// **'Invalid number — exactly 8 digits required'**
  String get commonInvalidPhone8;

  /// No description provided for @photoTakePicture.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get photoTakePicture;

  /// No description provided for @photoChooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get photoChooseFromGallery;

  /// No description provided for @courierDeleteRecipientTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this recipient?'**
  String get courierDeleteRecipientTitle;

  /// No description provided for @courierDeleteRecipientBody.
  ///
  /// In en, this message translates to:
  /// **'{name} will be removed from your saved contacts.'**
  String courierDeleteRecipientBody(String name);

  /// No description provided for @courierPickupAddress.
  ///
  /// In en, this message translates to:
  /// **'Pickup address'**
  String get courierPickupAddress;

  /// No description provided for @courierConfirmNoForbidden.
  ///
  /// In en, this message translates to:
  /// **'Confirm that your parcel contains no forbidden items.'**
  String get courierConfirmNoForbidden;

  /// No description provided for @courierAcceptPhotoProof.
  ///
  /// In en, this message translates to:
  /// **'Accept that the photo and location will serve as proof.'**
  String get courierAcceptPhotoProof;

  /// No description provided for @courierDeclaredValueRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the value of your parcel'**
  String get courierDeclaredValueRequired;

  /// No description provided for @courierDeclaredValuePositive.
  ///
  /// In en, this message translates to:
  /// **'The value must be greater than 0'**
  String get courierDeclaredValuePositive;

  /// No description provided for @courierDeclaredValueMax.
  ///
  /// In en, this message translates to:
  /// **'Maximum {max} TND — split your shipment'**
  String courierDeclaredValueMax(String max);

  /// No description provided for @courierDescriptionRequired.
  ///
  /// In en, this message translates to:
  /// **'Describe what is in your parcel'**
  String get courierDescriptionRequired;

  /// No description provided for @courierReceiverLabelRequired.
  ///
  /// In en, this message translates to:
  /// **'Say who the parcel will be handed to'**
  String get courierReceiverLabelRequired;

  /// No description provided for @courierSenderPhone.
  ///
  /// In en, this message translates to:
  /// **'Sender\'s phone'**
  String get courierSenderPhone;

  /// No description provided for @courierSenderPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'The person handing over the parcel'**
  String get courierSenderPhoneHint;

  /// No description provided for @courierSenderPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Required — sender\'s number'**
  String get courierSenderPhoneRequired;

  /// No description provided for @courierRecipientName.
  ///
  /// In en, this message translates to:
  /// **'Recipient\'s name'**
  String get courierRecipientName;

  /// No description provided for @courierRecipientNameHint.
  ///
  /// In en, this message translates to:
  /// **'Optional — helps the driver identify the recipient'**
  String get courierRecipientNameHint;

  /// No description provided for @courierRecipientNameExample.
  ///
  /// In en, this message translates to:
  /// **'E.g. Mohamed Ben Ali'**
  String get courierRecipientNameExample;

  /// No description provided for @courierRecipientPhone.
  ///
  /// In en, this message translates to:
  /// **'Recipient\'s phone'**
  String get courierRecipientPhone;

  /// No description provided for @courierRecipientPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'The person receiving the parcel'**
  String get courierRecipientPhoneHint;

  /// No description provided for @courierRecipientPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Required — recipient\'s number'**
  String get courierRecipientPhoneRequired;

  /// No description provided for @courierContentsTitle.
  ///
  /// In en, this message translates to:
  /// **'What is in your parcel?'**
  String get courierContentsTitle;

  /// No description provided for @courierContentsExample.
  ///
  /// In en, this message translates to:
  /// **'E.g. Samsung A15 phone, documents, clothes…'**
  String get courierContentsExample;

  /// No description provided for @courierDeclaredValue.
  ///
  /// In en, this message translates to:
  /// **'Declared value'**
  String get courierDeclaredValue;

  /// No description provided for @courierDeclaredValueCap.
  ///
  /// In en, this message translates to:
  /// **'Limit: {max} TND. Above that, split your shipment into several parcels.'**
  String courierDeclaredValueCap(String max);

  /// No description provided for @courierDeclaredValueHint.
  ///
  /// In en, this message translates to:
  /// **'Value in TND'**
  String get courierDeclaredValueHint;

  /// No description provided for @courierPhotoTitle.
  ///
  /// In en, this message translates to:
  /// **'Parcel photo'**
  String get courierPhotoTitle;

  /// No description provided for @courierPhotoHint.
  ///
  /// In en, this message translates to:
  /// **'Optional — helps the driver identify your parcel'**
  String get courierPhotoHint;

  /// No description provided for @courierSizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Parcel size'**
  String get courierSizeTitle;

  /// No description provided for @courierConfirmSend.
  ///
  /// In en, this message translates to:
  /// **'Confirm sending'**
  String get courierConfirmSend;

  /// No description provided for @courierTapToSelect.
  ///
  /// In en, this message translates to:
  /// **'Tap to select'**
  String get courierTapToSelect;

  /// No description provided for @courierPhoneExample.
  ///
  /// In en, this message translates to:
  /// **'E.g. 20123456'**
  String get courierPhoneExample;

  /// No description provided for @courierEstimatedPrice.
  ///
  /// In en, this message translates to:
  /// **'Estimated price'**
  String get courierEstimatedPrice;

  /// No description provided for @courierEstimatedPriceLoyaltyFree.
  ///
  /// In en, this message translates to:
  /// **'Estimated price — loyalty: free delivery'**
  String get courierEstimatedPriceLoyaltyFree;

  /// No description provided for @courierEstimatedPriceLoyaltyHalf.
  ///
  /// In en, this message translates to:
  /// **'Estimated price — loyalty: -50%'**
  String get courierEstimatedPriceLoyaltyHalf;

  /// No description provided for @courierPriceBase.
  ///
  /// In en, this message translates to:
  /// **'3.500 TND base'**
  String get courierPriceBase;

  /// No description provided for @courierReceiverLabelExample.
  ///
  /// In en, this message translates to:
  /// **'E.g. school caretaker, neighbour on the 3rd floor…'**
  String get courierReceiverLabelExample;

  /// No description provided for @courierAcceptPhotoProofCheckbox.
  ///
  /// In en, this message translates to:
  /// **'I accept that the proof of delivery is the driver\'s photo and location.'**
  String get courierAcceptPhotoProofCheckbox;

  /// No description provided for @courierForbiddenTitle.
  ///
  /// In en, this message translates to:
  /// **'Not allowed in a parcel'**
  String get courierForbiddenTitle;

  /// No description provided for @courierForbiddenConfirm.
  ///
  /// In en, this message translates to:
  /// **'I confirm that my parcel contains none of these items'**
  String get courierForbiddenConfirm;

  /// No description provided for @courierPhotoChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get courierPhotoChange;

  /// No description provided for @courierPhotoAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a photo of the parcel'**
  String get courierPhotoAdd;

  /// No description provided for @courierPhotoTapHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to take/choose a photo'**
  String get courierPhotoTapHint;

  /// No description provided for @courierSizeSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get courierSizeSmall;

  /// No description provided for @courierSizeMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get courierSizeMedium;

  /// No description provided for @courierSizeLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get courierSizeLarge;

  /// No description provided for @courierSizeSmallDesc.
  ///
  /// In en, this message translates to:
  /// **'Documents, small items'**
  String get courierSizeSmallDesc;

  /// No description provided for @courierSizeMediumDesc.
  ///
  /// In en, this message translates to:
  /// **'Clothes, accessories'**
  String get courierSizeMediumDesc;

  /// No description provided for @courierSizeLargeDesc.
  ///
  /// In en, this message translates to:
  /// **'Luggage, large parcels'**
  String get courierSizeLargeDesc;

  /// No description provided for @courierSaveRecipient.
  ///
  /// In en, this message translates to:
  /// **'Save this recipient for next time'**
  String get courierSaveRecipient;

  /// No description provided for @courierSavedRecipients.
  ///
  /// In en, this message translates to:
  /// **'Saved recipients'**
  String get courierSavedRecipients;

  /// No description provided for @factureSelectBillType.
  ///
  /// In en, this message translates to:
  /// **'Please select the bill type'**
  String get factureSelectBillType;

  /// No description provided for @factureEnterPickupAddress.
  ///
  /// In en, this message translates to:
  /// **'Please enter your pickup address'**
  String get factureEnterPickupAddress;

  /// No description provided for @factureEnterOfficeAddress.
  ///
  /// In en, this message translates to:
  /// **'Please enter the office address'**
  String get factureEnterOfficeAddress;

  /// No description provided for @factureNotSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get factureNotSignedIn;

  /// No description provided for @factureReferenceRequired.
  ///
  /// In en, this message translates to:
  /// **'Required — reference number'**
  String get factureReferenceRequired;

  /// No description provided for @factureAmountRequired.
  ///
  /// In en, this message translates to:
  /// **'Required — bill amount'**
  String get factureAmountRequired;

  /// No description provided for @facturePhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Required — phone number'**
  String get facturePhoneRequired;

  /// No description provided for @factureBillTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'Bill type'**
  String get factureBillTypeTitle;

  /// No description provided for @factureReferenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Reference / contract number'**
  String get factureReferenceLabel;

  /// No description provided for @factureAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount to pay (TND)'**
  String get factureAmountLabel;

  /// No description provided for @factureCustomerAddressTitle.
  ///
  /// In en, this message translates to:
  /// **'Your address (cash pickup)'**
  String get factureCustomerAddressTitle;

  /// No description provided for @factureChooseYourAddress.
  ///
  /// In en, this message translates to:
  /// **'Choose your address'**
  String get factureChooseYourAddress;

  /// No description provided for @factureOfficeAddressTitle.
  ///
  /// In en, this message translates to:
  /// **'Office address {billType}'**
  String factureOfficeAddressTitle(String billType);

  /// No description provided for @factureChooseOfficeAddress.
  ///
  /// In en, this message translates to:
  /// **'Choose the office address'**
  String get factureChooseOfficeAddress;

  /// No description provided for @facturePhoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Your phone number'**
  String get facturePhoneTitle;

  /// No description provided for @facturePhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone (8 digits)'**
  String get facturePhoneLabel;

  /// No description provided for @factureAddBillPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add a photo of the bill (optional)'**
  String get factureAddBillPhoto;

  /// No description provided for @factureRemovePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove the photo'**
  String get factureRemovePhoto;

  /// No description provided for @factureBillAmount.
  ///
  /// In en, this message translates to:
  /// **'Bill amount'**
  String get factureBillAmount;

  /// No description provided for @factureCollectedInCash.
  ///
  /// In en, this message translates to:
  /// **'(collected in cash)'**
  String get factureCollectedInCash;

  /// No description provided for @factureServiceFee.
  ///
  /// In en, this message translates to:
  /// **'Service fee'**
  String get factureServiceFee;

  /// No description provided for @factureLoyaltyHalf.
  ///
  /// In en, this message translates to:
  /// **'Loyalty — -50%'**
  String get factureLoyaltyHalf;

  /// No description provided for @factureSendRequest.
  ///
  /// In en, this message translates to:
  /// **'Send the request'**
  String get factureSendRequest;

  /// No description provided for @colisDisputeExplain.
  ///
  /// In en, this message translates to:
  /// **'Describe what happened. An administrator will review the evidence (photos, time, location) before deciding.'**
  String get colisDisputeExplain;

  /// No description provided for @colisDisputeMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Your message (optional)'**
  String get colisDisputeMessageHint;

  /// No description provided for @colisDisputeSendFailed.
  ///
  /// In en, this message translates to:
  /// **'The report could not be sent.'**
  String get colisDisputeSendFailed;

  /// No description provided for @colisReceiptTitle.
  ///
  /// In en, this message translates to:
  /// **'Pickup receipt'**
  String get colisReceiptTitle;

  /// No description provided for @colisReceiptDeclaredContents.
  ///
  /// In en, this message translates to:
  /// **'Declared contents'**
  String get colisReceiptDeclaredContents;

  /// No description provided for @colisReceiptHandedTo.
  ///
  /// In en, this message translates to:
  /// **'Handed to'**
  String get colisReceiptHandedTo;

  /// No description provided for @colisReceiptPlate.
  ///
  /// In en, this message translates to:
  /// **'Plate'**
  String get colisReceiptPlate;

  /// No description provided for @colisReceiptDistanceToAddress.
  ///
  /// In en, this message translates to:
  /// **'Distance to the address'**
  String get colisReceiptDistanceToAddress;

  /// No description provided for @colisProofPickup.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get colisProofPickup;

  /// No description provided for @colisProofDelivery.
  ///
  /// In en, this message translates to:
  /// **'Handover'**
  String get colisProofDelivery;

  /// No description provided for @colisDisputeSent.
  ///
  /// In en, this message translates to:
  /// **'Report sent. An administrator will review it.'**
  String get colisDisputeSent;

  /// No description provided for @colisDisputeWindow.
  ///
  /// In en, this message translates to:
  /// **'A problem? You have 24 h after delivery to report it.'**
  String get colisDisputeWindow;

  /// No description provided for @colisDisputeNotReceivedTitle.
  ///
  /// In en, this message translates to:
  /// **'Parcel not received'**
  String get colisDisputeNotReceivedTitle;

  /// No description provided for @colisDisputeNotReceived.
  ///
  /// In en, this message translates to:
  /// **'Not received'**
  String get colisDisputeNotReceived;

  /// No description provided for @colisDisputeProblem.
  ///
  /// In en, this message translates to:
  /// **'Problem with the parcel'**
  String get colisDisputeProblem;

  /// No description provided for @colisCodeCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get colisCodeCopy;

  /// No description provided for @colisCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get colisCodeCopied;

  /// No description provided for @colisCodeShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get colisCodeShare;

  /// No description provided for @loyaltyAppliedFree.
  ///
  /// In en, this message translates to:
  /// **'🎉 Free delivery applied — thank you for your loyalty!'**
  String get loyaltyAppliedFree;

  /// No description provided for @loyaltyAppliedHalf.
  ///
  /// In en, this message translates to:
  /// **'🎉 -50% on delivery applied — thank you for your loyalty!'**
  String get loyaltyAppliedHalf;

  /// No description provided for @loyaltyProgressOrders.
  ///
  /// In en, this message translates to:
  /// **'{progress}/5 orders until your next discount'**
  String loyaltyProgressOrders(String progress);

  /// No description provided for @loyaltyBadgeFree.
  ///
  /// In en, this message translates to:
  /// **'🎉 Free delivery'**
  String get loyaltyBadgeFree;

  /// No description provided for @loyaltyBadgeHalf.
  ///
  /// In en, this message translates to:
  /// **'🎉 -50% on delivery'**
  String get loyaltyBadgeHalf;

  /// No description provided for @reorderButton.
  ///
  /// In en, this message translates to:
  /// **'Order again'**
  String get reorderButton;

  /// No description provided for @reorderReplaceCartTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace the cart?'**
  String get reorderReplaceCartTitle;

  /// No description provided for @reorderReplaceCartBody.
  ///
  /// In en, this message translates to:
  /// **'Your cart already has items. Replace them with the ones from this order?'**
  String get reorderReplaceCartBody;

  /// No description provided for @reorderReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get reorderReplace;

  /// No description provided for @reorderNothingAvailable.
  ///
  /// In en, this message translates to:
  /// **'None of the items from this order are available right now.'**
  String get reorderNothingAvailable;

  /// No description provided for @reorderSkipped.
  ///
  /// In en, this message translates to:
  /// **'{count} unavailable item(s) were skipped.'**
  String reorderSkipped(String count);

  /// No description provided for @reorderFailed.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong while reordering. Try again.'**
  String get reorderFailed;

  /// No description provided for @orderTypeFacture.
  ///
  /// In en, this message translates to:
  /// **'Bill payment'**
  String get orderTypeFacture;

  /// No description provided for @orderShopSupermarket.
  ///
  /// In en, this message translates to:
  /// **'Supermarket'**
  String get orderShopSupermarket;

  /// No description provided for @orderShopBakery.
  ///
  /// In en, this message translates to:
  /// **'Bakery'**
  String get orderShopBakery;

  /// No description provided for @orderShopFlowers.
  ///
  /// In en, this message translates to:
  /// **'Flowers'**
  String get orderShopFlowers;

  /// No description provided for @orderShopPets.
  ///
  /// In en, this message translates to:
  /// **'Pet shop'**
  String get orderShopPets;

  /// No description provided for @orderShopGifts.
  ///
  /// In en, this message translates to:
  /// **'Gifts'**
  String get orderShopGifts;

  /// No description provided for @orderShopElectronics.
  ///
  /// In en, this message translates to:
  /// **'Electronics'**
  String get orderShopElectronics;

  /// No description provided for @orderShopRestaurant.
  ///
  /// In en, this message translates to:
  /// **'Restaurant'**
  String get orderShopRestaurant;

  /// No description provided for @homeEmptyBakery.
  ///
  /// In en, this message translates to:
  /// **'No bakery available near you.'**
  String get homeEmptyBakery;

  /// No description provided for @homeEmptyFlowers.
  ///
  /// In en, this message translates to:
  /// **'No florist available near you.'**
  String get homeEmptyFlowers;

  /// No description provided for @homeEmptyPets.
  ///
  /// In en, this message translates to:
  /// **'No pet shop available near you.'**
  String get homeEmptyPets;

  /// No description provided for @homeEmptyGifts.
  ///
  /// In en, this message translates to:
  /// **'No gift shop near you.'**
  String get homeEmptyGifts;

  /// No description provided for @homeEmptyElectronics.
  ///
  /// In en, this message translates to:
  /// **'No electronics shop near you.'**
  String get homeEmptyElectronics;

  /// No description provided for @homeEmptyShops.
  ///
  /// In en, this message translates to:
  /// **'No shop available near you.'**
  String get homeEmptyShops;

  /// No description provided for @profileUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed. Please try again.'**
  String get profileUploadFailed;

  /// No description provided for @profileBillReminders.
  ///
  /// In en, this message translates to:
  /// **'Bill reminders'**
  String get profileBillReminders;

  /// No description provided for @ratingOrderQuestion.
  ///
  /// In en, this message translates to:
  /// **'How was your order?'**
  String get ratingOrderQuestion;

  /// No description provided for @vendorCatalogueLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the catalogue'**
  String get vendorCatalogueLoadError;

  /// No description provided for @vendorNoItemsYet.
  ///
  /// In en, this message translates to:
  /// **'No items yet.'**
  String get vendorNoItemsYet;

  /// No description provided for @vendorDefaultSection.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get vendorDefaultSection;

  /// No description provided for @vendorClosedNotice.
  ///
  /// In en, this message translates to:
  /// **'This shop is currently closed.'**
  String get vendorClosedNotice;

  /// No description provided for @forgotPasswordIntro.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and we\'ll send\nyou a 6-digit reset code.'**
  String get forgotPasswordIntro;

  /// No description provided for @voiceRecordStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to start recording: {error}'**
  String voiceRecordStartFailed(String error);

  /// No description provided for @voiceRecordStopFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to stop recording: {error}'**
  String voiceRecordStopFailed(String error);

  /// No description provided for @voicePlayFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to play audio: {error}'**
  String voicePlayFailed(String error);

  /// No description provided for @addressLabelRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a label'**
  String get addressLabelRequired;

  /// No description provided for @addressRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter an address'**
  String get addressRequired;

  /// No description provided for @addressAptFloor.
  ///
  /// In en, this message translates to:
  /// **'Apt: {apartment}, Floor: {floor}'**
  String addressAptFloor(String apartment, String floor);

  /// No description provided for @aiChatTooltip.
  ///
  /// In en, this message translates to:
  /// **'AI Chat'**
  String get aiChatTooltip;

  /// No description provided for @ordersLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load orders'**
  String get ordersLoadError;

  /// No description provided for @orderTypeCourier.
  ///
  /// In en, this message translates to:
  /// **'Parcel delivery'**
  String get orderTypeCourier;

  /// No description provided for @etaMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes'**
  String etaMinutes(String minutes);

  /// No description provided for @helpEmailUs.
  ///
  /// In en, this message translates to:
  /// **'Email us'**
  String get helpEmailUs;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @restaurantShareText.
  ///
  /// In en, this message translates to:
  /// **'Check out {name}!\n{description}\nRating: {rating} ⭐\nDelivery: {minutes} min'**
  String restaurantShareText(
      String name, String description, String rating, String minutes);

  /// No description provided for @aiChipSpicy.
  ///
  /// In en, this message translates to:
  /// **'🌶 Spicy'**
  String get aiChipSpicy;

  /// No description provided for @aiChipVegetarian.
  ///
  /// In en, this message translates to:
  /// **'🥦 Vegetarian'**
  String get aiChipVegetarian;

  /// No description provided for @aiChipFast.
  ///
  /// In en, this message translates to:
  /// **'⚡ Fast'**
  String get aiChipFast;

  /// No description provided for @aiBadgeVeg.
  ///
  /// In en, this message translates to:
  /// **'🥦 Veg'**
  String get aiBadgeVeg;

  /// No description provided for @aiThisDish.
  ///
  /// In en, this message translates to:
  /// **'this dish'**
  String get aiThisDish;

  /// No description provided for @aiSearchErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection.'**
  String get aiSearchErrorNetwork;

  /// No description provided for @aiSearchErrorUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Service temporarily unavailable. Try again later.'**
  String get aiSearchErrorUnavailable;

  /// No description provided for @aiSearchErrorNoDish.
  ///
  /// In en, this message translates to:
  /// **'Could not identify a dish in this photo. Try a clearer image.'**
  String get aiSearchErrorNoDish;

  /// No description provided for @aiSearchErrorImageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Image is too large ({size} MB). Please use an image smaller than 10 MB.'**
  String aiSearchErrorImageTooLarge(String size);

  /// No description provided for @aiSearchErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get aiSearchErrorUnknown;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountIntro.
  ///
  /// In en, this message translates to:
  /// **'Deletion is permanent. You will no longer be able to sign in with this account.'**
  String get deleteAccountIntro;

  /// No description provided for @deleteAccountDeletedTitle.
  ///
  /// In en, this message translates to:
  /// **'What will be deleted'**
  String get deleteAccountDeletedTitle;

  /// No description provided for @deleteAccountDeletedDevices.
  ///
  /// In en, this message translates to:
  /// **'Your notifications and signed-in devices'**
  String get deleteAccountDeletedDevices;

  /// No description provided for @deleteAccountKeptTitle.
  ///
  /// In en, this message translates to:
  /// **'What will be kept'**
  String get deleteAccountKeptTitle;

  /// No description provided for @deleteAccountKeptWhy.
  ///
  /// In en, this message translates to:
  /// **'This information is kept for accounting and in case of a dispute.'**
  String get deleteAccountKeptWhy;

  /// No description provided for @deleteAccountBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Your account cannot be deleted yet'**
  String get deleteAccountBlockedTitle;

  /// No description provided for @deleteAccountContactTeam.
  ///
  /// In en, this message translates to:
  /// **'Contact the Amana team'**
  String get deleteAccountContactTeam;

  /// No description provided for @deleteAccountBlockerAdmin.
  ///
  /// In en, this message translates to:
  /// **'This is an administrator account: it cannot be deleted from the app.'**
  String get deleteAccountBlockerAdmin;

  /// No description provided for @deleteAccountBlockerActiveOrders.
  ///
  /// In en, this message translates to:
  /// **'You have {count} order(s) in progress. Wait until they are delivered or cancelled.'**
  String deleteAccountBlockerActiveOrders(int count);

  /// No description provided for @deleteAccountBlockerOpenDisputes.
  ///
  /// In en, this message translates to:
  /// **'A parcel dispute is still open. Wait for the Amana team to close it.'**
  String get deleteAccountBlockerOpenDisputes;

  /// No description provided for @deleteAccountBlockerDriverOrders.
  ///
  /// In en, this message translates to:
  /// **'You have {count} delivery(ies) in progress. Finish them first.'**
  String deleteAccountBlockerDriverOrders(int count);

  /// No description provided for @deleteAccountBlockerDriverDisputes.
  ///
  /// In en, this message translates to:
  /// **'A parcel dispute involving you is still open. Wait for the Amana team to close it.'**
  String get deleteAccountBlockerDriverDisputes;

  /// No description provided for @deleteAccountBlockerDriverPayouts.
  ///
  /// In en, this message translates to:
  /// **'Amana still owes you bonuses. Contact the Amana team to settle your account.'**
  String get deleteAccountBlockerDriverPayouts;

  /// No description provided for @deleteAccountBlockerShopOrders.
  ///
  /// In en, this message translates to:
  /// **'Your shop has {count} order(s) in progress. Complete or cancel them first.'**
  String deleteAccountBlockerShopOrders(int count);

  /// No description provided for @deleteAccountBlockerWallet.
  ///
  /// In en, this message translates to:
  /// **'{amount} TND remain on your balance. Contact the Amana team to settle your account.'**
  String deleteAccountBlockerWallet(String amount);

  /// No description provided for @deleteAccountBlockerSettlements.
  ///
  /// In en, this message translates to:
  /// **'A settlement is pending. Contact the Amana team to settle your account.'**
  String get deleteAccountBlockerSettlements;

  /// No description provided for @deleteAccountBlockerUnknown.
  ///
  /// In en, this message translates to:
  /// **'Your account cannot be deleted right now. Contact the Amana team.'**
  String get deleteAccountBlockerUnknown;

  /// No description provided for @deleteAccountConfirmWord.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get deleteAccountConfirmWord;

  /// No description provided for @deleteAccountTypeWord.
  ///
  /// In en, this message translates to:
  /// **'To confirm, type {word}'**
  String deleteAccountTypeWord(String word);

  /// No description provided for @deleteAccountWordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Type exactly {word}'**
  String deleteAccountWordMismatch(String word);

  /// No description provided for @deleteAccountPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'For your security, enter your password'**
  String get deleteAccountPasswordHint;

  /// No description provided for @deleteAccountPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get deleteAccountPasswordLabel;

  /// No description provided for @deleteAccountGoogleHint.
  ///
  /// In en, this message translates to:
  /// **'For your security, you will sign in again with this account\'s Google account.'**
  String get deleteAccountGoogleHint;

  /// No description provided for @deleteAccountSubmit.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete my account'**
  String get deleteAccountSubmit;

  /// No description provided for @deleteAccountErrorWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password.'**
  String get deleteAccountErrorWrongPassword;

  /// No description provided for @deleteAccountErrorOtherGoogle.
  ///
  /// In en, this message translates to:
  /// **'This Google account is not the one linked to this Amana account.'**
  String get deleteAccountErrorOtherGoogle;

  /// No description provided for @deleteAccountErrorReauth.
  ///
  /// In en, this message translates to:
  /// **'Your confirmation has expired. Please try again.'**
  String get deleteAccountErrorReauth;

  /// No description provided for @deleteAccountErrorNoMethod.
  ///
  /// In en, this message translates to:
  /// **'This account cannot be confirmed in the app. Contact the Amana team.'**
  String get deleteAccountErrorNoMethod;

  /// No description provided for @deleteAccountErrorFailed.
  ///
  /// In en, this message translates to:
  /// **'Deletion failed. Try again or contact the Amana team.'**
  String get deleteAccountErrorFailed;

  /// No description provided for @deleteAccountLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not check your account. Check your connection.'**
  String get deleteAccountLoadError;

  /// No description provided for @deleteAccountRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get deleteAccountRetry;

  /// No description provided for @deleteAccountDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Account deleted'**
  String get deleteAccountDoneTitle;

  /// No description provided for @deleteAccountDoneOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get deleteAccountDoneOk;

  /// No description provided for @deleteAccountDeletedContact.
  ///
  /// In en, this message translates to:
  /// **'Your contact details: name, phone, email and photo'**
  String get deleteAccountDeletedContact;

  /// No description provided for @deleteAccountDeletedAddresses.
  ///
  /// In en, this message translates to:
  /// **'Your saved addresses and recipients'**
  String get deleteAccountDeletedAddresses;

  /// No description provided for @deleteAccountDeletedPayment.
  ///
  /// In en, this message translates to:
  /// **'Your saved payment cards'**
  String get deleteAccountDeletedPayment;

  /// No description provided for @deleteAccountDeletedChat.
  ///
  /// In en, this message translates to:
  /// **'Your history with the Amana assistant'**
  String get deleteAccountDeletedChat;

  /// No description provided for @deleteAccountKeptOrders.
  ///
  /// In en, this message translates to:
  /// **'Your orders, for accounting: dates, status, items, amounts, fees and payments, with nothing that identifies you'**
  String get deleteAccountKeptOrders;

  /// No description provided for @deleteAccountKeptColis.
  ///
  /// In en, this message translates to:
  /// **'The handover proof of your parcels (photos, GPS, driver\'s plate and ID), for 30 days after your last order, then it is erased'**
  String get deleteAccountKeptColis;

  /// No description provided for @deleteAccountAppleHint.
  ///
  /// In en, this message translates to:
  /// **'For your security, you will sign in again with Apple.'**
  String get deleteAccountAppleHint;

  /// No description provided for @deleteAccountDoneBody.
  ///
  /// In en, this message translates to:
  /// **'Your account has been deleted. Thank you for using Amana.'**
  String get deleteAccountDoneBody;

  /// No description provided for @deleteAccountDeletedOrderDetails.
  ///
  /// In en, this message translates to:
  /// **'In your past orders: addresses, GPS positions, phone numbers, names, notes, voice messages and bill photos, including the name and phone of your parcel recipients'**
  String get deleteAccountDeletedOrderDetails;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
