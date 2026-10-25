// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get forgotPassword => 'Forgot your password?';

  @override
  String get changePassword => 'Change password';

  @override
  String get pwdIntro =>
      'Enter your current password, then choose a new one. You will stay signed in on this device.';

  @override
  String get pwdCurrent => 'Current password';

  @override
  String get pwdNew => 'New password';

  @override
  String get pwdConfirm => 'Confirm new password';

  @override
  String get pwdErrorRequired => 'Required';

  @override
  String get pwdErrorWrongCurrent => 'Current password is wrong';

  @override
  String pwdErrorTooShort(int min) {
    return 'At least $min characters';
  }

  @override
  String get pwdErrorMismatch => 'The two passwords do not match';

  @override
  String get pwdErrorSameAsOld => 'The new password is the same as the old one';

  @override
  String get pwdErrorReauthNeeded =>
      'For security, confirm your identity again before changing your password';

  @override
  String get pwdErrorNoSession => 'Your session has expired. Sign in again.';

  @override
  String get pwdErrorFailed => 'Could not change the password. Try again.';

  @override
  String get pwdChangedTitle => 'Password changed';

  @override
  String get pwdChangedBody =>
      'Other devices are still signed in with the old session. Sign them out?';

  @override
  String get pwdKeepOtherDevices => 'Keep them';

  @override
  String get pwdSignOutOthers => 'Sign out other devices';

  @override
  String get pwdOtherDevicesSignedOut => 'Other devices have been signed out';

  @override
  String get appTitle => 'Amana';

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
  String get chooseOnMap => 'Choose on the map';

  @override
  String get chooseOnMapSubtitle =>
      'Drop the pin exactly where you want the delivery';

  @override
  String get categories => 'Categories';

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
  String get noRestaurantsFound => 'No restaurants found';

  @override
  String get confirmPasswordShort => 'Confirm password';

  @override
  String get pleaseEnterEmail => 'Please enter your email';

  @override
  String get sendResetCode => 'Send the code';

  @override
  String get haveCodeEnterIt => 'Already have a code? Enter it →';

  @override
  String get resetCodeInvalid =>
      'The code is invalid or has expired. Request a new one.';

  @override
  String get passwordUpdatedBody =>
      'Your password has been changed. Sign in with your new password.';

  @override
  String get backToSignIn => 'Back to sign in';

  @override
  String get enterResetCode => 'Enter the code';

  @override
  String get pleaseEnterPassword => 'Please enter a password';

  @override
  String get resetPasswordButton => 'Reset password';

  @override
  String get eightDigitCode => '8-digit code';

  @override
  String get enterEightDigitCode => 'Enter the 8-digit code from your email';

  @override
  String get callUs => 'Call us';

  @override
  String get somethingWentWrong => 'Something went wrong. Please try again.';

  @override
  String codeSentTo(String email) {
    return 'Code sent to $email';
  }

  @override
  String get filterAll => 'All';

  @override
  String get cuisinePastry => 'Pastries';

  @override
  String get cuisinePizza => 'Pizza';

  @override
  String get cuisineBurgers => 'Burgers';

  @override
  String get cuisineSushi => 'Sushi';

  @override
  String get cuisineMexican => 'Mexican';

  @override
  String get cuisineItalian => 'Italian';

  @override
  String get cuisineFastFood => 'Fast food';

  @override
  String get shopOpen => 'Open';

  @override
  String get shopClosed => 'Closed';

  @override
  String get newShopBadge => 'New';

  @override
  String get deliveryLabel => 'Delivery';

  @override
  String get minOrderLabel => 'Min. order';

  @override
  String get deliveryTimeLabel => 'Delivery time';

  @override
  String get couldNotLoadShops => 'Could not load shops';

  @override
  String get newShopsSoon => 'Check back soon — new shops are on the way.';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get timeJustNow => 'Just now';

  @override
  String reviewsCount(int count) {
    return '$count reviews';
  }

  @override
  String timeMinutesAgo(int minutes) {
    return '$minutes min ago';
  }

  @override
  String timeHoursAgo(int hours) {
    return '$hours h ago';
  }

  @override
  String noRestaurantsNearby(int km) {
    return 'No restaurant within $km km of you yet.';
  }

  @override
  String noSupermarketsNearby(int km) {
    return 'No supermarket within $km km of you yet.';
  }

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
  String get user => 'User';

  @override
  String get viewDeals => 'View Deals';

  @override
  String get saveUpTo60 => 'Save up to 60% on food & groceries!';

  @override
  String get happyHour => 'HAPPY HOUR';

  @override
  String get happyHourLive => 'LIVE';

  @override
  String get receiptQuestion => 'Did you receive your order?';

  @override
  String get receiptQuestionParcel => 'Was your parcel handed over?';

  @override
  String get receiptYesParcel => 'Yes, delivered';

  @override
  String get receiptNoParcel => 'No, not delivered';

  @override
  String get receiptNotDeliveredParcelLink => 'My parcel was not delivered';

  @override
  String get receiptReportBodyParcel =>
      'We will tell our support team that this parcel was not handed over.';

  @override
  String receiptAutoIn(String time) {
    return 'Confirms automatically in $time';
  }

  @override
  String get receiptYes => 'Yes, received';

  @override
  String get receiptNo => 'No, not received';

  @override
  String get receiptConfirmed => 'Receipt confirmed. Thank you!';

  @override
  String get receiptAutoConfirmed => 'Receipt confirmed automatically';

  @override
  String get receiptNotReceivedLink => 'I did not receive my order';

  @override
  String get receiptReportTitle => 'Report a problem?';

  @override
  String get receiptReportBody =>
      'We will tell our support team that you did not receive this order.';

  @override
  String get receiptReportConfirm => 'Report';

  @override
  String get receiptReported => 'Reported. Our support team will contact you.';

  @override
  String get receiptSaveFailed =>
      'Could not save your answer. Please try again.';

  @override
  String get receiptTapToConfirm => 'Tap to confirm';

  @override
  String get rateDriverTitle => 'Rate your driver';

  @override
  String get rateDriverButton => 'Rate the driver';

  @override
  String get rateDriverHint => 'A comment? (optional)';

  @override
  String get rateDriverSend => 'Send';

  @override
  String get rateDriverLater => 'Later';

  @override
  String get rateDriverThanks => 'Thanks for your review!';

  @override
  String get rateDriverFailed => 'Could not send your review right now.';

  @override
  String happyHourDealsSummary(int count, int percent) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count deals · up to -$percent%',
      one: '1 deal · up to -$percent%',
    );
    return '$_temp0';
  }

  @override
  String happyHourEndsIn(String time) {
    return 'Ends in $time';
  }

  @override
  String get happyHourNoDealsNow => 'No deals right now, check back soon';

  @override
  String happyHourUnitsLeft(int count) {
    return 'Only $count left!';
  }

  @override
  String get happyHourShopsTab => 'Shops';

  @override
  String addedToCartWithQuantity(int quantity, String item) {
    return '$quantity x $item added to cart';
  }

  @override
  String get chooseAnOption => 'Choose an option';

  @override
  String get errorLoadingItems => 'Could not load the products';

  @override
  String get supermarketClosedNow => 'This supermarket is closed right now.';

  @override
  String get restaurantClosedLabel => 'Restaurant closed';

  @override
  String get organic => 'Organic';

  @override
  String get happyHourSubtitle => 'The best prices on your favourite dishes';

  @override
  String get promos => 'DEALS';

  @override
  String get promosSubtitle => 'Percentage off at your favourite shops';

  @override
  String get promosBannerCta => 'See the deals';

  @override
  String get happyHourGrab => 'Grab it!';

  @override
  String addedToCart(String item) {
    return '$item added to cart';
  }

  @override
  String get happyHourLoadError => 'Could not load the deals';

  @override
  String get viewCart => 'View cart';

  @override
  String get cartFromAnotherShopTitle => 'Cart from another shop';

  @override
  String get cartFromAnotherShopMessage =>
      'Your cart already contains items from another shop. Empty it to add this item?';

  @override
  String get emptyAndAdd => 'Empty and add';

  @override
  String get newItemBadge => 'NEW';

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
  String get pickupLocation => 'Pickup location';

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
  String get sendParcelTitle => 'Send a parcel';

  @override
  String get sendParcelSubtitle => 'Send any item from point A to point B';

  @override
  String get parcelSuccessTitle => 'Your parcel is on its way!';

  @override
  String orderSuccessTrackingRef(String ref) {
    return 'Order #$ref';
  }

  @override
  String get trackMyParcel => 'Track my parcel';

  @override
  String get trackMyOrder => 'Track my order';

  @override
  String get backToHome => 'Back to home';

  @override
  String get foodHeroTitle => 'Order a meal';

  @override
  String get supermarketHeroTitle => 'Get your groceries';

  @override
  String get factureHeroTitle => 'Pay a bill';

  @override
  String get supermarketSuccessTitle => 'Your order is on its way!';

  @override
  String get factureSuccessTitle => 'Your bill is being handled!';

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
  String get phoneInvalid => 'Please enter a valid 8-digit Tunisian number';

  @override
  String get continueButton => 'Continue';

  @override
  String get promoCode => 'Promo Code';

  @override
  String get promoCodePlaceholder => 'Enter your promo code';

  @override
  String get billTypeElectricity => 'STEG (electricity)';

  @override
  String get billTypeWater => 'SONEDE (water)';

  @override
  String get billTypeInternet => 'Topnet (internet)';

  @override
  String get packageFallback => 'Package';

  @override
  String get orderStatusPending => 'Pending';

  @override
  String get orderStatusConfirmed => 'Confirmed';

  @override
  String get orderStatusPreparing => 'Preparing';

  @override
  String get orderStatusReady => 'Ready';

  @override
  String get orderStatusPickedUp => 'Picked up';

  @override
  String get orderStatusOnTheWay => 'On the way';

  @override
  String get orderStatusDelivered => 'Delivered';

  @override
  String get orderStatusCancelled => 'Cancelled';

  @override
  String get timelineOrderConfirmed => 'Order confirmed';

  @override
  String get timelinePreparing => 'Preparing';

  @override
  String get timelineReady => 'Ready';

  @override
  String get timelineOnTheWay => 'On the way';

  @override
  String get timelineDelivered => 'Delivered';

  @override
  String get timelineRequestConfirmed => 'Request confirmed';

  @override
  String get timelinePickedUp => 'Picked up';

  @override
  String get timelineDriverComing => 'Driver on the way to you';

  @override
  String get timelineCashCollected => 'Cash collected';

  @override
  String get timelineBillPaid => 'Bill paid';

  @override
  String estimatedDeliveryAt(String time) {
    return 'Estimated delivery: $time';
  }

  @override
  String get orderDetailsTitle => 'Order details';

  @override
  String get billDetailsTitle => 'Bill details';

  @override
  String get deliveryLocation => 'Delivery location';

  @override
  String get paymentOffice => 'Payment office';

  @override
  String get yourAddress => 'Your address';

  @override
  String get driverLabel => 'Driver';

  @override
  String get routeLabel => 'Route';

  @override
  String get billTypeField => 'Type';

  @override
  String get billReferenceField => 'Reference';

  @override
  String get billAmountField => 'Amount';

  @override
  String get billPhotoLabel => 'Bill photo';

  @override
  String get paymentReceiptLabel => 'Payment receipt';

  @override
  String get paymentMethodCash => 'Cash';

  @override
  String get cancelOrderTitle => 'Cancel the order';

  @override
  String get cancelDriverAssigned =>
      'A driver has already been assigned to your order. Cancel anyway?';

  @override
  String get cancelReasonLabel => 'Reason for cancelling:';

  @override
  String get cancelReasonWrongOrder => 'Ordering mistake';

  @override
  String get cancelReasonTooLong => 'Taking too long';

  @override
  String get cancelReasonChangedMind => 'I changed my mind';

  @override
  String get cancelReasonOther => 'Other';

  @override
  String get backAction => 'Back';

  @override
  String get confirmAction => 'Confirm';

  @override
  String get orderCancelledOk => 'Order cancelled.';

  @override
  String get cancelTooLatePreparing =>
      'Too late to cancel — the order is already being prepared.';

  @override
  String get cancelTooLateOnTheWay =>
      'The order is already on its way. Contact support to cancel.';

  @override
  String placeOrderWithTotal(String total) {
    return 'Place order — $total';
  }

  @override
  String get venueClosedNow =>
      'This shop is currently closed and cannot take orders.';

  @override
  String get paymentFailedOrderCancelled => 'Payment failed. Order cancelled.';

  @override
  String get loyaltyFreeDelivery => 'Loyalty — free delivery';

  @override
  String get loyaltyHalfDelivery => 'Loyalty — 50% off delivery';

  @override
  String genericErrorWith(String message) {
    return 'Error: $message';
  }

  @override
  String promoOnEligible(String discount, String eligible) {
    return '− $discount on $eligible eligible';
  }

  @override
  String get promoErrorNotFound => 'This promo code does not exist';

  @override
  String get promoErrorInactive => 'This promo code is no longer active';

  @override
  String get promoErrorExpired => 'This code has expired or is not valid yet';

  @override
  String get promoErrorMaxUses => 'This code is no longer available';

  @override
  String get promoErrorAlreadyUsed => 'You have already used this promo code';

  @override
  String get promoErrorMinOrder => 'Your order is below this code\'s minimum';

  @override
  String promoErrorMinOrderAmount(String amount) {
    return 'This code needs a minimum order of $amount';
  }

  @override
  String get promoErrorAllOnPromo =>
      'Your items are already discounted, so this code does not apply';

  @override
  String get promoErrorNotFirstOrder =>
      'This code is for your first order only';

  @override
  String get promoErrorEmptyCart => 'Your cart is empty';

  @override
  String get promoErrorNotLoggedIn => 'Sign in to use a promo code';

  @override
  String get promoErrorNetwork => 'Network error. Please try again.';

  @override
  String get promoErrorGeneric => 'Invalid or expired code';

  @override
  String get applyPromoCode => 'Apply';

  @override
  String get removePromoCode => 'Remove';

  @override
  String get promoApplied => 'Discount applied!';

  @override
  String promoDiscount(String code) {
    return 'Discount ($code)';
  }

  @override
  String get loyaltyCardTitle => 'Loyalty card';

  @override
  String get loyaltyPendingSubtitle => 'Stamp pending — confirmed at delivery';

  @override
  String get loyaltyProgressLabel => 'Your progress';

  @override
  String loyaltyRemainingHalf(int count) {
    return '$count more orders for half-price delivery';
  }

  @override
  String loyaltyRemainingFree(int count) {
    return '$count more orders for free delivery';
  }

  @override
  String get loyaltyCelebrationHalf =>
      'This is your 5th order — your delivery is half price!';

  @override
  String get loyaltyCelebrationFree => '10th order — your delivery is free!';

  @override
  String get loyaltyViewRewards => 'See my rewards';

  @override
  String get loyaltyCancelTitle => 'Order cancelled';

  @override
  String get loyaltyCancelMessage =>
      'Got it! We hope to see you again soon. Thanks for your trust!';

  @override
  String get loyaltyCancelNote =>
      'This order\'s stamp has been removed from your card.';

  @override
  String get loyaltyCancelPrimaryCta => 'Order again';

  @override
  String get loyaltyCancelSecondaryCta => 'Close';

  @override
  String get loyaltyRewardsTitle => 'My rewards';

  @override
  String get loyaltyMilestoneHalfTitle => '5th order';

  @override
  String get loyaltyMilestoneHalfSubtitle => 'Half-price delivery';

  @override
  String get loyaltyMilestoneFreeTitle => '10th order';

  @override
  String get loyaltyMilestoneFreeSubtitle => 'Free delivery';

  @override
  String get loyaltyStateAchieved => 'Achieved';

  @override
  String get loyaltyStateCurrent => 'In progress';

  @override
  String get loyaltyStateLocked => 'Locked';

  @override
  String get loyaltyHowItWorksTitle => 'How it works';

  @override
  String get loyaltyHowItWorks1 => 'Each delivered order = 1 stamp';

  @override
  String get loyaltyHowItWorks2 =>
      'Discounts apply automatically to the delivery fee of the order that reaches the milestone';

  @override
  String get loyaltyHowItWorks3 => 'Cancelled orders don\'t count';

  @override
  String get loyaltyHowItWorks4 =>
      'After the 10th order, the card resets and a new cycle begins';

  @override
  String get optionGroupRequired => 'Required';

  @override
  String get optionGroupOptional => 'Optional';

  @override
  String optionGroupSelectExact(int count) {
    return 'Select $count';
  }

  @override
  String optionGroupSelectUpTo(int max) {
    return 'Select up to $max';
  }

  @override
  String optionGroupSelectRange(int min, int max) {
    return 'Select $min to $max';
  }

  @override
  String addToCartWithTotal(String total) {
    return 'Add to Cart · $total';
  }

  @override
  String get completeRequiredSelections =>
      'Please complete the required selections';

  @override
  String get variantGroupTitle => 'Choose an option';

  @override
  String get aiSearchTitle => 'AI Search';

  @override
  String get aiSearchPlaceholder =>
      'N7eb nekel 7aja 7arra… ou décris ce que tu veux';

  @override
  String get aiSearchCameraTooltip => 'Search by photo';

  @override
  String get aiSearchVisualSearchBadge => 'Visual Search';

  @override
  String aiSearchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results found',
      one: '1 result found',
    );
    return '$_temp0';
  }

  @override
  String get aiSearchLoadingPhoto => 'Analyzing your photo…';

  @override
  String get aiSearchLoadingText => 'Understanding your request…';

  @override
  String get aiSearchPoweredBy => 'Powered by AI';

  @override
  String get aiSearchEmptyTitle => 'Describe what you want';

  @override
  String get aiSearchEmptyDescription =>
      'Type in Darija, French or Arabic — or upload a photo of a dish you want to find.';

  @override
  String get aiSearchExampleQuery1 => 'N7eb chapati w ma tfoutch 10 dinar';

  @override
  String get aiSearchExampleQuery2 => 'Une pizza pas chère';

  @override
  String get aiSearchExampleQuery3 => 'A malfouf under 12 dinars';

  @override
  String get aiSearchExampleQueryPhoto => 'Upload a food photo';

  @override
  String aiSearchNoResultsPhoto(String dishName) {
    return 'No restaurants found for \"$dishName\"';
  }

  @override
  String get aiSearchNoResultsText => 'No dishes match your request';

  @override
  String get aiSearchFallbackMessage =>
      'No exact match — here are some popular dishes';

  @override
  String get aiSearchModalTitle => 'Search by Photo';

  @override
  String aiSearchModalHint(String city) {
    return 'Upload a photo of a dish to find it in $city';
  }

  @override
  String get aiSearchCameraLabel => 'Camera';

  @override
  String get aiSearchGalleryLabel => 'Gallery';

  @override
  String get aiSearchTryAgain => 'Try again';

  @override
  String get aiSearchErrorCouldNotOpen => 'Could not open image';

  @override
  String aiSearchIdentified(String dishName, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count restaurants',
      one: '1 restaurant',
    );
    return 'Identified: \"$dishName\" · $_temp0';
  }

  @override
  String get city => 'Tunisia';

  @override
  String get colisHandoverSectionTitle =>
      'How does the driver hand over your parcel?';

  @override
  String get colisModeRecommended => 'Recommended';

  @override
  String get colisModeCodeTitle => 'With a code';

  @override
  String get colisModeCodeSubtitle =>
      'The safest option for you. You get a 4-digit code. Send it to the person receiving the parcel. On arrival, they give the code to the driver. Without the right code, the driver cannot complete the delivery. So you know your parcel reaches the right person.';

  @override
  String get colisModeNoCodeTitle => 'Hand over without a code';

  @override
  String get colisModeNoCodeSubtitle =>
      'For when the person has no phone (a child at school, a caretaker…). The driver takes a photo at the moment of handover, with their location. It is less safe than with a code.';

  @override
  String colisCodeHeadline(String code) {
    return 'Your delivery code: $code';
  }

  @override
  String get colisCodeExplain =>
      'Send this code to the recipient. They will give it to the driver when they receive the parcel.';

  @override
  String colisShareMessage(String code) {
    return 'Hello, an Amana parcel is on its way to you. Give this code to the driver on arrival: $code';
  }

  @override
  String get colisShareSubject => 'Amana delivery code';

  @override
  String get mapGpsUnavailable => 'Couldn\'t get your GPS position';

  @override
  String get mapUseCurrentLocation => 'Use my current location';

  @override
  String get mapOr => 'or';

  @override
  String get mapSearchHint => 'Search for an address or place…';

  @override
  String get mapTypeStreetHint => 'Type a street, neighbourhood or place…';

  @override
  String get mapNoResults => 'No results';

  @override
  String get mapLocating => 'Locating…';

  @override
  String get mapLocatingInProgress => 'Finding your location…';

  @override
  String get mapDragToAdjust => 'Drag to adjust the position';

  @override
  String get mapDragToPlace => 'Drag the map to the spot you want';

  @override
  String get mapConfirmLocation => 'Confirm this location';

  @override
  String get authErrorInvalidCredentials => 'Incorrect email or password';

  @override
  String get authErrorAccountExists =>
      'An account already exists with this email';

  @override
  String get authErrorEmailNotConfirmed =>
      'Please confirm your email before signing in';

  @override
  String get authErrorNoInternet => 'Internet connection problem';

  @override
  String get authErrorTimeout =>
      'The server is taking too long to respond. Try again.';

  @override
  String get authErrorServiceUnavailable =>
      'The service is temporarily unavailable. Try again in a moment.';

  @override
  String get authErrorGeneric => 'Something went wrong, please try again';

  @override
  String get authCheckFormFields => 'Check the form fields';

  @override
  String get authAccountCreatedConfirmEmail =>
      'Account created! Open the confirmation email we just sent, then sign in.';

  @override
  String get billsTitle => 'My bills';

  @override
  String get billsLoadError => 'Couldn\'t load your bills';

  @override
  String get billsEmptyTitle => 'No bills paid yet';

  @override
  String get billsEmptySubtitle => 'Your bill payments will appear here';

  @override
  String billsReference(String reference) {
    return 'Ref: $reference';
  }

  @override
  String get billsReceiptAvailable => 'Receipt available';

  @override
  String get billsLabelSteg => 'STEG — Electricity';

  @override
  String get billsLabelSonede => 'SONEDE — Water';

  @override
  String get billsLabelTopnet => 'Topnet — Internet';

  @override
  String get billsLabelOther => 'Other bill';

  @override
  String get billStatusPaid => 'Paid';

  @override
  String get billStatusInProgress => 'In progress';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonInvalidAmount => 'Invalid amount';

  @override
  String get commonInvalidPhone8 =>
      'Invalid number — exactly 8 digits required';

  @override
  String get photoTakePicture => 'Take a photo';

  @override
  String get photoChooseFromGallery => 'Choose from gallery';

  @override
  String get courierDeleteRecipientTitle => 'Delete this recipient?';

  @override
  String courierDeleteRecipientBody(String name) {
    return '$name will be removed from your saved contacts.';
  }

  @override
  String get courierPickupAddress => 'Pickup address';

  @override
  String get courierConfirmNoForbidden =>
      'Confirm that your parcel contains no forbidden items.';

  @override
  String get courierAcceptPhotoProof =>
      'Accept that the photo and location will serve as proof.';

  @override
  String get courierDeclaredValueRequired => 'Enter the value of your parcel';

  @override
  String get courierDeclaredValuePositive => 'The value must be greater than 0';

  @override
  String courierDeclaredValueMax(String max) {
    return 'Maximum $max TND — split your shipment';
  }

  @override
  String get courierDescriptionRequired => 'Describe what is in your parcel';

  @override
  String get courierReceiverLabelRequired =>
      'Say who the parcel will be handed to';

  @override
  String get courierSenderPhone => 'Sender\'s phone';

  @override
  String get courierSenderPhoneHint => 'The person handing over the parcel';

  @override
  String get courierSenderPhoneRequired => 'Required — sender\'s number';

  @override
  String get courierRecipientName => 'Recipient\'s name';

  @override
  String get courierRecipientNameHint =>
      'Optional — helps the driver identify the recipient';

  @override
  String get courierRecipientNameExample => 'E.g. Mohamed Ben Ali';

  @override
  String get courierRecipientPhone => 'Recipient\'s phone';

  @override
  String get courierRecipientPhoneHint => 'The person receiving the parcel';

  @override
  String get courierRecipientPhoneRequired => 'Required — recipient\'s number';

  @override
  String get courierContentsTitle => 'What is in your parcel?';

  @override
  String get courierContentsExample =>
      'E.g. Samsung A15 phone, documents, clothes…';

  @override
  String get courierDeclaredValue => 'Declared value';

  @override
  String courierDeclaredValueCap(String max) {
    return 'Limit: $max TND. Above that, split your shipment into several parcels.';
  }

  @override
  String get courierDeclaredValueHint => 'Value in TND';

  @override
  String get courierPhotoTitle => 'Parcel photo';

  @override
  String get courierPhotoHint =>
      'Optional — helps the driver identify your parcel';

  @override
  String get courierSizeTitle => 'Parcel size';

  @override
  String get courierConfirmSend => 'Confirm sending';

  @override
  String get courierTapToSelect => 'Tap to select';

  @override
  String get courierPhoneExample => 'E.g. 20123456';

  @override
  String get courierEstimatedPrice => 'Estimated price';

  @override
  String get courierEstimatedPriceLoyaltyFree =>
      'Estimated price — loyalty: free delivery';

  @override
  String get courierEstimatedPriceLoyaltyHalf =>
      'Estimated price — loyalty: -50%';

  @override
  String get courierPriceBase => '3.500 TND base';

  @override
  String get courierReceiverLabelExample =>
      'E.g. school caretaker, neighbour on the 3rd floor…';

  @override
  String get courierAcceptPhotoProofCheckbox =>
      'I accept that the proof of delivery is the driver\'s photo and location.';

  @override
  String get courierForbiddenTitle => 'Not allowed in a parcel';

  @override
  String get courierForbiddenConfirm =>
      'I confirm that my parcel contains none of these items';

  @override
  String get courierPhotoChange => 'Change';

  @override
  String get courierPhotoAdd => 'Add a photo of the parcel';

  @override
  String get courierPhotoTapHint => 'Tap to take/choose a photo';

  @override
  String get courierSizeSmall => 'Small';

  @override
  String get courierSizeMedium => 'Medium';

  @override
  String get courierSizeLarge => 'Large';

  @override
  String get courierSizeSmallDesc => 'Documents, small items';

  @override
  String get courierSizeMediumDesc => 'Clothes, accessories';

  @override
  String get courierSizeLargeDesc => 'Luggage, large parcels';

  @override
  String get courierSaveRecipient => 'Save this recipient for next time';

  @override
  String get courierSavedRecipients => 'Saved recipients';

  @override
  String get factureSelectBillType => 'Please select the bill type';

  @override
  String get factureEnterPickupAddress => 'Please enter your pickup address';

  @override
  String get factureEnterOfficeAddress => 'Please enter the office address';

  @override
  String get factureNotSignedIn => 'Not signed in';

  @override
  String get factureReferenceRequired => 'Required — reference number';

  @override
  String get factureAmountRequired => 'Required — bill amount';

  @override
  String get facturePhoneRequired => 'Required — phone number';

  @override
  String get factureBillTypeTitle => 'Bill type';

  @override
  String get factureReferenceLabel => 'Reference / contract number';

  @override
  String get factureAmountLabel => 'Amount to pay (TND)';

  @override
  String get factureCustomerAddressTitle => 'Your address (cash pickup)';

  @override
  String get factureChooseYourAddress => 'Choose your address';

  @override
  String factureOfficeAddressTitle(String billType) {
    return 'Office address $billType';
  }

  @override
  String get factureChooseOfficeAddress => 'Choose the office address';

  @override
  String get facturePhoneTitle => 'Your phone number';

  @override
  String get facturePhoneLabel => 'Phone (8 digits)';

  @override
  String get factureAddBillPhoto => 'Add a photo of the bill (optional)';

  @override
  String get factureRemovePhoto => 'Remove the photo';

  @override
  String get factureBillAmount => 'Bill amount';

  @override
  String get factureCollectedInCash => '(collected in cash)';

  @override
  String get factureServiceFee => 'Service fee';

  @override
  String get factureLoyaltyHalf => 'Loyalty — -50%';

  @override
  String get factureSendRequest => 'Send the request';

  @override
  String get colisDisputeExplain =>
      'Describe what happened. An administrator will review the evidence (photos, time, location) before deciding.';

  @override
  String get colisDisputeMessageHint => 'Your message (optional)';

  @override
  String get colisDisputeSendFailed => 'The report could not be sent.';

  @override
  String get colisReceiptTitle => 'Pickup receipt';

  @override
  String get colisReceiptDeclaredContents => 'Declared contents';

  @override
  String get colisReceiptHandedTo => 'Handed to';

  @override
  String get colisReceiptPlate => 'Plate';

  @override
  String get colisReceiptDistanceToAddress => 'Distance to the address';

  @override
  String get colisProofPickup => 'Pickup';

  @override
  String get colisProofDelivery => 'Handover';

  @override
  String get colisDisputeSent =>
      'Report sent. An administrator will review it.';

  @override
  String get colisDisputeWindow =>
      'A problem? You have 24 h after delivery to report it.';

  @override
  String get colisDisputeNotReceivedTitle => 'Parcel not received';

  @override
  String get colisDisputeNotReceived => 'Not received';

  @override
  String get colisDisputeProblem => 'Problem with the parcel';

  @override
  String get colisCodeCopy => 'Copy';

  @override
  String get colisCodeCopied => 'Code copied';

  @override
  String get colisCodeShare => 'Share';

  @override
  String get loyaltyAppliedFree =>
      '🎉 Free delivery applied — thank you for your loyalty!';

  @override
  String get loyaltyAppliedHalf =>
      '🎉 -50% on delivery applied — thank you for your loyalty!';

  @override
  String loyaltyProgressOrders(String progress) {
    return '$progress/5 orders until your next discount';
  }

  @override
  String get loyaltyBadgeFree => '🎉 Free delivery';

  @override
  String get loyaltyBadgeHalf => '🎉 -50% on delivery';

  @override
  String get reorderButton => 'Order again';

  @override
  String get reorderReplaceCartTitle => 'Replace the cart?';

  @override
  String get reorderReplaceCartBody =>
      'Your cart already has items. Replace them with the ones from this order?';

  @override
  String get reorderReplace => 'Replace';

  @override
  String get reorderNothingAvailable =>
      'None of the items from this order are available right now.';

  @override
  String reorderSkipped(String count) {
    return '$count unavailable item(s) were skipped.';
  }

  @override
  String get reorderFailed =>
      'Something went wrong while reordering. Try again.';

  @override
  String get orderTypeFacture => 'Bill payment';

  @override
  String get orderShopSupermarket => 'Supermarket';

  @override
  String get orderShopBakery => 'Bakery';

  @override
  String get orderShopFlowers => 'Flowers';

  @override
  String get orderShopPets => 'Pet shop';

  @override
  String get orderShopGifts => 'Gifts';

  @override
  String get orderShopElectronics => 'Electronics';

  @override
  String get orderShopRestaurant => 'Restaurant';

  @override
  String get homeEmptyBakery => 'No bakery available near you.';

  @override
  String get homeEmptyFlowers => 'No florist available near you.';

  @override
  String get homeEmptyPets => 'No pet shop available near you.';

  @override
  String get homeEmptyGifts => 'No gift shop near you.';

  @override
  String get homeEmptyElectronics => 'No electronics shop near you.';

  @override
  String get homeEmptyShops => 'No shop available near you.';

  @override
  String get profileUploadFailed => 'Upload failed. Please try again.';

  @override
  String get profileBillReminders => 'Bill reminders';

  @override
  String get ratingOrderQuestion => 'How was your order?';

  @override
  String get vendorCatalogueLoadError => 'Couldn\'t load the catalogue';

  @override
  String get vendorNoItemsYet => 'No items yet.';

  @override
  String get vendorDefaultSection => 'Items';

  @override
  String get vendorClosedNotice => 'This shop is currently closed.';

  @override
  String get forgotPasswordIntro =>
      'Enter your email and we\'ll send\nyou a 6-digit reset code.';

  @override
  String voiceRecordStartFailed(String error) {
    return 'Failed to start recording: $error';
  }

  @override
  String voiceRecordStopFailed(String error) {
    return 'Failed to stop recording: $error';
  }

  @override
  String voicePlayFailed(String error) {
    return 'Failed to play audio: $error';
  }

  @override
  String get addressLabelRequired => 'Please enter a label';

  @override
  String get addressRequired => 'Please enter an address';

  @override
  String addressAptFloor(String apartment, String floor) {
    return 'Apt: $apartment, Floor: $floor';
  }

  @override
  String get aiChatTooltip => 'AI Chat';

  @override
  String get ordersLoadError => 'Failed to load orders';

  @override
  String get orderTypeCourier => 'Parcel delivery';

  @override
  String etaMinutes(String minutes) {
    return '$minutes minutes';
  }

  @override
  String get helpEmailUs => 'Email us';

  @override
  String get quantity => 'Quantity';

  @override
  String restaurantShareText(
      String name, String description, String rating, String minutes) {
    return 'Check out $name!\n$description\nRating: $rating ⭐\nDelivery: $minutes min';
  }

  @override
  String get aiChipSpicy => '🌶 Spicy';

  @override
  String get aiChipVegetarian => '🥦 Vegetarian';

  @override
  String get aiChipFast => '⚡ Fast';

  @override
  String get aiBadgeVeg => '🥦 Veg';

  @override
  String get aiThisDish => 'this dish';

  @override
  String get aiSearchErrorNetwork =>
      'Network error. Please check your connection.';

  @override
  String get aiSearchErrorUnavailable =>
      'Service temporarily unavailable. Try again later.';

  @override
  String get aiSearchErrorNoDish =>
      'Could not identify a dish in this photo. Try a clearer image.';

  @override
  String aiSearchErrorImageTooLarge(String size) {
    return 'Image is too large ($size MB). Please use an image smaller than 10 MB.';
  }

  @override
  String get aiSearchErrorUnknown => 'Unknown error';

  @override
  String get deleteAccount => 'Delete my account';

  @override
  String get deleteAccountIntro =>
      'Deletion is permanent. You will no longer be able to sign in with this account.';

  @override
  String get deleteAccountDeletedTitle => 'What will be deleted';

  @override
  String get deleteAccountDeletedDevices =>
      'Your notifications and signed-in devices';

  @override
  String get deleteAccountKeptTitle => 'What will be kept';

  @override
  String get deleteAccountKeptWhy =>
      'This information is kept for accounting and in case of a dispute.';

  @override
  String get deleteAccountBlockedTitle => 'Your account cannot be deleted yet';

  @override
  String get deleteAccountContactTeam => 'Contact the Amana team';

  @override
  String get deleteAccountBlockerAdmin =>
      'This is an administrator account: it cannot be deleted from the app.';

  @override
  String deleteAccountBlockerActiveOrders(int count) {
    return 'You have $count order(s) in progress. Wait until they are delivered or cancelled.';
  }

  @override
  String get deleteAccountBlockerOpenDisputes =>
      'A parcel dispute is still open. Wait for the Amana team to close it.';

  @override
  String deleteAccountBlockerDriverOrders(int count) {
    return 'You have $count delivery(ies) in progress. Finish them first.';
  }

  @override
  String get deleteAccountBlockerDriverDisputes =>
      'A parcel dispute involving you is still open. Wait for the Amana team to close it.';

  @override
  String get deleteAccountBlockerDriverPayouts =>
      'Amana still owes you bonuses. Contact the Amana team to settle your account.';

  @override
  String deleteAccountBlockerShopOrders(int count) {
    return 'Your shop has $count order(s) in progress. Complete or cancel them first.';
  }

  @override
  String deleteAccountBlockerWallet(String amount) {
    return '$amount TND remain on your balance. Contact the Amana team to settle your account.';
  }

  @override
  String get deleteAccountBlockerSettlements =>
      'A settlement is pending. Contact the Amana team to settle your account.';

  @override
  String get deleteAccountBlockerUnknown =>
      'Your account cannot be deleted right now. Contact the Amana team.';

  @override
  String get deleteAccountConfirmWord => 'DELETE';

  @override
  String deleteAccountTypeWord(String word) {
    return 'To confirm, type $word';
  }

  @override
  String deleteAccountWordMismatch(String word) {
    return 'Type exactly $word';
  }

  @override
  String get deleteAccountPasswordHint =>
      'For your security, enter your password';

  @override
  String get deleteAccountPasswordLabel => 'Password';

  @override
  String get deleteAccountGoogleHint =>
      'For your security, you will sign in again with this account\'s Google account.';

  @override
  String get deleteAccountSubmit => 'Permanently delete my account';

  @override
  String get deleteAccountErrorWrongPassword => 'Incorrect password.';

  @override
  String get deleteAccountErrorOtherGoogle =>
      'This Google account is not the one linked to this Amana account.';

  @override
  String get deleteAccountErrorReauth =>
      'Your confirmation has expired. Please try again.';

  @override
  String get deleteAccountErrorNoMethod =>
      'This account cannot be confirmed in the app. Contact the Amana team.';

  @override
  String get deleteAccountErrorFailed =>
      'Deletion failed. Try again or contact the Amana team.';

  @override
  String get deleteAccountLoadError =>
      'Could not check your account. Check your connection.';

  @override
  String get deleteAccountRetry => 'Retry';

  @override
  String get deleteAccountDoneTitle => 'Account deleted';

  @override
  String get deleteAccountDoneOk => 'OK';

  @override
  String get deleteAccountDeletedContact =>
      'Your contact details: name, phone, email and photo';

  @override
  String get deleteAccountDeletedAddresses =>
      'Your saved addresses and recipients';

  @override
  String get deleteAccountDeletedPayment => 'Your saved payment cards';

  @override
  String get deleteAccountDeletedChat =>
      'Your history with the Amana assistant';

  @override
  String get deleteAccountKeptOrders =>
      'Your orders, for accounting: dates, status, items, amounts, fees and payments, with nothing that identifies you';

  @override
  String get deleteAccountKeptColis =>
      'The handover proof of your parcels (photos, GPS, driver\'s plate and ID), for 30 days after your last order, then it is erased';

  @override
  String get deleteAccountAppleHint =>
      'For your security, you will sign in again with Apple.';

  @override
  String get deleteAccountDoneBody =>
      'Your account has been deleted. Thank you for using Amana.';

  @override
  String get deleteAccountDeletedOrderDetails =>
      'In your past orders: addresses, GPS positions, phone numbers, names, notes, voice messages and bill photos, including the name and phone of your parcel recipients';

  @override
  String get cannotOpenContactApp =>
      'Couldn\'t open the app. Contact us at +216 24 697 855.';
}
