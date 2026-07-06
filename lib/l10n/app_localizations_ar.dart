// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

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
  String get noPaymentMethods => 'لا توجد طرق دفع محفوظة';

  @override
  String get addNewCard => 'إضافة بطاقة جديدة';

  @override
  String get noRestaurantsFound => 'لا توجد مطاعم';

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
  String get paymentMethods => 'طرق الدفع';

  @override
  String get user => 'المستخدم';

  @override
  String get viewDeals => 'عرض العروض';

  @override
  String get saveUpTo60 => 'وفّر حتى 60% على الطعام والبقالة!';

  @override
  String get happyHour => 'ساعة سعيدة';

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
  String get pickupLocation => 'موقع الاستلام';

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
  String get cardholderName => 'اسم حامل البطاقة';

  @override
  String get cardNumber => 'رقم البطاقة';

  @override
  String get expiryDate => 'تاريخ الانتهاء (MM/YY)';

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
  String get phoneInvalid => 'يرجى إدخال رقم هاتف صحيح';

  @override
  String get continueButton => 'متابعة';

  @override
  String get promoCode => 'رمز الخصم';

  @override
  String get promoCodePlaceholder => 'أدخل رمز الخصم';

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
}
