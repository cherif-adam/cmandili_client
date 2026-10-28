// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get forgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get changePassword => 'تغيير كلمة المرور';

  @override
  String get pwdIntro =>
      'أدخل كلمة المرور الحالية، ثم اختر واحدة جديدة. ستبقى متصلاً على هذا الجهاز.';

  @override
  String get pwdCurrent => 'كلمة المرور الحالية';

  @override
  String get pwdNew => 'كلمة المرور الجديدة';

  @override
  String get pwdConfirm => 'تأكيد كلمة المرور الجديدة';

  @override
  String get pwdErrorRequired => 'حقل مطلوب';

  @override
  String get pwdErrorWrongCurrent => 'كلمة المرور الحالية غير صحيحة';

  @override
  String pwdErrorTooShort(int min) {
    return '$min أحرف على الأقل';
  }

  @override
  String get pwdErrorMismatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get pwdErrorSameAsOld => 'كلمة المرور الجديدة مطابقة للقديمة';

  @override
  String get pwdErrorReauthNeeded =>
      'للأمان، أكّد هويتك مجدداً قبل تغيير كلمة المرور';

  @override
  String get pwdErrorNoSession => 'انتهت الجلسة. سجّل الدخول مجدداً.';

  @override
  String get pwdErrorFailed => 'تعذّر تغيير كلمة المرور. حاول مجدداً.';

  @override
  String get pwdChangedTitle => 'تم تغيير كلمة المرور';

  @override
  String get pwdChangedBody =>
      'لا تزال أجهزة أخرى متصلة بالجلسة القديمة. هل تريد إنهاء جلساتها؟';

  @override
  String get pwdKeepOtherDevices => 'احتفظ بها';

  @override
  String get pwdSignOutOthers => 'إنهاء جلسات الأجهزة الأخرى';

  @override
  String get pwdOtherDevicesSignedOut => 'تم إنهاء جلسات الأجهزة الأخرى';

  @override
  String get appTitle => 'Amana';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get signUp => 'إنشاء حساب';

  @override
  String get createAccount => 'إنشاء حساب';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get password => 'كلمة المرور';

  @override
  String get fullName => 'الاسم الكامل';

  @override
  String get or => 'أو';

  @override
  String pleaseEnter(Object field) {
    return 'الرجاء إدخال $field';
  }

  @override
  String get validEmail => 'الرجاء إدخال بريد إلكتروني صحيح';

  @override
  String get passwordLength => 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';

  @override
  String get settings => 'الإعدادات';

  @override
  String get language => 'اللغة';

  @override
  String get theme => 'المظهر';

  @override
  String get darkMode => 'الوضع الداكن';

  @override
  String get lightMode => 'الوضع الفاتح';

  @override
  String get profile => 'الملف الشخصي';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get home => 'الرئيسية';

  @override
  String get favorites => 'المفضلة';

  @override
  String get cart => 'السلة';

  @override
  String get welcome => 'مرحباً';

  @override
  String get search => 'ابحث عن الطعام...';

  @override
  String get chooseOnMap => 'اختر من الخريطة';

  @override
  String get chooseOnMapSubtitle => 'ضع المؤشّر في مكان التسليم بالضبط';

  @override
  String get categories => 'الفئات';

  @override
  String get popular => 'شائع';

  @override
  String get seeAll => 'عرض الكل';

  @override
  String get deliverTo => 'التوصيل إلى';

  @override
  String get currentLocation => 'الموقع الحالي';

  @override
  String get searchRestaurants => 'ابحث عن المطاعم...';

  @override
  String get popularRestaurants => 'المطاعم الشائعة';

  @override
  String get noFavoritesYet => 'لا توجد مفضلة بعد';

  @override
  String get myCart => 'عربة التسوق';

  @override
  String get clear => 'مسح';

  @override
  String get subtotal => 'المجموع الفرعي';

  @override
  String get deliveryFee => 'رسوم التوصيل';

  @override
  String get total => 'المجموع';

  @override
  String get proceedToCheckout => 'متابعة الدفع';

  @override
  String get clearCart => 'مسح العربة';

  @override
  String get clearCartConfirmation =>
      'هل أنت متأكد أنك تريد إزالة جميع العناصر من عربة التسوق؟';

  @override
  String get cancel => 'إلغاء';

  @override
  String get cartEmpty => 'عربة التسوق فارغة';

  @override
  String get addItemsToGetStarted => 'أضف عناصر للبدء';

  @override
  String get browseRestaurants => 'تصفح المطاعم';

  @override
  String get notifications => 'الإشعارات';

  @override
  String get markAllRead => 'تحديد الكل كمقروء';

  @override
  String get noNotifications => 'لا توجد إشعارات';

  @override
  String get notificationsWillAppearHere => 'ستظهر الإشعارات هنا';

  @override
  String get specialInstructions => 'تعليمات خاصة';

  @override
  String get typeMessage => 'كتابة';

  @override
  String get voiceMessage => 'رسالة صوتية';

  @override
  String get save => 'حفظ';

  @override
  String get typeInstructionsHint => 'مثال: بدون بصل، جبنة إضافية...';

  @override
  String get microphonePermissionDenied => 'تم رفض إذن الميكروفون';

  @override
  String get tapToRecord => 'اضغط للتسجيل';

  @override
  String get tapAgainToStop => 'اضغط مرة أخرى للإيقاف';

  @override
  String get addSpecialInstructions => 'إضافة تعليمات خاصة';

  @override
  String get customization => 'التخصيص';

  @override
  String get orderTracking => 'تتبع الطلب';

  @override
  String get activeOrder => 'طلب نشط';

  @override
  String get confirmReceipt => 'تأكيد الاستلام';

  @override
  String get orderMarkedDelivered => 'تم وضع علامة تم التسليم على الطلب!';

  @override
  String get errorLoadingOrder => 'خطأ في تحميل الطلب';

  @override
  String get errorLoadingRestaurants => 'خطأ في تحميل المطاعم';

  @override
  String get errorLoadingMenu => 'خطأ في تحميل القائمة';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get selectDeliveryAddress => 'اختر عنوان التسليم';

  @override
  String get deliveryAddress => 'عنوان التسليم';

  @override
  String get paymentMethod => 'طريقة الدفع';

  @override
  String get cashOnDelivery => 'الدفع عند الاستلام';

  @override
  String get payWhenYouReceive => 'ادفع عند الاستلام';

  @override
  String get payWithKonnect => 'الدفع عبر Konnect';

  @override
  String get secureOnlinePayment => 'دفع آمن عبر الإنترنت (تونس)';

  @override
  String get orderNotes => 'ملاحظات الطلب';

  @override
  String get specialDeliveryInstructions => 'أضف أي تعليمات خاصة للتوصيل...';

  @override
  String get orderSummary => 'ملخص الطلب';

  @override
  String get placeOrder => 'تأكيد الطلب';

  @override
  String get myOrders => 'طلباتي';

  @override
  String get noOrdersYet => 'لا توجد طلبات بعد';

  @override
  String get startOrderingMessage => 'سيظهر سجل طلباتك هنا';

  @override
  String get helpSupport => 'المساعدة والدعم';

  @override
  String get supportTicketSent => 'تم إرسال تذكرة الدعم! سنتصل بك قريباً.';

  @override
  String get savedAddresses => 'العناوين المحفوظة';

  @override
  String get noAddressesSaved => 'لا توجد عناوين محفوظة';

  @override
  String get addNewAddress => 'إضافة عنوان جديد';

  @override
  String get addressRemoved => 'تم حذف العنوان';

  @override
  String get setDefault => 'تعيين كافتراضي';

  @override
  String get noRestaurantsFound => 'لا توجد مطاعم';

  @override
  String get confirmPasswordShort => 'تأكيد كلمة المرور';

  @override
  String get pleaseEnterEmail => 'يرجى إدخال بريدك الإلكتروني';

  @override
  String get sendResetCode => 'إرسال الرمز';

  @override
  String get haveCodeEnterIt => 'لديك رمز بالفعل؟ أدخله ←';

  @override
  String get resetCodeInvalid =>
      'الرمز غير صالح أو انتهت صلاحيته. اطلب رمزًا جديدًا.';

  @override
  String get passwordUpdatedBody =>
      'تم تغيير كلمة المرور. سجّل الدخول بكلمة المرور الجديدة.';

  @override
  String get backToSignIn => 'العودة إلى تسجيل الدخول';

  @override
  String get enterResetCode => 'أدخل الرمز';

  @override
  String get pleaseEnterPassword => 'يرجى إدخال كلمة المرور';

  @override
  String get resetPasswordButton => 'إعادة تعيين كلمة المرور';

  @override
  String get eightDigitCode => 'رمز من 8 أرقام';

  @override
  String get enterEightDigitCode =>
      'أدخل الرمز المكوّن من 8 أرقام الذي وصلك عبر البريد';

  @override
  String get callUs => 'اتصل بنا';

  @override
  String get somethingWentWrong => 'حدث خطأ ما. يرجى المحاولة مرة أخرى.';

  @override
  String codeSentTo(String email) {
    return 'تم إرسال الرمز إلى $email';
  }

  @override
  String get filterAll => 'الكل';

  @override
  String get cuisinePastry => 'حلويات';

  @override
  String get cuisinePizza => 'بيتزا';

  @override
  String get cuisineBurgers => 'برغر';

  @override
  String get cuisineSushi => 'سوشي';

  @override
  String get cuisineMexican => 'مكسيكي';

  @override
  String get cuisineItalian => 'إيطالي';

  @override
  String get cuisineFastFood => 'وجبات سريعة';

  @override
  String get shopOpen => 'مفتوح';

  @override
  String get shopClosed => 'مغلق';

  @override
  String get newShopBadge => 'جديد';

  @override
  String get deliveryLabel => 'التوصيل';

  @override
  String get minOrderLabel => 'الحد الأدنى';

  @override
  String get deliveryTimeLabel => 'مدة التوصيل';

  @override
  String get couldNotLoadShops => 'تعذّر تحميل المتاجر';

  @override
  String get newShopsSoon => 'عد قريبًا — متاجر جديدة في الطريق.';

  @override
  String get today => 'اليوم';

  @override
  String get yesterday => 'أمس';

  @override
  String get timeJustNow => 'الآن';

  @override
  String reviewsCount(int count) {
    return '$count تقييم';
  }

  @override
  String timeMinutesAgo(int minutes) {
    return 'منذ $minutes د';
  }

  @override
  String timeHoursAgo(int hours) {
    return 'منذ $hours س';
  }

  @override
  String noRestaurantsNearby(int km) {
    return 'لا يوجد مطعم على بعد $km كم منك حاليًا.';
  }

  @override
  String noSupermarketsNearby(int km) {
    return 'لا يوجد سوبرماركت على بعد $km كم منك حاليًا.';
  }

  @override
  String get couldNotLoadSupermarkets => 'تعذر تحميل السوبر ماركت';

  @override
  String get couldNotGetLocation =>
      'تعذر تحديد موقعك الحالي. يرجى تفعيل خدمات الموقع.';

  @override
  String get account => 'الحساب';

  @override
  String get orderHistory => 'سجل الطلبات';

  @override
  String get editProfile => 'تعديل الملف الشخصي';

  @override
  String get user => 'المستخدم';

  @override
  String get viewDeals => 'عرض العروض';

  @override
  String get saveUpTo60 => 'وفّر حتى 60% على الطعام والبقالة!';

  @override
  String get happyHour => 'ساعة سعيدة';

  @override
  String get happyHourLive => 'مباشر';

  @override
  String get receiptQuestion => 'هل استلمت طلبك؟';

  @override
  String get receiptQuestionParcel => 'هل تم تسليم طردك؟';

  @override
  String get receiptYesParcel => 'نعم، تم التسليم';

  @override
  String get receiptNoParcel => 'لا، لم يُسلَّم';

  @override
  String get receiptNotDeliveredParcelLink => 'لم يتم تسليم طردي';

  @override
  String get receiptReportBodyParcel =>
      'سنبلغ فريق الدعم بأن هذا الطرد لم يُسلَّم.';

  @override
  String receiptAutoIn(String time) {
    return 'تأكيد تلقائي خلال $time';
  }

  @override
  String get receiptYes => 'نعم، استلمته';

  @override
  String get receiptNo => 'لا، لم أستلمه';

  @override
  String get receiptConfirmed => 'تم تأكيد الاستلام. شكراً!';

  @override
  String get receiptAutoConfirmed => 'تم تأكيد الاستلام تلقائياً';

  @override
  String get receiptNotReceivedLink => 'لم أستلم طلبي';

  @override
  String get receiptReportTitle => 'الإبلاغ عن مشكلة؟';

  @override
  String get receiptReportBody => 'سنبلغ فريق الدعم بأنك لم تستلم هذا الطلب.';

  @override
  String get receiptReportConfirm => 'إبلاغ';

  @override
  String get receiptReported => 'تم الإبلاغ. سيتواصل معك فريق الدعم.';

  @override
  String get receiptSaveFailed => 'تعذر حفظ إجابتك. حاول مرة أخرى.';

  @override
  String get receiptTapToConfirm => 'اضغط للتأكيد';

  @override
  String get rateDriverTitle => 'قيّم السائق';

  @override
  String get rateDriverButton => 'تقييم السائق';

  @override
  String get rateDriverHint => 'تعليق؟ (اختياري)';

  @override
  String get rateDriverSend => 'إرسال';

  @override
  String get rateDriverLater => 'لاحقاً';

  @override
  String get rateDriverThanks => 'شكراً على تقييمك!';

  @override
  String get rateDriverFailed => 'تعذر إرسال تقييمك حالياً.';

  @override
  String happyHourDealsSummary(int count, int percent) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عروض · حتى -$percent%',
      one: 'عرض واحد · حتى -$percent%',
    );
    return '$_temp0';
  }

  @override
  String happyHourEndsIn(String time) {
    return 'ينتهي خلال $time';
  }

  @override
  String get happyHourNoDealsNow => 'لا توجد عروض حالياً، عد قريباً';

  @override
  String happyHourUnitsLeft(int count) {
    return 'تبقى $count فقط!';
  }

  @override
  String get happyHourShopsTab => 'متاجر';

  @override
  String addedToCartWithQuantity(int quantity, String item) {
    return '$quantity × $item أُضيف إلى السلة';
  }

  @override
  String get chooseAnOption => 'اختر خياراً';

  @override
  String get errorLoadingItems => 'تعذّر تحميل المنتجات';

  @override
  String get supermarketClosedNow => 'هذا المتجر مغلق حالياً.';

  @override
  String get restaurantClosedLabel => 'المطعم مغلق';

  @override
  String get organic => 'عضوي';

  @override
  String get happyHourSubtitle => 'أفضل الأسعار على أطباقك المفضّلة';

  @override
  String get promos => 'عروض';

  @override
  String get promosSubtitle => 'خصومات في متاجرك المفضّلة';

  @override
  String get promosBannerCta => 'عرض العروض';

  @override
  String get happyHourGrab => 'احصل عليه';

  @override
  String addedToCart(String item) {
    return 'تمت إضافة $item إلى السلة';
  }

  @override
  String get happyHourLoadError => 'تعذّر تحميل العروض';

  @override
  String get viewCart => 'عرض السلة';

  @override
  String get cartFromAnotherShopTitle => 'سلة من متجر آخر';

  @override
  String get cartFromAnotherShopMessage =>
      'تحتوي سلتك على منتجات من متجر آخر. هل تريد إفراغها لإضافة هذا المنتج؟';

  @override
  String get emptyAndAdd => 'إفراغ وإضافة';

  @override
  String get newItemBadge => 'جديد';

  @override
  String get restaurants => 'المطاعم';

  @override
  String get supermarkets => 'متاجر البقالة';

  @override
  String get noDealsRightNow => 'لا توجد عروض حالياً. عُد لاحقاً!';

  @override
  String get confirmPickupRequest => 'تأكيد طلب الاستلام';

  @override
  String get amountToCollect => 'المبلغ المطلوب تحصيله:';

  @override
  String get confirmPickup => 'تأكيد الاستلام';

  @override
  String get pleaseSignInToContinue => 'يرجى تسجيل الدخول للمتابعة';

  @override
  String get billPayments => 'دفع الفواتير';

  @override
  String get internet => 'الإنترنت';

  @override
  String get electricity => 'الكهرباء';

  @override
  String get water => 'الماء';

  @override
  String get selectProvider => 'اختر المزود';

  @override
  String get noProvidersAvailable => 'لا يوجد مزودون متاحون لهذه الفئة بعد.';

  @override
  String get howMuchToPay => 'كم تريد أن تدفع؟';

  @override
  String get driverWillCollect => 'سيأتي السائق لتحصيل هذا المبلغ بالضبط منك.';

  @override
  String get amountDt => 'المبلغ (د.ت)';

  @override
  String get pleaseEnterAmount => 'يرجى إدخال المبلغ';

  @override
  String get pleaseEnterValidAmount => 'يرجى إدخال مبلغ صحيح';

  @override
  String get requestDriverForPickup => 'طلب سائق للاستلام';

  @override
  String get serviceFeeNote =>
      'الرسوم: ستتم إضافة 2.000 د.ت كرسوم خدمة من قبل السائق';

  @override
  String get pleaseSelectAddress => 'يرجى اختيار عنوان التسليم';

  @override
  String get pleaseEnterPhone =>
      'يرجى إدخال رقم هاتفك ليتمكن السائق من التواصل معك';

  @override
  String get checkout => 'إتمام الشراء';

  @override
  String get contactInfo => 'معلومات الاتصال';

  @override
  String get phoneHint => 'رقم الهاتف (مثال: +216 12 345 678)';

  @override
  String get fullNameHint => 'الاسم الكامل';

  @override
  String get selectAddress => 'اختر العنوان';

  @override
  String get useCurrentLocation => 'استخدم الموقع الحالي';

  @override
  String get gettingLocation => 'جارٍ تحديد الموقع...';

  @override
  String get enableLocationToDeliver => 'فعّل خدمة الموقع للتوصيل هنا';

  @override
  String get addNew => 'إضافة جديد';

  @override
  String get defaultLabel => 'افتراضي';

  @override
  String get couldNotGeocode =>
      'تعذر تحديد إحداثيات العنوان. يرجى التحقق من العنوان والمحاولة مرة أخرى.';

  @override
  String get labelHint => 'التسمية (مثال: المنزل، العمل)';

  @override
  String get fullAddressLabel => 'العنوان الكامل';

  @override
  String get apartment => 'الشقة';

  @override
  String get floor => 'الطابق';

  @override
  String get saveAddress => 'حفظ العنوان';

  @override
  String get pleaseSelectPickupDropoff => 'يرجى اختيار موقعي الاستلام والتسليم';

  @override
  String get recipientDetails => 'تفاصيل المستلم';

  @override
  String get friendsName => 'اسم الصديق';

  @override
  String get phoneNumber => 'رقم الهاتف';

  @override
  String get packageDetails => 'تفاصيل الطرد';

  @override
  String get whatAreYouSending => 'ماذا ترسل؟';

  @override
  String get locations => 'المواقع';

  @override
  String get pickupLocation => 'مكان الاستلام';

  @override
  String get dropoffLocation => 'موقع التسليم';

  @override
  String get requestCourier => 'طلب مرسال';

  @override
  String get recipientAccepted => 'لقد قبل المستلم الطرد';

  @override
  String get yourCourier => 'مرسالك';

  @override
  String get recipient => 'المستلم';

  @override
  String get phone => 'الهاتف';

  @override
  String get item => 'العنصر';

  @override
  String get driverPhoneNotAvailable => 'رقم هاتف السائق غير متاح بعد';

  @override
  String get unableToStartCall => 'تعذر بدء المكالمة الهاتفية';

  @override
  String get sendParcelTitle => 'إرسال طرد';

  @override
  String get sendParcelSubtitle => 'أرسل أي غرض من نقطة إلى أخرى';

  @override
  String get parcelSuccessTitle => 'طردك في الطريق!';

  @override
  String orderSuccessTrackingRef(String ref) {
    return 'الطلب رقم #$ref';
  }

  @override
  String get trackMyParcel => 'تتبع طردي';

  @override
  String get trackMyOrder => 'تتبع طلبي';

  @override
  String get backToHome => 'العودة إلى الرئيسية';

  @override
  String get foodHeroTitle => 'اطلب وجبة';

  @override
  String get supermarketHeroTitle => 'قم بتسوقك';

  @override
  String get factureHeroTitle => 'ادفع فاتورة';

  @override
  String get supermarketSuccessTitle => 'طلبك في الطريق!';

  @override
  String get factureSuccessTitle => 'تم تحصيل فاتورتك!';

  @override
  String get phoneNumberLabel => 'رقم الهاتف';

  @override
  String get bio => 'نبذة';

  @override
  String get subject => 'الموضوع';

  @override
  String get message => 'الرسالة';

  @override
  String get submitTicket => 'إرسال التذكرة';

  @override
  String get howCanWeHelp => 'كيف يمكننا مساعدتك؟';

  @override
  String get fillFormDescription =>
      'املأ النموذج أدناه وسيتواصل معك فريقنا خلال 24 ساعة.';

  @override
  String get failedToSendTicket => 'فشل إرسال التذكرة. يرجى المحاولة مرة أخرى.';

  @override
  String get removedFromFavorites => 'تمت الإزالة من المفضلة';

  @override
  String get addedToFavorites => 'تمت الإضافة إلى المفضلة';

  @override
  String get addressRemovedSuccess => 'تم حذف العنوان';

  @override
  String get pleaseEnterSubject => 'يرجى إدخال موضوع';

  @override
  String get pleaseEnterMessage => 'يرجى إدخال رسالتك';

  @override
  String get pleaseEnterName => 'يرجى إدخال اسمك';

  @override
  String get profileUpdated => 'تم تحديث الملف الشخصي بنجاح!';

  @override
  String get failedToUpdateProfile => 'فشل تحديث الملف الشخصي';

  @override
  String get saveChanges => 'حفظ التغييرات';

  @override
  String get addYourPhoneNumber => 'أضف رقم هاتفك';

  @override
  String get phoneRequiredExplain =>
      'نحتاج إلى رقم هاتفك حتى يتمكن السائقون من التواصل معك بخصوص التوصيلات. خطوة لمرة واحدة.';

  @override
  String get phoneInvalid => 'يرجى إدخال رقم هاتف تونسي صحيح من 8 أرقام';

  @override
  String get continueButton => 'متابعة';

  @override
  String get promoCode => 'رمز الخصم';

  @override
  String get promoCodePlaceholder => 'أدخل رمز الخصم';

  @override
  String get billTypeElectricity => 'STEG (الكهرباء)';

  @override
  String get billTypeWater => 'SONEDE (الماء)';

  @override
  String get billTypeInternet => 'Topnet (الإنترنت)';

  @override
  String get packageFallback => 'طرد';

  @override
  String get orderStatusPending => 'قيد الانتظار';

  @override
  String get orderStatusConfirmed => 'مؤكّدة';

  @override
  String get orderStatusPreparing => 'قيد التحضير';

  @override
  String get orderStatusReady => 'جاهزة';

  @override
  String get orderStatusPickedUp => 'تم الاستلام';

  @override
  String get orderStatusOnTheWay => 'في الطريق';

  @override
  String get orderStatusDelivered => 'تم التوصيل';

  @override
  String get orderStatusCancelled => 'ملغاة';

  @override
  String get timelineOrderConfirmed => 'تم تأكيد الطلب';

  @override
  String get timelinePreparing => 'قيد التحضير';

  @override
  String get timelineReady => 'جاهز';

  @override
  String get timelineOnTheWay => 'في الطريق';

  @override
  String get timelineDelivered => 'تم التوصيل';

  @override
  String get timelineRequestConfirmed => 'تم تأكيد الطلب';

  @override
  String get timelinePickedUp => 'تم استلام الطرد';

  @override
  String get timelineDriverComing => 'السائق في طريقه إليك';

  @override
  String get timelineCashCollected => 'تم استلام المبلغ';

  @override
  String get timelineBillPaid => 'تم دفع الفاتورة';

  @override
  String estimatedDeliveryAt(String time) {
    return 'التوصيل المتوقع: $time';
  }

  @override
  String get orderDetailsTitle => 'تفاصيل الطلب';

  @override
  String get billDetailsTitle => 'تفاصيل الفاتورة';

  @override
  String get deliveryLocation => 'مكان التوصيل';

  @override
  String get paymentOffice => 'مكتب الدفع';

  @override
  String get yourAddress => 'عنوانك';

  @override
  String get driverLabel => 'السائق';

  @override
  String get routeLabel => 'المسار';

  @override
  String get billTypeField => 'النوع';

  @override
  String get billReferenceField => 'المرجع';

  @override
  String get billAmountField => 'المبلغ';

  @override
  String get billPhotoLabel => 'صورة الفاتورة';

  @override
  String get paymentReceiptLabel => 'إيصال الدفع';

  @override
  String get paymentMethodCash => 'نقداً';

  @override
  String get cancelOrderTitle => 'إلغاء الطلب';

  @override
  String get cancelDriverAssigned =>
      'تم تعيين سائق لطلبك بالفعل. هل تريد الإلغاء رغم ذلك؟';

  @override
  String get cancelReasonLabel => 'سبب الإلغاء:';

  @override
  String get cancelReasonWrongOrder => 'خطأ في الطلب';

  @override
  String get cancelReasonTooLong => 'الانتظار طويل جداً';

  @override
  String get cancelReasonChangedMind => 'غيّرت رأيي';

  @override
  String get cancelReasonOther => 'سبب آخر';

  @override
  String get backAction => 'رجوع';

  @override
  String get confirmAction => 'تأكيد';

  @override
  String get orderCancelledOk => 'تم إلغاء الطلب.';

  @override
  String get cancelTooLatePreparing =>
      'لا يمكن الإلغاء — الطلب قيد التحضير بالفعل.';

  @override
  String get cancelTooLateOnTheWay =>
      'الطلب في الطريق بالفعل. تواصل مع الدعم للإلغاء.';

  @override
  String placeOrderWithTotal(String total) {
    return 'اطلب — $total';
  }

  @override
  String get venueClosedNow =>
      'هذا المتجر مغلق حالياً ولا يمكنه استقبال الطلبات.';

  @override
  String get paymentFailedOrderCancelled => 'فشل الدفع. تم إلغاء الطلب.';

  @override
  String get loyaltyFreeDelivery => 'الولاء — توصيل مجاني';

  @override
  String get loyaltyHalfDelivery => 'الولاء — خصم 50% على التوصيل';

  @override
  String genericErrorWith(String message) {
    return 'خطأ: $message';
  }

  @override
  String promoOnEligible(String discount, String eligible) {
    return '− $discount من أصل $eligible مؤهّلة';
  }

  @override
  String get promoErrorNotFound => 'هذا الرمز غير موجود';

  @override
  String get promoErrorInactive => 'هذا الرمز لم يعد فعّالاً';

  @override
  String get promoErrorExpired => 'انتهت صلاحية هذا الرمز أو لم تبدأ بعد';

  @override
  String get promoErrorMaxUses => 'هذا الرمز لم يعد متاحاً';

  @override
  String get promoErrorAlreadyUsed => 'لقد استخدمت هذا الرمز من قبل';

  @override
  String get promoErrorMinOrder => 'طلبك أقل من الحد الأدنى لهذا الرمز';

  @override
  String promoErrorMinOrderAmount(String amount) {
    return 'يتطلب هذا الرمز طلباً بقيمة $amount على الأقل';
  }

  @override
  String get promoErrorAllOnPromo =>
      'منتجاتك عليها خصم بالفعل، لذلك لا ينطبق هذا الرمز';

  @override
  String get promoErrorNotFirstOrder => 'هذا الرمز مخصّص لطلبك الأول فقط';

  @override
  String get promoErrorEmptyCart => 'سلتك فارغة';

  @override
  String get promoErrorNotLoggedIn => 'سجّل الدخول لاستخدام رمز ترويجي';

  @override
  String get promoErrorNetwork => 'خطأ في الشبكة. حاول مجدداً.';

  @override
  String get promoErrorGeneric => 'رمز غير صالح أو منتهٍ';

  @override
  String get applyPromoCode => 'تطبيق';

  @override
  String get removePromoCode => 'إزالة';

  @override
  String get promoApplied => 'تم تطبيق الخصم!';

  @override
  String promoDiscount(String code) {
    return 'خصم ($code)';
  }

  @override
  String get loyaltyCardTitle => 'بطاقة الولاء';

  @override
  String get loyaltyPendingSubtitle =>
      'الختم قيد الانتظار — يُؤكَّد عند التسليم';

  @override
  String get loyaltyProgressLabel => 'تقدمك';

  @override
  String loyaltyRemainingHalf(int count) {
    return '$count طلبات أخرى للحصول على توصيل بنصف السعر';
  }

  @override
  String loyaltyRemainingFree(int count) {
    return '$count طلبات أخرى للحصول على توصيل مجاني';
  }

  @override
  String get loyaltyCelebrationHalf => 'هذا طلبك الخامس — توصيلك بنصف السعر!';

  @override
  String get loyaltyCelebrationFree => 'الطلب العاشر — توصيلك مجاني!';

  @override
  String get loyaltyViewRewards => 'عرض مكافآتي';

  @override
  String get loyaltyCancelTitle => 'تم إلغاء الطلب';

  @override
  String get loyaltyCancelMessage =>
      'تم! نأمل أن نراك مجددًا قريبًا. شكرًا لثقتك!';

  @override
  String get loyaltyCancelNote => 'تمت إزالة ختم هذا الطلب من بطاقتك.';

  @override
  String get loyaltyCancelPrimaryCta => 'اطلب مجددًا';

  @override
  String get loyaltyCancelSecondaryCta => 'إغلاق';

  @override
  String get loyaltyRewardsTitle => 'مكافآتي';

  @override
  String get loyaltyMilestoneHalfTitle => 'الطلب الخامس';

  @override
  String get loyaltyMilestoneHalfSubtitle => 'توصيل بنصف السعر';

  @override
  String get loyaltyMilestoneFreeTitle => 'الطلب العاشر';

  @override
  String get loyaltyMilestoneFreeSubtitle => 'توصيل مجاني';

  @override
  String get loyaltyStateAchieved => 'تم تحقيقه';

  @override
  String get loyaltyStateCurrent => 'قيد التقدم';

  @override
  String get loyaltyStateLocked => 'مقفل';

  @override
  String get loyaltyHowItWorksTitle => 'كيف يعمل البرنامج';

  @override
  String get loyaltyHowItWorks1 => 'كل طلب يُسلَّم = ختم واحد';

  @override
  String get loyaltyHowItWorks2 =>
      'تُطبَّق الخصومات تلقائيًا على رسوم توصيل الطلب الذي يصل إلى الحد المطلوب';

  @override
  String get loyaltyHowItWorks3 => 'الطلبات الملغاة لا تُحتسب';

  @override
  String get loyaltyHowItWorks4 =>
      'بعد الطلب العاشر، تُعاد تهيئة البطاقة ويبدأ دورة جديدة';

  @override
  String get optionGroupRequired => 'إلزامي';

  @override
  String get optionGroupOptional => 'اختياري';

  @override
  String optionGroupSelectExact(int count) {
    return 'اختر $count';
  }

  @override
  String optionGroupSelectUpTo(int max) {
    return 'اختر حتى $max';
  }

  @override
  String optionGroupSelectRange(int min, int max) {
    return 'اختر من $min إلى $max';
  }

  @override
  String addToCartWithTotal(String total) {
    return 'أضف إلى السلة · $total';
  }

  @override
  String get completeRequiredSelections => 'يرجى إكمال الاختيارات الإلزامية';

  @override
  String get variantGroupTitle => 'اختر خيارًا';

  @override
  String get aiSearchTitle => 'البحث بالذكاء الاصطناعي';

  @override
  String get aiSearchPlaceholder => 'صِف ما تبحث عنه...';

  @override
  String get aiSearchCameraTooltip => 'البحث بالصورة';

  @override
  String get aiSearchVisualSearchBadge => 'البحث البصري';

  @override
  String aiSearchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم العثور على $count نتيجة',
      many: 'تم العثور على $count نتيجة',
      few: 'تم العثور على $count نتائج',
      two: 'تم العثور على نتيجتين',
      one: 'تم العثور على نتيجة واحدة',
      zero: 'لم يتم العثور على نتائج',
    );
    return '$_temp0';
  }

  @override
  String get aiSearchLoadingPhoto => 'جاري تحليل صورتك…';

  @override
  String get aiSearchLoadingText => 'جاري فهم طلبك…';

  @override
  String get aiSearchPoweredBy => 'مدعوم بالذكاء الاصطناعي';

  @override
  String get aiSearchEmptyTitle => 'صِف ما تريد';

  @override
  String get aiSearchEmptyDescription =>
      'اكتب باللهجة الدارجة أو الفرنسية أو العربية — أو احمل صورة للطبق الذي تبحث عنه.';

  @override
  String get aiSearchExampleQuery1 => 'نحب شاباتي وما تفوتش 10 دينار';

  @override
  String get aiSearchExampleQuery2 => 'بيتزا رخيصة';

  @override
  String get aiSearchExampleQuery3 => 'ملفوف بأقل من 12 دينار';

  @override
  String get aiSearchExampleQueryPhoto => 'احمل صورة طبق';

  @override
  String aiSearchNoResultsPhoto(String dishName) {
    return 'لم يتم العثور على مطاعم تقدم « $dishName »';
  }

  @override
  String get aiSearchNoResultsText => 'لا توجد أطباق تطابق طلبك';

  @override
  String get aiSearchFallbackMessage =>
      'لا توجد نتائج مطابقة — إليك بعض الأطباق الشائعة';

  @override
  String get aiSearchModalTitle => 'البحث بالصورة';

  @override
  String aiSearchModalHint(String city) {
    return 'احمل صورة طبق للعثور عليه في $city';
  }

  @override
  String get aiSearchCameraLabel => 'الكاميرا';

  @override
  String get aiSearchGalleryLabel => 'المعرض';

  @override
  String get aiSearchTryAgain => 'المحاولة مرة أخرى';

  @override
  String get aiSearchErrorCouldNotOpen => 'تعذر فتح الصورة';

  @override
  String aiSearchIdentified(String dishName, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مطعم',
      many: '$count مطعمًا',
      few: '$count مطاعم',
      two: 'مطعمان',
      one: 'مطعم واحد',
      zero: 'لا توجد مطاعم',
    );
    return 'تم التعرف: « $dishName » · $_temp0';
  }

  @override
  String get city => 'تونس';

  @override
  String get colisHandoverSectionTitle => 'كيف يسلّم السائق طردك؟';

  @override
  String get colisModeRecommended => 'موصى به';

  @override
  String get colisModeCodeTitle => 'مع رمز';

  @override
  String get colisModeCodeSubtitle =>
      'الأكثر أماناً لك. تتلقّى رمزاً من 4 أرقام. أرسله إلى الشخص الذي يستلم الطرد. عند الوصول، يعطي هذا الرمز للسائق. بدون الرمز الصحيح، لا يمكن للسائق إتمام التسليم. هكذا تكون واثقاً أن طردك يصل إلى الشخص الصحيح.';

  @override
  String get colisModeNoCodeTitle => 'التسليم بدون رمز';

  @override
  String get colisModeNoCodeSubtitle =>
      'إذا لم يكن للشخص هاتف (طفل في المدرسة، حارس…). يأخذ السائق صورة لحظة التسليم، مع موقعه. هذا أقل أماناً من التسليم برمز.';

  @override
  String colisCodeHeadline(String code) {
    return 'رمز التسليم متاعك: $code';
  }

  @override
  String get colisCodeExplain =>
      'أرسل هذا الرمز إلى المستلم. سيعطيه للسائق عند استلام الطرد.';

  @override
  String colisShareMessage(String code) {
    return 'مرحباً، طرد أمانة في الطريق إليك. أعط هذا الرمز للسائق عند الاستلام: $code';
  }

  @override
  String get colisShareSubject => 'رمز التسليم أمانة';

  @override
  String get mapGpsUnavailable => 'تعذّر الحصول على موقع GPS';

  @override
  String get mapUseCurrentLocation => 'استخدام موقعي الحالي';

  @override
  String get mapOr => 'أو';

  @override
  String get mapSearchHint => 'ابحث عن عنوان أو مكان…';

  @override
  String get mapTypeStreetHint => 'اكتب اسم شارع أو حي أو مكان…';

  @override
  String get mapNoResults => 'لا توجد نتائج';

  @override
  String get mapLocating => 'جارٍ تحديد الموقع…';

  @override
  String get mapLocatingInProgress => 'جارٍ تحديد موقعك…';

  @override
  String get mapDragToAdjust => 'اسحب لضبط الموقع';

  @override
  String get mapDragToPlace => 'اسحب الخريطة إلى المكان المطلوب';

  @override
  String get mapConfirmLocation => 'تأكيد هذا الموقع';

  @override
  String get authErrorInvalidCredentials =>
      'البريد الإلكتروني أو كلمة المرور غير صحيحة';

  @override
  String get authErrorAccountExists =>
      'يوجد حساب بهذا البريد الإلكتروني بالفعل';

  @override
  String get authErrorEmailNotConfirmed =>
      'يرجى تأكيد بريدك الإلكتروني قبل تسجيل الدخول';

  @override
  String get authErrorNoInternet => 'مشكلة في الاتصال بالإنترنت';

  @override
  String get authErrorTimeout =>
      'الخادم يستغرق وقتاً طويلاً للرد. حاول مرة أخرى.';

  @override
  String get authErrorServiceUnavailable =>
      'الخدمة غير متاحة مؤقتاً. حاول مرة أخرى بعد قليل.';

  @override
  String get authErrorGeneric => 'حدث خطأ، يرجى المحاولة مرة أخرى';

  @override
  String get authCheckFormFields => 'تحقّق من حقول النموذج';

  @override
  String get authAccountCreatedConfirmEmail =>
      'تم إنشاء الحساب! افتح رسالة التأكيد التي أرسلناها للتو، ثم سجّل الدخول.';

  @override
  String get billsTitle => 'فواتيري';

  @override
  String get billsLoadError => 'تعذّر تحميل الفواتير';

  @override
  String get billsEmptyTitle => 'لا توجد فواتير مدفوعة';

  @override
  String get billsEmptySubtitle => 'ستظهر مدفوعات فواتيرك هنا';

  @override
  String billsReference(String reference) {
    return 'المرجع: $reference';
  }

  @override
  String get billsReceiptAvailable => 'الإيصال متوفّر';

  @override
  String get billsLabelSteg => 'STEG — الكهرباء';

  @override
  String get billsLabelSonede => 'SONEDE — الماء';

  @override
  String get billsLabelTopnet => 'Topnet — الإنترنت';

  @override
  String get billsLabelOther => 'فاتورة أخرى';

  @override
  String get billStatusPaid => 'مدفوعة';

  @override
  String get billStatusInProgress => 'قيد التنفيذ';

  @override
  String get commonDelete => 'حذف';

  @override
  String get commonInvalidAmount => 'مبلغ غير صالح';

  @override
  String get commonInvalidPhone8 =>
      'رقم غير صالح — يجب أن يتكوّن من 8 أرقام بالضبط';

  @override
  String get photoTakePicture => 'التقاط صورة';

  @override
  String get photoChooseFromGallery => 'اختيار من المعرض';

  @override
  String get courierDeleteRecipientTitle => 'حذف هذا المستلم؟';

  @override
  String courierDeleteRecipientBody(String name) {
    return 'ستتم إزالة $name من جهات الاتصال المحفوظة.';
  }

  @override
  String get courierPickupAddress => 'عنوان الاستلام';

  @override
  String get courierConfirmNoForbidden =>
      'أكّد أن طردك لا يحتوي على أي مادة ممنوعة.';

  @override
  String get courierAcceptPhotoProof =>
      'وافق على أن تكون الصورة والموقع بمثابة دليل.';

  @override
  String get courierDeclaredValueRequired => 'أدخل قيمة طردك';

  @override
  String get courierDeclaredValuePositive => 'يجب أن تكون القيمة أكبر من 0';

  @override
  String courierDeclaredValueMax(String max) {
    return 'الحد الأقصى $max TND — قسّم شحنتك';
  }

  @override
  String get courierDescriptionRequired => 'صِف محتوى طردك';

  @override
  String get courierReceiverLabelRequired => 'حدّد لمن سيُسلَّم الطرد';

  @override
  String get courierSenderPhone => 'هاتف المُرسِل';

  @override
  String get courierSenderPhoneHint => 'الشخص الذي يسلّم الطرد';

  @override
  String get courierSenderPhoneRequired => 'إلزامي — رقم المُرسِل';

  @override
  String get courierRecipientName => 'اسم المستلم';

  @override
  String get courierRecipientNameHint =>
      'اختياري — يساعد السائق على التعرّف على المستلم';

  @override
  String get courierRecipientNameExample => 'مثال: محمد بن علي';

  @override
  String get courierRecipientPhone => 'هاتف المستلم';

  @override
  String get courierRecipientPhoneHint => 'الشخص الذي يستلم الطرد';

  @override
  String get courierRecipientPhoneRequired => 'إلزامي — رقم المستلم';

  @override
  String get courierContentsTitle => 'ماذا يحتوي طردك؟';

  @override
  String get courierContentsExample => 'مثال: هاتف Samsung A15، وثائق، ملابس…';

  @override
  String get courierDeclaredValue => 'القيمة المصرّح بها';

  @override
  String courierDeclaredValueCap(String max) {
    return 'الحد الأقصى: $max TND. فوق ذلك، قسّم شحنتك إلى عدة طرود.';
  }

  @override
  String get courierDeclaredValueHint => 'القيمة بالدينار (TND)';

  @override
  String get courierPhotoTitle => 'صورة الطرد';

  @override
  String get courierPhotoHint => 'اختياري — يساعد السائق على التعرّف على طردك';

  @override
  String get courierSizeTitle => 'حجم الطرد';

  @override
  String get courierConfirmSend => 'تأكيد الإرسال';

  @override
  String get courierTapToSelect => 'اضغط للاختيار';

  @override
  String get courierPhoneExample => 'مثال: 20123456';

  @override
  String get courierEstimatedPrice => 'السعر التقديري';

  @override
  String get courierEstimatedPriceLoyaltyFree =>
      'السعر التقديري — الولاء: توصيل مجاني';

  @override
  String get courierEstimatedPriceLoyaltyHalf =>
      'السعر التقديري — الولاء: -50%';

  @override
  String get courierPriceBase => '3.500 TND أساسي';

  @override
  String get courierReceiverLabelExample =>
      'مثال: حارس المدرسة، جار الطابق الثالث…';

  @override
  String get courierAcceptPhotoProofCheckbox =>
      'أوافق على أن يكون دليل التسليم هو صورة السائق وموقعه.';

  @override
  String get courierForbiddenTitle => 'ممنوع في الطرد';

  @override
  String get courierForbiddenConfirm =>
      'أؤكّد أن طردي لا يحتوي على أي من هذه المواد';

  @override
  String get courierPhotoChange => 'تغيير';

  @override
  String get courierPhotoAdd => 'إضافة صورة للطرد';

  @override
  String get courierPhotoTapHint => 'اضغط لالتقاط/اختيار صورة';

  @override
  String get courierSizeSmall => 'صغير';

  @override
  String get courierSizeMedium => 'متوسط';

  @override
  String get courierSizeLarge => 'كبير';

  @override
  String get courierSizeSmallDesc => 'وثائق، أغراض صغيرة';

  @override
  String get courierSizeMediumDesc => 'ملابس، إكسسوارات';

  @override
  String get courierSizeLargeDesc => 'أمتعة، طرود كبيرة';

  @override
  String get courierSaveRecipient => 'حفظ هذا المستلم للمرة القادمة';

  @override
  String get courierSavedRecipients => 'المستلمون المحفوظون';

  @override
  String get factureSelectBillType => 'يرجى اختيار نوع الفاتورة';

  @override
  String get factureEnterPickupAddress => 'يرجى تحديد عنوان الاستلام';

  @override
  String get factureEnterOfficeAddress => 'يرجى تحديد عنوان المكتب';

  @override
  String get factureNotSignedIn => 'غير مسجّل الدخول';

  @override
  String get factureReferenceRequired => 'إلزامي — الرقم المرجعي';

  @override
  String get factureAmountRequired => 'إلزامي — مبلغ الفاتورة';

  @override
  String get facturePhoneRequired => 'إلزامي — رقم الهاتف';

  @override
  String get factureBillTypeTitle => 'نوع الفاتورة';

  @override
  String get factureReferenceLabel => 'الرقم المرجعي / رقم العقد';

  @override
  String get factureAmountLabel => 'المبلغ المطلوب دفعه (TND)';

  @override
  String get factureCustomerAddressTitle => 'عنوانك (استلام المبلغ نقداً)';

  @override
  String get factureChooseYourAddress => 'اختر عنوانك';

  @override
  String factureOfficeAddressTitle(String billType) {
    return 'عنوان المكتب $billType';
  }

  @override
  String get factureChooseOfficeAddress => 'اختر عنوان المكتب';

  @override
  String get facturePhoneTitle => 'رقم هاتفك';

  @override
  String get facturePhoneLabel => 'الهاتف (8 أرقام)';

  @override
  String get factureAddBillPhoto => 'إضافة صورة الفاتورة (اختياري)';

  @override
  String get factureRemovePhoto => 'حذف الصورة';

  @override
  String get factureBillAmount => 'مبلغ الفاتورة';

  @override
  String get factureCollectedInCash => '(يُحصَّل نقداً)';

  @override
  String get factureServiceFee => 'رسوم الخدمة';

  @override
  String get factureLoyaltyHalf => 'الولاء — -50%';

  @override
  String get factureSendRequest => 'إرسال الطلب';

  @override
  String get colisDisputeExplain =>
      'صِف ما حدث. سيراجع أحد المسؤولين الأدلة (الصور، الوقت، الموقع) قبل اتخاذ القرار.';

  @override
  String get colisDisputeMessageHint => 'رسالتك (اختياري)';

  @override
  String get colisDisputeSendFailed => 'تعذّر إرسال البلاغ.';

  @override
  String get colisReceiptTitle => 'وصل الاستلام';

  @override
  String get colisReceiptDeclaredContents => 'المحتوى المصرّح به';

  @override
  String get colisReceiptHandedTo => 'سُلِّم إلى';

  @override
  String get colisReceiptPlate => 'اللوحة';

  @override
  String get colisReceiptDistanceToAddress => 'المسافة إلى العنوان';

  @override
  String get colisProofPickup => 'الاستلام';

  @override
  String get colisProofDelivery => 'التسليم';

  @override
  String get colisDisputeSent => 'تم إرسال البلاغ. سيراجعه أحد المسؤولين.';

  @override
  String get colisDisputeWindow =>
      'هل هناك مشكلة؟ لديك 24 ساعة بعد التسليم للإبلاغ عنها.';

  @override
  String get colisDisputeNotReceivedTitle => 'لم يتم استلام الطرد';

  @override
  String get colisDisputeNotReceived => 'لم يُستلَم';

  @override
  String get colisDisputeProblem => 'مشكلة في الطرد';

  @override
  String get colisCodeCopy => 'نسخ';

  @override
  String get colisCodeCopied => 'تم نسخ الرمز';

  @override
  String get colisCodeShare => 'مشاركة';

  @override
  String get loyaltyAppliedFree =>
      '🎉 تم تطبيق التوصيل المجاني — شكراً على وفائك!';

  @override
  String get loyaltyAppliedHalf =>
      '🎉 تم تطبيق خصم 50% على التوصيل — شكراً على وفائك!';

  @override
  String loyaltyProgressOrders(String progress) {
    return '$progress/5 طلبات قبل خصمك القادم';
  }

  @override
  String get loyaltyBadgeFree => '🎉 توصيل مجاني';

  @override
  String get loyaltyBadgeHalf => '🎉 خصم 50% على التوصيل';

  @override
  String get reorderButton => 'اطلب مرة أخرى';

  @override
  String get reorderReplaceCartTitle => 'استبدال السلة؟';

  @override
  String get reorderReplaceCartBody =>
      'سلتك الحالية تحتوي على منتجات. هل تريد استبدالها بمنتجات هذا الطلب؟';

  @override
  String get reorderReplace => 'استبدال';

  @override
  String get reorderNothingAvailable => 'لا يتوفر حالياً أي منتج من هذا الطلب.';

  @override
  String reorderSkipped(String count) {
    return 'تم تجاهل $count منتج(ات) غير متوفر(ة).';
  }

  @override
  String get reorderFailed => 'حدث خطأ أثناء إعادة الطلب. حاول مرة أخرى.';

  @override
  String get orderTypeFacture => 'دفع فاتورة';

  @override
  String get orderShopSupermarket => 'سوبرماركت';

  @override
  String get orderShopBakery => 'مخبزة';

  @override
  String get orderShopFlowers => 'زهور';

  @override
  String get orderShopPets => 'متجر الحيوانات';

  @override
  String get orderShopGifts => 'هدايا';

  @override
  String get orderShopElectronics => 'إلكترونيات';

  @override
  String get orderShopRestaurant => 'مطعم';

  @override
  String get homeEmptyBakery => 'لا توجد مخبزة متاحة بالقرب منك.';

  @override
  String get homeEmptyFlowers => 'لا يوجد بائع زهور متاح بالقرب منك.';

  @override
  String get homeEmptyPets => 'لا يوجد متجر حيوانات متاح بالقرب منك.';

  @override
  String get homeEmptyGifts => 'لا يوجد متجر هدايا بالقرب منك.';

  @override
  String get homeEmptyElectronics => 'لا يوجد متجر إلكترونيات بالقرب منك.';

  @override
  String get homeEmptyShops => 'لا يوجد متجر متاح بالقرب منك.';

  @override
  String get profileUploadFailed => 'فشل التحميل. يرجى المحاولة مرة أخرى.';

  @override
  String get profileBillReminders => 'تذكيرات الفواتير';

  @override
  String get ratingOrderQuestion => 'كيف كان طلبك؟';

  @override
  String get vendorCatalogueLoadError => 'تعذّر تحميل الكتالوج';

  @override
  String get vendorNoItemsYet => 'لا توجد منتجات حالياً.';

  @override
  String get vendorDefaultSection => 'المنتجات';

  @override
  String get vendorClosedNotice => 'هذا المتجر مغلق حالياً.';

  @override
  String get forgotPasswordIntro =>
      'أدخل بريدك الإلكتروني وسنرسل لك\nرمز إعادة تعيين من 6 أرقام.';

  @override
  String voiceRecordStartFailed(String error) {
    return 'تعذّر بدء التسجيل: $error';
  }

  @override
  String voiceRecordStopFailed(String error) {
    return 'تعذّر إيقاف التسجيل: $error';
  }

  @override
  String voicePlayFailed(String error) {
    return 'تعذّر تشغيل الصوت: $error';
  }

  @override
  String get addressLabelRequired => 'يرجى إدخال اسم للعنوان';

  @override
  String get addressRequired => 'يرجى إدخال عنوان';

  @override
  String addressAptFloor(String apartment, String floor) {
    return 'شقة: $apartment، طابق: $floor';
  }

  @override
  String get aiChatTooltip => 'المساعد الذكي';

  @override
  String get ordersLoadError => 'تعذّر تحميل الطلبات';

  @override
  String get orderTypeCourier => 'إرسال طرد';

  @override
  String etaMinutes(String minutes) {
    return '$minutes دقيقة';
  }

  @override
  String get helpEmailUs => 'راسلنا عبر البريد';

  @override
  String get quantity => 'الكمية';

  @override
  String restaurantShareText(
      String name, String description, String rating, String minutes) {
    return 'اكتشف $name!\n$description\nالتقييم: $rating ⭐\nالتوصيل: $minutes دقيقة';
  }

  @override
  String get aiChipSpicy => '🌶 حار';

  @override
  String get aiChipVegetarian => '🥦 نباتي';

  @override
  String get aiChipFast => '⚡ سريع';

  @override
  String get aiBadgeVeg => '🥦 نباتي';

  @override
  String get aiThisDish => 'هذا الطبق';

  @override
  String get aiSearchErrorNetwork => 'خطأ في الشبكة. تحقّق من اتصالك.';

  @override
  String get aiSearchErrorUnavailable =>
      'الخدمة غير متاحة مؤقتًا. حاول مرة أخرى لاحقًا.';

  @override
  String get aiSearchErrorNoDish =>
      'تعذّر التعرّف على طبق في هذه الصورة. جرّب صورة أوضح.';

  @override
  String aiSearchErrorImageTooLarge(String size) {
    return 'الصورة كبيرة جدًا ($size ميغابايت). استخدم صورة أصغر من 10 ميغابايت.';
  }

  @override
  String get aiSearchErrorUnknown => 'خطأ غير معروف';

  @override
  String get deleteAccount => 'حذف حسابي';

  @override
  String get deleteAccountIntro =>
      'الحذف نهائي. لن تتمكن بعد ذلك من تسجيل الدخول بهذا الحساب.';

  @override
  String get deleteAccountDeletedTitle => 'ما سيتم حذفه';

  @override
  String get deleteAccountDeletedDevices => 'إشعاراتك والأجهزة المتصلة';

  @override
  String get deleteAccountKeptTitle => 'ما سيتم الاحتفاظ به';

  @override
  String get deleteAccountKeptWhy =>
      'يتم الاحتفاظ بهذه المعلومات لأغراض المحاسبة وفي حال وجود نزاع.';

  @override
  String get deleteAccountBlockedTitle => 'لا يمكن حذف حسابك بعد';

  @override
  String get deleteAccountContactTeam => 'تواصل مع فريق أمانة';

  @override
  String get deleteAccountBlockerAdmin =>
      'هذا حساب مسؤول: لا يمكن حذفه من التطبيق.';

  @override
  String deleteAccountBlockerActiveOrders(int count) {
    return 'لديك $count طلب(ات) قيد التنفيذ. انتظر حتى يتم توصيلها أو إلغاؤها.';
  }

  @override
  String get deleteAccountBlockerOpenDisputes =>
      'يوجد نزاع طرد مفتوح. انتظر حتى يغلقه فريق أمانة.';

  @override
  String deleteAccountBlockerDriverOrders(int count) {
    return 'لديك $count توصيل(ات) قيد التنفيذ. أكملها أولاً.';
  }

  @override
  String get deleteAccountBlockerDriverDisputes =>
      'يوجد نزاع طرد يخصك لا يزال مفتوحاً. انتظر حتى يغلقه فريق أمانة.';

  @override
  String get deleteAccountBlockerDriverPayouts =>
      'لا تزال أمانة مدينة لك بمكافآت. تواصل مع فريق أمانة لتسوية حسابك.';

  @override
  String deleteAccountBlockerShopOrders(int count) {
    return 'لدى متجرك $count طلب(ات) قيد التنفيذ. أكملها أو ألغها أولاً.';
  }

  @override
  String deleteAccountBlockerWallet(String amount) {
    return 'يتبقى $amount دينار في رصيدك. تواصل مع فريق أمانة لتسوية حسابك.';
  }

  @override
  String get deleteAccountBlockerSettlements =>
      'هناك تسوية معلقة. تواصل مع فريق أمانة لتسوية حسابك.';

  @override
  String get deleteAccountBlockerUnknown =>
      'لا يمكن حذف حسابك حالياً. تواصل مع فريق أمانة.';

  @override
  String get deleteAccountConfirmWord => 'حذف';

  @override
  String deleteAccountTypeWord(String word) {
    return 'للتأكيد، اكتب $word';
  }

  @override
  String deleteAccountWordMismatch(String word) {
    return 'اكتب $word بالضبط';
  }

  @override
  String get deleteAccountPasswordHint => 'لأمانك، أدخل كلمة المرور';

  @override
  String get deleteAccountPasswordLabel => 'كلمة المرور';

  @override
  String get deleteAccountGoogleHint =>
      'لأمانك، ستعيد تسجيل الدخول بحساب Google المرتبط بهذا الحساب.';

  @override
  String get deleteAccountSubmit => 'حذف حسابي نهائياً';

  @override
  String get deleteAccountErrorWrongPassword => 'كلمة المرور غير صحيحة.';

  @override
  String get deleteAccountErrorOtherGoogle =>
      'حساب Google هذا ليس المرتبط بحساب أمانة هذا.';

  @override
  String get deleteAccountErrorReauth => 'انتهت صلاحية التأكيد. حاول مرة أخرى.';

  @override
  String get deleteAccountErrorNoMethod =>
      'لا يمكن تأكيد هذا الحساب في التطبيق. تواصل مع فريق أمانة.';

  @override
  String get deleteAccountErrorFailed =>
      'فشل الحذف. حاول مرة أخرى أو تواصل مع فريق أمانة.';

  @override
  String get deleteAccountLoadError => 'تعذر التحقق من حسابك. تحقق من اتصالك.';

  @override
  String get deleteAccountRetry => 'إعادة المحاولة';

  @override
  String get deleteAccountDoneTitle => 'تم حذف الحساب';

  @override
  String get deleteAccountDoneOk => 'حسناً';

  @override
  String get deleteAccountDeletedContact =>
      'بياناتك الشخصية: الاسم والهاتف والبريد الإلكتروني والصورة';

  @override
  String get deleteAccountDeletedAddresses => 'عناوينك والمستلمون المحفوظون';

  @override
  String get deleteAccountDeletedPayment => 'بطاقات الدفع المحفوظة';

  @override
  String get deleteAccountDeletedChat => 'سجل محادثاتك مع مساعد أمانة';

  @override
  String get deleteAccountKeptOrders =>
      'طلباتك لأغراض المحاسبة: التواريخ والحالة والمنتجات والمبالغ والرسوم والمدفوعات، دون أي معلومة تدل عليك';

  @override
  String get deleteAccountKeptColis =>
      'إثبات تسليم طرودك (الصور وموقع GPS ولوحة السائق وهويته) لمدة 30 يوماً بعد آخر طلب لك، ثم يُحذف';

  @override
  String get deleteAccountAppleHint => 'لأمانك، ستعيد تسجيل الدخول عبر Apple.';

  @override
  String get deleteAccountDoneBody => 'تم حذف حسابك. شكراً لاستخدامك أمانة.';

  @override
  String get deleteAccountDeletedOrderDetails =>
      'في طلباتك السابقة: العناوين ومواقع GPS وأرقام الهواتف والأسماء والملاحظات والرسائل الصوتية وصور الفواتير، بما في ذلك اسم وهاتف مستلمي طرودك';

  @override
  String get cannotOpenContactApp =>
      'تعذّر فتح التطبيق. اتصل بنا على الرقم +216 24 697 855.';

  @override
  String get privacyPolicy => 'سياسة الخصوصية';

  @override
  String get privacyPolicyOpenFailed => 'تعذّر فتح الصفحة. تحقّق من اتصالك.';
}
