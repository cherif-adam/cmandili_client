// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Cmandili';

  @override
  String get signIn => 'Sign In';

  @override
  String get signUp => 'Sign Up';

  @override
  String get createAccount => 'Create Account';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get fullName => 'Full Name';

  @override
  String get or => 'OR';

  @override
  String pleaseEnter(Object field) {
    return 'Please enter your $field';
  }

  @override
  String get validEmail => 'Please enter a valid email';

  @override
  String get passwordLength => 'Password must be at least 6 characters';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get lightMode => 'Light Mode';

  @override
  String get profile => 'Profile';

  @override
  String get logout => 'Logout';

  @override
  String get home => 'Home';

  @override
  String get favorites => 'Favorites';

  @override
  String get cart => 'Cart';

  @override
  String get welcome => 'Welcome';

  @override
  String get search => 'Search for food...';

  @override
  String get popular => 'Popular';

  @override
  String get seeAll => 'See All';

  @override
  String get deliverTo => 'Deliver to';

  @override
  String get currentLocation => 'Current Location';

  @override
  String get searchRestaurants => 'Search for restaurants...';

  @override
  String get popularRestaurants => 'Popular Restaurants';

  @override
  String get noFavoritesYet => 'No favorites yet';

  @override
  String get myCart => 'My Cart';

  @override
  String get clear => 'Clear';

  @override
  String get subtotal => 'Subtotal';

  @override
  String get deliveryFee => 'Delivery Fee';

  @override
  String get total => 'Total';

  @override
  String get proceedToCheckout => 'Proceed to Checkout';

  @override
  String get clearCart => 'Clear Cart';

  @override
  String get clearCartConfirmation =>
      'Are you sure you want to remove all items from your cart?';

  @override
  String get cancel => 'Cancel';

  @override
  String get cartEmpty => 'Your cart is empty';

  @override
  String get addItemsToGetStarted => 'Add items to get started';

  @override
  String get browseRestaurants => 'Browse Restaurants';

  @override
  String get notifications => 'Notifications';

  @override
  String get markAllRead => 'Mark all read';

  @override
  String get noNotifications => 'No notifications';

  @override
  String get notificationsWillAppearHere => 'Notifications will appear here';

  @override
  String get specialInstructions => 'Special Instructions';

  @override
  String get typeMessage => 'Type';

  @override
  String get voiceMessage => 'Voice Message';

  @override
  String get save => 'Save';

  @override
  String get typeInstructionsHint => 'e.g., No onions, extra cheese...';

  @override
  String get microphonePermissionDenied => 'Microphone permission denied';

  @override
  String get tapToRecord => 'Tap to record';

  @override
  String get tapAgainToStop => 'Tap again to stop';

  @override
  String get addSpecialInstructions => 'Add Special Instructions';

  @override
  String get customization => 'Customization';

  @override
  String get orderTracking => 'Order Tracking';

  @override
  String get activeOrder => 'Active Order';

  @override
  String get confirmReceipt => 'Confirm Receipt';

  @override
  String get orderMarkedDelivered => 'Order marked as delivered!';

  @override
  String get errorLoadingOrder => 'Error loading order';

  @override
  String get errorLoadingRestaurants => 'Error loading restaurants';

  @override
  String get errorLoadingMenu => 'Error loading menu';

  @override
  String get retry => 'Retry';

  @override
  String get selectDeliveryAddress => 'Select delivery address';

  @override
  String get deliveryAddress => 'Delivery Address';

  @override
  String get paymentMethod => 'Payment Method';

  @override
  String get cashOnDelivery => 'Cash on Delivery';

  @override
  String get payWhenYouReceive => 'Pay when you receive';

  @override
  String get payWithKonnect => 'Pay with Konnect';

  @override
  String get secureOnlinePayment => 'Secure online payment (Tunisia)';

  @override
  String get orderNotes => 'Order Notes';

  @override
  String get specialDeliveryInstructions =>
      'Add any special instructions for delivery...';

  @override
  String get orderSummary => 'Order Summary';

  @override
  String get placeOrder => 'Place Order';

  @override
  String get myOrders => 'My Orders';

  @override
  String get noOrdersYet => 'No orders yet';

  @override
  String get startOrderingMessage => 'Your order history will appear here';

  @override
  String get helpSupport => 'Help & Support';

  @override
  String get supportTicketSent =>
      'Support ticket sent! We will contact you soon.';

  @override
  String get savedAddresses => 'Saved Addresses';

  @override
  String get noAddressesSaved => 'No addresses saved';

  @override
  String get addNewAddress => 'Add New Address';

  @override
  String get addressRemoved => 'Address removed';

  @override
  String get setDefault => 'Set Default';

  @override
  String get noPaymentMethods => 'No payment methods saved';

  @override
  String get addNewCard => 'Add New Card';

  @override
  String get noRestaurantsFound => 'No restaurants found';

  @override
  String get couldNotLoadSupermarkets => 'Could not load supermarkets';

  @override
  String get couldNotGetLocation =>
      'Unable to get current location. Please enable location services.';

  @override
  String get account => 'Account';

  @override
  String get orderHistory => 'Order History';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get paymentMethods => 'Payment Methods';

  @override
  String get user => 'User';

  @override
  String get viewDeals => 'View Deals';

  @override
  String get saveUpTo60 => 'Save up to 60% on food & groceries!';

  @override
  String get happyHour => 'HAPPY HOUR';

  @override
  String get restaurants => 'Restaurants';

  @override
  String get supermarkets => 'Supermarkets';

  @override
  String get noDealsRightNow => 'No deals right now. Check back later!';

  @override
  String get confirmPickupRequest => 'Confirm Pickup Request';

  @override
  String get amountToCollect => 'Amount to Collect:';

  @override
  String get confirmPickup => 'Confirm Pickup';

  @override
  String get pleaseSignInToContinue => 'Please sign in to continue';

  @override
  String get billPayments => 'Bill Payments';

  @override
  String get internet => 'Internet';

  @override
  String get electricity => 'Electricity';

  @override
  String get water => 'Water';

  @override
  String get selectProvider => 'Select Provider';

  @override
  String get noProvidersAvailable =>
      'No providers available for this category yet.';

  @override
  String get howMuchToPay => 'How much to pay?';

  @override
  String get driverWillCollect =>
      'A driver will come to collect this exact amount from you.';

  @override
  String get amountDt => 'Amount (DT)';

  @override
  String get pleaseEnterAmount => 'Please enter amount';

  @override
  String get pleaseEnterValidAmount => 'Please enter a valid amount';

  @override
  String get requestDriverForPickup => 'Request Driver for Pickup';

  @override
  String get serviceFeeNote =>
      'Fees: 2.000 DT service fee will be added by driver';

  @override
  String get pleaseSelectAddress => 'Please select a delivery address';

  @override
  String get pleaseEnterPhone =>
      'Please enter your phone number so the driver can reach you';

  @override
  String get checkout => 'Checkout';

  @override
  String get contactInfo => 'Contact Info';

  @override
  String get phoneHint => 'Phone number (e.g. +216 12 345 678)';

  @override
  String get fullNameHint => 'Full name';

  @override
  String get selectAddress => 'Select Address';

  @override
  String get useCurrentLocation => 'Use Current Location';

  @override
  String get gettingLocation => 'Getting location...';

  @override
  String get enableLocationToDeliver => 'Enable location to deliver here';

  @override
  String get addNew => 'Add New';

  @override
  String get defaultLabel => 'Default';

  @override
  String get couldNotGeocode =>
      'Could not geocode address. Please check the address and try again.';

  @override
  String get labelHint => 'Label (e.g., Home, Work)';

  @override
  String get fullAddressLabel => 'Full Address';

  @override
  String get apartment => 'Apartment';

  @override
  String get floor => 'Floor';

  @override
  String get saveAddress => 'Save Address';

  @override
  String get pleaseSelectPickupDropoff =>
      'Please select both pickup and dropoff locations';

  @override
  String get recipientDetails => 'Recipient Details';

  @override
  String get friendsName => 'Friend\'s Name';

  @override
  String get phoneNumber => 'Phone Number';

  @override
  String get packageDetails => 'Package Details';

  @override
  String get whatAreYouSending => 'What are you sending?';

  @override
  String get locations => 'Locations';

  @override
  String get pickupLocation => 'Pickup Location';

  @override
  String get dropoffLocation => 'Dropoff Location';

  @override
  String get requestCourier => 'Request Courier';

  @override
  String get recipientAccepted => 'Recipient has accepted the package';

  @override
  String get yourCourier => 'Your Courier';

  @override
  String get recipient => 'Recipient';

  @override
  String get phone => 'Phone';

  @override
  String get item => 'Item';

  @override
  String get driverPhoneNotAvailable => 'Driver phone not available yet';

  @override
  String get unableToStartCall => 'Unable to start phone call';

  @override
  String get cardholderName => 'Cardholder Name';

  @override
  String get cardNumber => 'Card Number';

  @override
  String get expiryDate => 'Expiry Date (MM/YY)';

  @override
  String get phoneNumberLabel => 'Phone Number';

  @override
  String get bio => 'Bio';

  @override
  String get subject => 'Subject';

  @override
  String get message => 'Message';

  @override
  String get submitTicket => 'Submit Ticket';

  @override
  String get howCanWeHelp => 'How can we help you?';

  @override
  String get fillFormDescription =>
      'Fill out the form below and our team will get back to you within 24 hours.';

  @override
  String get failedToSendTicket => 'Failed to send ticket. Please try again.';

  @override
  String get removedFromFavorites => 'Removed from favorites';

  @override
  String get addedToFavorites => 'Added to favorites';

  @override
  String get addressRemovedSuccess => 'Address removed';

  @override
  String get pleaseEnterSubject => 'Please enter a subject';

  @override
  String get pleaseEnterMessage => 'Please enter your message';

  @override
  String get pleaseEnterName => 'Please enter your name';

  @override
  String get profileUpdated => 'Profile updated successfully!';

  @override
  String get failedToUpdateProfile => 'Failed to update profile';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get addYourPhoneNumber => 'Add your phone number';

  @override
  String get phoneRequiredExplain =>
      'We need your phone number so drivers can reach you about deliveries. This is a one-time step.';

  @override
  String get phoneInvalid => 'Please enter a valid phone number';

  @override
  String get continueButton => 'Continue';
}
