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
  /// **'Pickup Location'**
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
  /// **'Please enter a valid phone number'**
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
