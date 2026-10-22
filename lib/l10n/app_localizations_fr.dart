// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get forgotPassword => 'Mot de passe oublié ?';

  @override
  String get changePassword => 'Changer le mot de passe';

  @override
  String get pwdIntro =>
      'Saisissez votre mot de passe actuel, puis choisissez-en un nouveau. Vous resterez connecté sur cet appareil.';

  @override
  String get pwdCurrent => 'Mot de passe actuel';

  @override
  String get pwdNew => 'Nouveau mot de passe';

  @override
  String get pwdConfirm => 'Confirmer le nouveau mot de passe';

  @override
  String get pwdErrorRequired => 'Champ obligatoire';

  @override
  String get pwdErrorWrongCurrent => 'Mot de passe actuel incorrect';

  @override
  String pwdErrorTooShort(int min) {
    return 'Au moins $min caractères';
  }

  @override
  String get pwdErrorMismatch => 'Les deux mots de passe ne correspondent pas';

  @override
  String get pwdErrorSameAsOld =>
      'Le nouveau mot de passe est identique à l\'ancien';

  @override
  String get pwdErrorReauthNeeded =>
      'Par sécurité, confirmez à nouveau votre identité avant de changer votre mot de passe';

  @override
  String get pwdErrorNoSession => 'Votre session a expiré. Reconnectez-vous.';

  @override
  String get pwdErrorFailed =>
      'Impossible de changer le mot de passe. Réessayez.';

  @override
  String get pwdChangedTitle => 'Mot de passe modifié';

  @override
  String get pwdChangedBody =>
      'D\'autres appareils restent connectés avec l\'ancienne session. Voulez-vous les déconnecter ?';

  @override
  String get pwdKeepOtherDevices => 'Les garder';

  @override
  String get pwdSignOutOthers => 'Déconnecter les autres appareils';

  @override
  String get pwdOtherDevicesSignedOut =>
      'Les autres appareils ont été déconnectés';

  @override
  String get appTitle => 'Amana';

  @override
  String get signIn => 'Se connecter';

  @override
  String get signUp => 'S\'inscrire';

  @override
  String get createAccount => 'Créer un compte';

  @override
  String get email => 'Email';

  @override
  String get password => 'Mot de passe';

  @override
  String get fullName => 'Nom complet';

  @override
  String get or => 'OU';

  @override
  String pleaseEnter(Object field) {
    return 'Veuillez entrer votre $field';
  }

  @override
  String get validEmail => 'Veuillez entrer un email valide';

  @override
  String get passwordLength =>
      'Le mot de passe doit contenir au moins 6 caractères';

  @override
  String get settings => 'Paramètres';

  @override
  String get language => 'Langue';

  @override
  String get theme => 'Thème';

  @override
  String get darkMode => 'Mode sombre';

  @override
  String get lightMode => 'Mode clair';

  @override
  String get profile => 'Profil';

  @override
  String get logout => 'Déconnexion';

  @override
  String get home => 'Accueil';

  @override
  String get favorites => 'Favoris';

  @override
  String get cart => 'Panier';

  @override
  String get welcome => 'Bienvenue';

  @override
  String get search => 'Rechercher de la nourriture...';

  @override
  String get chooseOnMap => 'Choisir sur la carte';

  @override
  String get chooseOnMapSubtitle =>
      'Placez le repère à l’endroit exact de la livraison';

  @override
  String get categories => 'Catégories';

  @override
  String get popular => 'Populaire';

  @override
  String get seeAll => 'Voir tout';

  @override
  String get deliverTo => 'Livrer à';

  @override
  String get currentLocation => 'Position actuelle';

  @override
  String get searchRestaurants => 'Rechercher des restaurants...';

  @override
  String get popularRestaurants => 'Restaurants populaires';

  @override
  String get noFavoritesYet => 'Pas encore de favoris';

  @override
  String get myCart => 'Mon panier';

  @override
  String get clear => 'Effacer';

  @override
  String get subtotal => 'Sous-total';

  @override
  String get deliveryFee => 'Frais de livraison';

  @override
  String get total => 'Total';

  @override
  String get proceedToCheckout => 'Passer à la caisse';

  @override
  String get clearCart => 'Vider le panier';

  @override
  String get clearCartConfirmation =>
      'Êtes-vous sûr de vouloir supprimer tous les articles de votre panier ?';

  @override
  String get cancel => 'Annuler';

  @override
  String get cartEmpty => 'Votre panier est vide';

  @override
  String get addItemsToGetStarted => 'Ajoutez des articles pour commencer';

  @override
  String get browseRestaurants => 'Parcourir les restaurants';

  @override
  String get notifications => 'Notifications';

  @override
  String get markAllRead => 'Tout marquer comme lu';

  @override
  String get noNotifications => 'Aucune notification';

  @override
  String get notificationsWillAppearHere =>
      'Les notifications apparaîtront ici';

  @override
  String get specialInstructions => 'Instructions spéciales';

  @override
  String get typeMessage => 'Taper';

  @override
  String get voiceMessage => 'Message vocal';

  @override
  String get save => 'Enregistrer';

  @override
  String get typeInstructionsHint =>
      'par ex., Pas d\'oignons, fromage supplémentaire...';

  @override
  String get microphonePermissionDenied => 'Permission du microphone refusée';

  @override
  String get tapToRecord => 'Appuyez pour enregistrer';

  @override
  String get tapAgainToStop => 'Appuyez à nouveau pour arrêter';

  @override
  String get addSpecialInstructions => 'Ajouter des instructions spéciales';

  @override
  String get customization => 'Personnalisation';

  @override
  String get orderTracking => 'Suivi de commande';

  @override
  String get activeOrder => 'Commande active';

  @override
  String get confirmReceipt => 'Confirmer la réception';

  @override
  String get orderMarkedDelivered => 'Commande marquée comme livrée !';

  @override
  String get errorLoadingOrder => 'Erreur lors du chargement de la commande';

  @override
  String get errorLoadingRestaurants =>
      'Erreur lors du chargement des restaurants';

  @override
  String get errorLoadingMenu => 'Erreur lors du chargement du menu';

  @override
  String get retry => 'Réessayer';

  @override
  String get selectDeliveryAddress => 'Sélectionner une adresse de livraison';

  @override
  String get deliveryAddress => 'Adresse de livraison';

  @override
  String get paymentMethod => 'Mode de paiement';

  @override
  String get cashOnDelivery => 'Paiement à la livraison';

  @override
  String get payWhenYouReceive => 'Payez à la réception';

  @override
  String get payWithKonnect => 'Payer avec Konnect';

  @override
  String get secureOnlinePayment => 'Paiement en ligne sécurisé (Tunisie)';

  @override
  String get orderNotes => 'Notes de commande';

  @override
  String get specialDeliveryInstructions =>
      'Ajoutez des instructions spéciales pour la livraison...';

  @override
  String get orderSummary => 'Récapitulatif de commande';

  @override
  String get placeOrder => 'Passer la commande';

  @override
  String get myOrders => 'Mes commandes';

  @override
  String get noOrdersYet => 'Pas encore de commandes';

  @override
  String get startOrderingMessage =>
      'Votre historique de commandes apparaîtra ici';

  @override
  String get helpSupport => 'Aide et support';

  @override
  String get supportTicketSent =>
      'Ticket d\'assistance envoyé ! Nous vous contacterons bientôt.';

  @override
  String get savedAddresses => 'Adresses enregistrées';

  @override
  String get noAddressesSaved => 'Aucune adresse enregistrée';

  @override
  String get addNewAddress => 'Ajouter une nouvelle adresse';

  @override
  String get addressRemoved => 'Adresse supprimée';

  @override
  String get setDefault => 'Définir par défaut';

  @override
  String get noPaymentMethods => 'Aucun moyen de paiement enregistré';

  @override
  String get addNewCard => 'Ajouter une nouvelle carte';

  @override
  String get noRestaurantsFound => 'Aucun restaurant trouvé';

  @override
  String get confirmPasswordShort => 'Confirmer le mot de passe';

  @override
  String get pleaseEnterEmail => 'Veuillez saisir votre e-mail';

  @override
  String get sendResetCode => 'Envoyer le code';

  @override
  String get haveCodeEnterIt => 'Vous avez déjà un code ? Saisissez-le →';

  @override
  String get resetCodeInvalid =>
      'Le code est invalide ou a expiré. Demandez-en un nouveau.';

  @override
  String get passwordUpdatedBody =>
      'Votre mot de passe a été modifié. Connectez-vous avec le nouveau.';

  @override
  String get backToSignIn => 'Retour à la connexion';

  @override
  String get enterResetCode => 'Saisissez le code';

  @override
  String get pleaseEnterPassword => 'Veuillez saisir un mot de passe';

  @override
  String get resetPasswordButton => 'Réinitialiser le mot de passe';

  @override
  String get eightDigitCode => 'Code à 8 chiffres';

  @override
  String get enterEightDigitCode =>
      'Saisissez le code à 8 chiffres reçu par e-mail';

  @override
  String get callUs => 'Appelez-nous';

  @override
  String get somethingWentWrong =>
      'Une erreur est survenue. Veuillez réessayer.';

  @override
  String codeSentTo(String email) {
    return 'Code envoyé à $email';
  }

  @override
  String get filterAll => 'Tout';

  @override
  String get cuisinePastry => 'Pâtisseries';

  @override
  String get cuisinePizza => 'Pizza';

  @override
  String get cuisineBurgers => 'Burgers';

  @override
  String get cuisineSushi => 'Sushi';

  @override
  String get cuisineMexican => 'Mexicain';

  @override
  String get cuisineItalian => 'Italien';

  @override
  String get cuisineFastFood => 'Fast-food';

  @override
  String get shopOpen => 'Ouvert';

  @override
  String get shopClosed => 'Fermé';

  @override
  String get newShopBadge => 'Nouveau';

  @override
  String get deliveryLabel => 'Livraison';

  @override
  String get minOrderLabel => 'Commande min.';

  @override
  String get deliveryTimeLabel => 'Temps de livraison';

  @override
  String get couldNotLoadShops => 'Impossible de charger les boutiques';

  @override
  String get newShopsSoon =>
      'Revenez bientôt — de nouvelles boutiques arrivent.';

  @override
  String get today => 'Aujourd\'hui';

  @override
  String get yesterday => 'Hier';

  @override
  String get timeJustNow => 'À l\'instant';

  @override
  String reviewsCount(int count) {
    return '$count avis';
  }

  @override
  String timeMinutesAgo(int minutes) {
    return 'il y a $minutes min';
  }

  @override
  String timeHoursAgo(int hours) {
    return 'il y a $hours h';
  }

  @override
  String noRestaurantsNearby(int km) {
    return 'Aucun restaurant à moins de $km km de vous pour le moment.';
  }

  @override
  String noSupermarketsNearby(int km) {
    return 'Aucun supermarché à moins de $km km de vous pour le moment.';
  }

  @override
  String get couldNotLoadSupermarkets =>
      'Impossible de charger les supermarchés';

  @override
  String get couldNotGetLocation =>
      'Impossible d\'obtenir la position actuelle. Veuillez activer les services de localisation.';

  @override
  String get account => 'Compte';

  @override
  String get orderHistory => 'Historique des commandes';

  @override
  String get editProfile => 'Modifier le profil';

  @override
  String get paymentMethods => 'Moyens de paiement';

  @override
  String get user => 'Utilisateur';

  @override
  String get viewDeals => 'Voir les offres';

  @override
  String get saveUpTo60 =>
      'Économisez jusqu\'à 60% sur la nourriture et l\'épicerie !';

  @override
  String get happyHour => 'HAPPY HOUR';

  @override
  String get happyHourLive => 'EN DIRECT';

  @override
  String get receiptQuestion => 'Avez-vous reçu votre commande ?';

  @override
  String get receiptQuestionParcel => 'Votre colis a-t-il bien été remis ?';

  @override
  String get receiptYesParcel => 'Oui, remis';

  @override
  String get receiptNoParcel => 'Non, pas remis';

  @override
  String get receiptNotDeliveredParcelLink => 'Mon colis n\'a pas été remis';

  @override
  String get receiptReportBodyParcel =>
      'Nous préviendrons notre support que ce colis n\'a pas été remis.';

  @override
  String receiptAutoIn(String time) {
    return 'Confirmation automatique dans $time';
  }

  @override
  String get receiptYes => 'Oui, reçue';

  @override
  String get receiptNo => 'Non, pas reçue';

  @override
  String get receiptConfirmed => 'Réception confirmée. Merci !';

  @override
  String get receiptAutoConfirmed => 'Réception confirmée automatiquement';

  @override
  String get receiptNotReceivedLink => 'Je n\'ai pas reçu ma commande';

  @override
  String get receiptReportTitle => 'Signaler un problème ?';

  @override
  String get receiptReportBody =>
      'Nous préviendrons notre support que vous n\'avez pas reçu cette commande.';

  @override
  String get receiptReportConfirm => 'Signaler';

  @override
  String get receiptReported => 'Signalé. Notre support va vous contacter.';

  @override
  String get receiptSaveFailed =>
      'Impossible d\'enregistrer votre réponse. Réessayez.';

  @override
  String get receiptTapToConfirm => 'Touchez pour confirmer';

  @override
  String get rateDriverTitle => 'Notez votre livreur';

  @override
  String get rateDriverButton => 'Noter le livreur';

  @override
  String get rateDriverHint => 'Un commentaire ? (facultatif)';

  @override
  String get rateDriverSend => 'Envoyer';

  @override
  String get rateDriverLater => 'Plus tard';

  @override
  String get rateDriverThanks => 'Merci pour votre avis !';

  @override
  String get rateDriverFailed =>
      'Impossible d\'envoyer votre avis pour le moment.';

  @override
  String happyHourDealsSummary(int count, int percent) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count offres · jusqu\'à -$percent%',
      one: '1 offre · jusqu\'à -$percent%',
    );
    return '$_temp0';
  }

  @override
  String happyHourEndsIn(String time) {
    return 'Se termine dans $time';
  }

  @override
  String get happyHourNoDealsNow =>
      'Pas d\'offre en ce moment, revenez bientôt';

  @override
  String happyHourUnitsLeft(int count) {
    return 'Plus que $count !';
  }

  @override
  String get happyHourShopsTab => 'Boutiques';

  @override
  String addedToCartWithQuantity(int quantity, String item) {
    return '$quantity x $item ajouté au panier';
  }

  @override
  String get chooseAnOption => 'Choisissez une option';

  @override
  String get errorLoadingItems => 'Impossible de charger les articles';

  @override
  String get supermarketClosedNow => 'Ce supermarché est fermé pour le moment.';

  @override
  String get restaurantClosedLabel => 'Restaurant fermé';

  @override
  String get organic => 'Bio';

  @override
  String get happyHourSubtitle =>
      'Profitez des meilleurs prix sur vos plats préférés';

  @override
  String get promos => 'PROMOS';

  @override
  String get promosSubtitle => 'Des remises sur vos boutiques préférées';

  @override
  String get promosBannerCta => 'Voir les promos';

  @override
  String get happyHourGrab => 'J\'en profite';

  @override
  String addedToCart(String item) {
    return '$item ajouté au panier';
  }

  @override
  String get happyHourLoadError => 'Impossible de charger les offres';

  @override
  String get viewCart => 'Voir le panier';

  @override
  String get cartFromAnotherShopTitle => 'Panier d\'une autre boutique';

  @override
  String get cartFromAnotherShopMessage =>
      'Votre panier contient déjà des articles d\'une autre boutique. Voulez-vous le vider pour ajouter cet article ?';

  @override
  String get emptyAndAdd => 'Vider et ajouter';

  @override
  String get newItemBadge => 'NOUVEAU';

  @override
  String get restaurants => 'Restaurants';

  @override
  String get supermarkets => 'Supermarchés';

  @override
  String get noDealsRightNow =>
      'Aucune offre pour le moment. Revenez plus tard !';

  @override
  String get confirmPickupRequest => 'Confirmer la demande de ramassage';

  @override
  String get amountToCollect => 'Montant à collecter :';

  @override
  String get confirmPickup => 'Confirmer le ramassage';

  @override
  String get pleaseSignInToContinue => 'Veuillez vous connecter pour continuer';

  @override
  String get billPayments => 'Paiement de factures';

  @override
  String get internet => 'Internet';

  @override
  String get electricity => 'Électricité';

  @override
  String get water => 'Eau';

  @override
  String get selectProvider => 'Sélectionner un fournisseur';

  @override
  String get noProvidersAvailable =>
      'Aucun fournisseur disponible pour cette catégorie pour le moment.';

  @override
  String get howMuchToPay => 'Combien payer ?';

  @override
  String get driverWillCollect =>
      'Un livreur viendra collecter ce montant exact chez vous.';

  @override
  String get amountDt => 'Montant (DT)';

  @override
  String get pleaseEnterAmount => 'Veuillez entrer un montant';

  @override
  String get pleaseEnterValidAmount => 'Veuillez entrer un montant valide';

  @override
  String get requestDriverForPickup => 'Demander un livreur pour le ramassage';

  @override
  String get serviceFeeNote =>
      'Frais : 2.000 DT de frais de service seront ajoutés par le livreur';

  @override
  String get pleaseSelectAddress =>
      'Veuillez sélectionner une adresse de livraison';

  @override
  String get pleaseEnterPhone =>
      'Veuillez entrer votre numéro de téléphone pour que le livreur puisse vous joindre';

  @override
  String get checkout => 'Paiement';

  @override
  String get contactInfo => 'Coordonnées';

  @override
  String get phoneHint => 'Numéro de téléphone (ex. +216 12 345 678)';

  @override
  String get fullNameHint => 'Nom complet';

  @override
  String get selectAddress => 'Sélectionner une adresse';

  @override
  String get useCurrentLocation => 'Utiliser la position actuelle';

  @override
  String get gettingLocation => 'Localisation en cours...';

  @override
  String get enableLocationToDeliver =>
      'Activez la localisation pour livrer ici';

  @override
  String get addNew => 'Ajouter';

  @override
  String get defaultLabel => 'Par défaut';

  @override
  String get couldNotGeocode =>
      'Impossible de géocoder l\'adresse. Veuillez vérifier l\'adresse et réessayer.';

  @override
  String get labelHint => 'Étiquette (ex. Maison, Travail)';

  @override
  String get fullAddressLabel => 'Adresse complète';

  @override
  String get apartment => 'Appartement';

  @override
  String get floor => 'Étage';

  @override
  String get saveAddress => 'Enregistrer l\'adresse';

  @override
  String get pleaseSelectPickupDropoff =>
      'Veuillez sélectionner les lieux de ramassage et de livraison';

  @override
  String get recipientDetails => 'Détails du destinataire';

  @override
  String get friendsName => 'Nom de l\'ami';

  @override
  String get phoneNumber => 'Numéro de téléphone';

  @override
  String get packageDetails => 'Détails du colis';

  @override
  String get whatAreYouSending => 'Que voulez-vous envoyer ?';

  @override
  String get locations => 'Lieux';

  @override
  String get pickupLocation => 'Lieu de retrait';

  @override
  String get dropoffLocation => 'Lieu de livraison';

  @override
  String get requestCourier => 'Demander un coursier';

  @override
  String get recipientAccepted => 'Le destinataire a accepté le colis';

  @override
  String get yourCourier => 'Votre coursier';

  @override
  String get recipient => 'Destinataire';

  @override
  String get phone => 'Téléphone';

  @override
  String get item => 'Article';

  @override
  String get driverPhoneNotAvailable =>
      'Le téléphone du livreur n\'est pas encore disponible';

  @override
  String get unableToStartCall => 'Impossible de lancer l\'appel téléphonique';

  @override
  String get sendParcelTitle => 'Envoyer un colis';

  @override
  String get sendParcelSubtitle =>
      'Envoyez n\'importe quel article d\'un point A à un point B';

  @override
  String get parcelSuccessTitle => 'Ton colis est en route !';

  @override
  String orderSuccessTrackingRef(String ref) {
    return 'Commande #$ref';
  }

  @override
  String get trackMyParcel => 'Suivre mon colis';

  @override
  String get trackMyOrder => 'Suivre ma commande';

  @override
  String get backToHome => 'Retour à l\'accueil';

  @override
  String get foodHeroTitle => 'Commander un repas';

  @override
  String get supermarketHeroTitle => 'Faire ses courses';

  @override
  String get factureHeroTitle => 'Payer une facture';

  @override
  String get supermarketSuccessTitle => 'Ta commande est en route !';

  @override
  String get factureSuccessTitle => 'Ta facture est prise en charge !';

  @override
  String get cardholderName => 'Nom du titulaire';

  @override
  String get cardNumber => 'Numéro de carte';

  @override
  String get expiryDate => 'Date d\'expiration (MM/AA)';

  @override
  String get phoneNumberLabel => 'Numéro de téléphone';

  @override
  String get bio => 'Bio';

  @override
  String get subject => 'Sujet';

  @override
  String get message => 'Message';

  @override
  String get submitTicket => 'Envoyer le ticket';

  @override
  String get howCanWeHelp => 'Comment pouvons-nous vous aider ?';

  @override
  String get fillFormDescription =>
      'Remplissez le formulaire ci-dessous et notre équipe vous répondra dans les 24 heures.';

  @override
  String get failedToSendTicket =>
      'Échec de l\'envoi du ticket. Veuillez réessayer.';

  @override
  String get removedFromFavorites => 'Retiré des favoris';

  @override
  String get addedToFavorites => 'Ajouté aux favoris';

  @override
  String get addressRemovedSuccess => 'Adresse supprimée';

  @override
  String get pleaseEnterSubject => 'Veuillez entrer un sujet';

  @override
  String get pleaseEnterMessage => 'Veuillez entrer votre message';

  @override
  String get pleaseEnterName => 'Veuillez entrer votre nom';

  @override
  String get profileUpdated => 'Profil mis à jour avec succès !';

  @override
  String get failedToUpdateProfile => 'Échec de la mise à jour du profil';

  @override
  String get saveChanges => 'Enregistrer les modifications';

  @override
  String get addYourPhoneNumber => 'Ajoutez votre numéro de téléphone';

  @override
  String get phoneRequiredExplain =>
      'Nous avons besoin de votre numéro de téléphone pour que les livreurs puissent vous joindre. Étape unique.';

  @override
  String get phoneInvalid =>
      'Veuillez entrer un numéro tunisien valide à 8 chiffres';

  @override
  String get continueButton => 'Continuer';

  @override
  String get promoCode => 'Code promo';

  @override
  String get promoCodePlaceholder => 'Entrez votre code promo';

  @override
  String get billTypeElectricity => 'STEG (Électricité)';

  @override
  String get billTypeWater => 'SONEDE (Eau)';

  @override
  String get billTypeInternet => 'Topnet (Internet)';

  @override
  String get packageFallback => 'Colis';

  @override
  String get orderStatusPending => 'En attente';

  @override
  String get orderStatusConfirmed => 'Confirmée';

  @override
  String get orderStatusPreparing => 'En préparation';

  @override
  String get orderStatusReady => 'Prête';

  @override
  String get orderStatusPickedUp => 'Récupérée';

  @override
  String get orderStatusOnTheWay => 'En route';

  @override
  String get orderStatusDelivered => 'Livrée';

  @override
  String get orderStatusCancelled => 'Annulée';

  @override
  String get timelineOrderConfirmed => 'Commande confirmée';

  @override
  String get timelinePreparing => 'En préparation';

  @override
  String get timelineReady => 'Prête';

  @override
  String get timelineOnTheWay => 'En route';

  @override
  String get timelineDelivered => 'Livrée';

  @override
  String get timelineRequestConfirmed => 'Demande confirmée';

  @override
  String get timelinePickedUp => 'Colis récupéré';

  @override
  String get timelineDriverComing => 'Livreur en route chez vous';

  @override
  String get timelineCashCollected => 'Espèces collectées';

  @override
  String get timelineBillPaid => 'Facture payée';

  @override
  String estimatedDeliveryAt(String time) {
    return 'Livraison estimée : $time';
  }

  @override
  String get orderDetailsTitle => 'Récapitulatif de commande';

  @override
  String get billDetailsTitle => 'Détails de la facture';

  @override
  String get deliveryLocation => 'Lieu de livraison';

  @override
  String get paymentOffice => 'Bureau de paiement';

  @override
  String get yourAddress => 'Votre adresse';

  @override
  String get driverLabel => 'Livreur';

  @override
  String get routeLabel => 'Itinéraire';

  @override
  String get billTypeField => 'Type';

  @override
  String get billReferenceField => 'Référence';

  @override
  String get billAmountField => 'Montant';

  @override
  String get billPhotoLabel => 'Photo de la facture';

  @override
  String get paymentReceiptLabel => 'Reçu de paiement';

  @override
  String get paymentMethodCash => 'Espèces';

  @override
  String get cancelOrderTitle => 'Annuler la commande';

  @override
  String get cancelDriverAssigned =>
      'Un livreur est déjà assigné à votre commande. Voulez-vous vraiment annuler ?';

  @override
  String get cancelReasonLabel => 'Raison de l\'annulation :';

  @override
  String get cancelReasonWrongOrder => 'Erreur de commande';

  @override
  String get cancelReasonTooLong => 'Délai trop long';

  @override
  String get cancelReasonChangedMind => 'J\'ai changé d\'avis';

  @override
  String get cancelReasonOther => 'Autre';

  @override
  String get backAction => 'Retour';

  @override
  String get confirmAction => 'Confirmer';

  @override
  String get orderCancelledOk => 'Commande annulée avec succès.';

  @override
  String get cancelTooLatePreparing =>
      'Impossible d\'annuler — la commande est déjà en cours de préparation.';

  @override
  String get cancelTooLateOnTheWay =>
      'La commande est déjà en route. Pour annuler, contactez le support.';

  @override
  String placeOrderWithTotal(String total) {
    return 'Commander — $total';
  }

  @override
  String get venueClosedNow =>
      'Ce commerce est actuellement fermé et ne peut pas accepter de commande.';

  @override
  String get paymentFailedOrderCancelled =>
      'Paiement refusé. Commande annulée.';

  @override
  String get loyaltyFreeDelivery => 'Fidélité — livraison gratuite';

  @override
  String get loyaltyHalfDelivery => 'Fidélité — −50 % livraison';

  @override
  String genericErrorWith(String message) {
    return 'Erreur : $message';
  }

  @override
  String promoOnEligible(String discount, String eligible) {
    return '− $discount sur $eligible éligibles';
  }

  @override
  String get promoErrorNotFound => 'Ce code promo n\'existe pas';

  @override
  String get promoErrorInactive => 'Ce code promo n\'est plus actif';

  @override
  String get promoErrorExpired =>
      'Ce code a expiré ou n\'est pas encore valable';

  @override
  String get promoErrorMaxUses => 'Ce code n\'est plus disponible';

  @override
  String get promoErrorAlreadyUsed => 'Vous avez déjà utilisé ce code promo';

  @override
  String get promoErrorMinOrder =>
      'Votre commande est en dessous du minimum de ce code';

  @override
  String promoErrorMinOrderAmount(String amount) {
    return 'Ce code demande une commande d\'au moins $amount';
  }

  @override
  String get promoErrorAllOnPromo =>
      'Vos articles sont déjà en promotion : ce code ne s\'applique pas';

  @override
  String get promoErrorNotFirstOrder =>
      'Ce code est réservé à votre première commande';

  @override
  String get promoErrorEmptyCart => 'Votre panier est vide';

  @override
  String get promoErrorNotLoggedIn =>
      'Connectez-vous pour utiliser un code promo';

  @override
  String get promoErrorNetwork => 'Erreur réseau. Veuillez réessayer.';

  @override
  String get promoErrorGeneric => 'Code invalide ou expiré';

  @override
  String get applyPromoCode => 'Appliquer';

  @override
  String get removePromoCode => 'Retirer';

  @override
  String get promoApplied => 'Réduction appliquée !';

  @override
  String promoDiscount(String code) {
    return 'Réduction ($code)';
  }

  @override
  String get loyaltyCardTitle => 'Carte de fidélité';

  @override
  String get loyaltyPendingSubtitle =>
      'Tampon en attente — confirmé à la livraison';

  @override
  String get loyaltyProgressLabel => 'Ta progression';

  @override
  String loyaltyRemainingHalf(int count) {
    return 'Encore $count commandes pour ta livraison à moitié prix';
  }

  @override
  String loyaltyRemainingFree(int count) {
    return 'Encore $count commandes pour ta livraison gratuite';
  }

  @override
  String get loyaltyCelebrationHalf =>
      'C\'est ta 5ème commande — ta livraison est à moitié prix !';

  @override
  String get loyaltyCelebrationFree =>
      '10ème commande — ta livraison est offerte !';

  @override
  String get loyaltyViewRewards => 'Voir mes récompenses';

  @override
  String get loyaltyCancelTitle => 'Commande annulée';

  @override
  String get loyaltyCancelMessage =>
      'C\'est noté ! On espère te revoir très bientôt. Merci de ta confiance !';

  @override
  String get loyaltyCancelNote =>
      'Le tampon de cette commande a été retiré de ta carte.';

  @override
  String get loyaltyCancelPrimaryCta => 'Recommander';

  @override
  String get loyaltyCancelSecondaryCta => 'Fermer';

  @override
  String get loyaltyRewardsTitle => 'Mes récompenses';

  @override
  String get loyaltyMilestoneHalfTitle => '5ème commande';

  @override
  String get loyaltyMilestoneHalfSubtitle => 'Livraison à moitié prix';

  @override
  String get loyaltyMilestoneFreeTitle => '10ème commande';

  @override
  String get loyaltyMilestoneFreeSubtitle => 'Livraison gratuite';

  @override
  String get loyaltyStateAchieved => 'Atteint';

  @override
  String get loyaltyStateCurrent => 'En cours';

  @override
  String get loyaltyStateLocked => 'Verrouillé';

  @override
  String get loyaltyHowItWorksTitle => 'Comment ça marche';

  @override
  String get loyaltyHowItWorks1 => 'Chaque commande livrée = 1 tampon';

  @override
  String get loyaltyHowItWorks2 =>
      'Les réductions s\'appliquent automatiquement sur les frais de livraison de la commande qui atteint le palier';

  @override
  String get loyaltyHowItWorks3 => 'Les commandes annulées ne comptent pas';

  @override
  String get loyaltyHowItWorks4 =>
      'Après la 10ème commande, la carte se réinitialise et un nouveau cycle commence';

  @override
  String get optionGroupRequired => 'Obligatoire';

  @override
  String get optionGroupOptional => 'Facultatif';

  @override
  String optionGroupSelectExact(int count) {
    return 'Sélectionnez $count';
  }

  @override
  String optionGroupSelectUpTo(int max) {
    return 'Sélectionnez jusqu\'à $max';
  }

  @override
  String optionGroupSelectRange(int min, int max) {
    return 'Sélectionnez de $min à $max';
  }

  @override
  String addToCartWithTotal(String total) {
    return 'Ajouter au panier · $total';
  }

  @override
  String get completeRequiredSelections =>
      'Veuillez compléter les sélections obligatoires';

  @override
  String get variantGroupTitle => 'Choisissez une option';

  @override
  String get aiSearchTitle => 'Recherche IA';

  @override
  String get aiSearchPlaceholder => 'Décris ce que tu cherches...';

  @override
  String get aiSearchCameraTooltip => 'Rechercher par photo';

  @override
  String get aiSearchVisualSearchBadge => 'Recherche visuelle';

  @override
  String aiSearchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count résultats trouvés',
      one: '1 résultat trouvé',
    );
    return '$_temp0';
  }

  @override
  String get aiSearchLoadingPhoto => 'Analyse de votre photo…';

  @override
  String get aiSearchLoadingText => 'Analyse de votre demande…';

  @override
  String get aiSearchPoweredBy => 'Propulsé par l\'IA';

  @override
  String get aiSearchEmptyTitle => 'Décris ce que tu veux';

  @override
  String get aiSearchEmptyDescription =>
      'Écris en Darija, français ou arabe — ou envoie une photo du plat que tu cherches.';

  @override
  String get aiSearchExampleQuery1 => 'N7eb chapati w ma tfoutch 10 dinar';

  @override
  String get aiSearchExampleQuery2 => 'Une pizza pas chère';

  @override
  String get aiSearchExampleQuery3 => 'Un malfouf à moins de 12 dinars';

  @override
  String get aiSearchExampleQueryPhoto => 'Envoyer une photo de plat';

  @override
  String aiSearchNoResultsPhoto(String dishName) {
    return 'Aucun restaurant trouvé pour « $dishName »';
  }

  @override
  String get aiSearchNoResultsText => 'Aucun plat ne correspond à ta demande';

  @override
  String get aiSearchFallbackMessage =>
      'Aucun résultat exact — voici des plats populaires';

  @override
  String get aiSearchModalTitle => 'Rechercher par photo';

  @override
  String aiSearchModalHint(String city) {
    return 'Envoie une photo d\'un plat pour le trouver à $city';
  }

  @override
  String get aiSearchCameraLabel => 'Appareil photo';

  @override
  String get aiSearchGalleryLabel => 'Galerie';

  @override
  String get aiSearchTryAgain => 'Réessayer';

  @override
  String get aiSearchErrorCouldNotOpen => 'Impossible d\'ouvrir l\'image';

  @override
  String aiSearchIdentified(String dishName, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count restaurants',
      one: '1 restaurant',
    );
    return 'Identifié : « $dishName » · $_temp0';
  }

  @override
  String get city => 'Kairouan';

  @override
  String get colisHandoverSectionTitle =>
      'Comment le livreur remet votre colis ?';

  @override
  String get colisModeRecommended => 'Recommandé';

  @override
  String get colisModeCodeTitle => 'Avec code';

  @override
  String get colisModeCodeSubtitle =>
      'Le plus sûr pour vous. Vous recevez un code à 4 chiffres. Envoyez-le à la personne qui reçoit le colis. À l\'arrivée, elle donne ce code au livreur. Sans le bon code, le livreur ne peut pas terminer la livraison. Vous êtes donc sûr que votre colis arrive à la bonne personne.';

  @override
  String get colisModeNoCodeTitle => 'Remise sans code';

  @override
  String get colisModeNoCodeSubtitle =>
      'Si la personne n\'a pas de téléphone (un enfant à l\'école, un gardien…). Le livreur prend une photo au moment de la remise, avec sa position. C\'est moins sûr qu\'avec un code.';

  @override
  String colisCodeHeadline(String code) {
    return 'Votre code de remise : $code';
  }

  @override
  String get colisCodeExplain =>
      'Envoyez ce code au destinataire. Il le donnera au livreur quand il recevra le colis.';

  @override
  String colisShareMessage(String code) {
    return 'Bonjour, un colis Amana arrive pour vous. Donnez ce code au livreur à la réception : $code';
  }

  @override
  String get colisShareSubject => 'Code de remise Amana';

  @override
  String get mapGpsUnavailable => 'Impossible d\'obtenir la position GPS';

  @override
  String get mapUseCurrentLocation => 'Utiliser ma position actuelle';

  @override
  String get mapOr => 'ou';

  @override
  String get mapSearchHint => 'Rechercher une adresse ou un lieu…';

  @override
  String get mapTypeStreetHint => 'Tapez un nom de rue, quartier ou lieu…';

  @override
  String get mapNoResults => 'Aucun résultat';

  @override
  String get mapLocating => 'Localisation…';

  @override
  String get mapLocatingInProgress => 'Localisation en cours…';

  @override
  String get mapDragToAdjust => 'Glissez pour ajuster la position';

  @override
  String get mapDragToPlace => 'Glissez la carte vers l\'emplacement souhaité';

  @override
  String get mapConfirmLocation => 'Confirmer cet emplacement';

  @override
  String get authErrorInvalidCredentials => 'Email ou mot de passe incorrect';

  @override
  String get authErrorAccountExists => 'Un compte existe déjà avec cet email';

  @override
  String get authErrorEmailNotConfirmed =>
      'Veuillez confirmer votre email avant de vous connecter';

  @override
  String get authErrorNoInternet => 'Problème de connexion internet';

  @override
  String get authErrorTimeout =>
      'Le serveur met trop de temps à répondre. Réessayez.';

  @override
  String get authErrorServiceUnavailable =>
      'Le service est momentanément indisponible. Réessayez dans un instant.';

  @override
  String get authErrorGeneric => 'Une erreur est survenue, veuillez réessayer';

  @override
  String get authCheckFormFields => 'Vérifiez les champs du formulaire';

  @override
  String get authAccountCreatedConfirmEmail =>
      'Compte créé ! Ouvrez l\'email de confirmation que nous venons d\'envoyer, puis connectez-vous.';

  @override
  String get billsTitle => 'Mes factures';

  @override
  String get billsLoadError => 'Impossible de charger les factures';

  @override
  String get billsEmptyTitle => 'Aucune facture payée';

  @override
  String get billsEmptySubtitle => 'Vos paiements de factures apparaîtront ici';

  @override
  String billsReference(String reference) {
    return 'Réf: $reference';
  }

  @override
  String get billsReceiptAvailable => 'Reçu disponible';

  @override
  String get billsLabelSteg => 'STEG — Électricité';

  @override
  String get billsLabelSonede => 'SONEDE — Eau';

  @override
  String get billsLabelTopnet => 'Topnet — Internet';

  @override
  String get billsLabelOther => 'Autre facture';

  @override
  String get billStatusPaid => 'Payée';

  @override
  String get billStatusInProgress => 'En cours';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonInvalidAmount => 'Montant invalide';

  @override
  String get commonInvalidPhone8 =>
      'Numéro invalide — exactement 8 chiffres requis';

  @override
  String get photoTakePicture => 'Prendre une photo';

  @override
  String get photoChooseFromGallery => 'Choisir depuis la galerie';

  @override
  String get courierDeleteRecipientTitle => 'Supprimer ce destinataire ?';

  @override
  String courierDeleteRecipientBody(String name) {
    return '$name sera retiré de vos contacts enregistrés.';
  }

  @override
  String get courierPickupAddress => 'Adresse de ramassage';

  @override
  String get courierConfirmNoForbidden =>
      'Confirmez que votre colis ne contient aucun article interdit.';

  @override
  String get courierAcceptPhotoProof =>
      'Acceptez que la photo et la position tiennent lieu de preuve.';

  @override
  String get courierDeclaredValueRequired =>
      'Indiquez la valeur de votre colis';

  @override
  String get courierDeclaredValuePositive =>
      'La valeur doit être supérieure à 0';

  @override
  String courierDeclaredValueMax(String max) {
    return 'Maximum $max TND — scindez votre envoi';
  }

  @override
  String get courierDescriptionRequired => 'Décrivez le contenu de votre colis';

  @override
  String get courierReceiverLabelRequired =>
      'Indiquez à qui le colis sera remis';

  @override
  String get courierSenderPhone => 'Téléphone de l\'expéditeur';

  @override
  String get courierSenderPhoneHint => 'La personne qui remet le colis';

  @override
  String get courierSenderPhoneRequired =>
      'Obligatoire — numéro de l\'expéditeur';

  @override
  String get courierRecipientName => 'Nom du destinataire';

  @override
  String get courierRecipientNameHint =>
      'Optionnel — aide le livreur à identifier le destinataire';

  @override
  String get courierRecipientNameExample => 'Ex: Mohamed Ben Ali';

  @override
  String get courierRecipientPhone => 'Téléphone du destinataire';

  @override
  String get courierRecipientPhoneHint => 'La personne qui reçoit le colis';

  @override
  String get courierRecipientPhoneRequired =>
      'Obligatoire — numéro du destinataire';

  @override
  String get courierContentsTitle => 'Que contient votre colis ?';

  @override
  String get courierContentsExample =>
      'Ex : téléphone Samsung A15, documents, vêtements…';

  @override
  String get courierDeclaredValue => 'Valeur déclarée';

  @override
  String courierDeclaredValueCap(String max) {
    return 'Plafond : $max TND. Au-delà, scindez votre envoi en plusieurs colis.';
  }

  @override
  String get courierDeclaredValueHint => 'Valeur en TND';

  @override
  String get courierPhotoTitle => 'Photo du colis';

  @override
  String get courierPhotoHint =>
      'Optionnel — aide le livreur à identifier votre colis';

  @override
  String get courierSizeTitle => 'Taille du colis';

  @override
  String get courierConfirmSend => 'Confirmer l\'envoi';

  @override
  String get courierTapToSelect => 'Appuyez pour sélectionner';

  @override
  String get courierPhoneExample => 'Ex: 20123456';

  @override
  String get courierEstimatedPrice => 'Prix estimé';

  @override
  String get courierEstimatedPriceLoyaltyFree =>
      'Prix estimé — fidélité : livraison gratuite';

  @override
  String get courierEstimatedPriceLoyaltyHalf =>
      'Prix estimé — fidélité : -50%';

  @override
  String get courierPriceBase => '3.500 TND base';

  @override
  String get courierReceiverLabelExample =>
      'Ex : Gardien de l\'école, voisin du 3e…';

  @override
  String get courierAcceptPhotoProofCheckbox =>
      'J\'accepte que la preuve de remise soit la photo et la position du livreur.';

  @override
  String get courierForbiddenTitle => 'Interdit dans un colis';

  @override
  String get courierForbiddenConfirm =>
      'Je confirme que mon colis ne contient aucun de ces articles';

  @override
  String get courierPhotoChange => 'Changer';

  @override
  String get courierPhotoAdd => 'Ajouter une photo du colis';

  @override
  String get courierPhotoTapHint => 'Appuyer pour prendre/choisir une photo';

  @override
  String get courierSizeSmall => 'Petit';

  @override
  String get courierSizeMedium => 'Moyen';

  @override
  String get courierSizeLarge => 'Grand';

  @override
  String get courierSizeSmallDesc => 'Documents, petits objets';

  @override
  String get courierSizeMediumDesc => 'Vêtements, accessoires';

  @override
  String get courierSizeLargeDesc => 'Bagages, gros colis';

  @override
  String get courierSaveRecipient =>
      'Enregistrer ce destinataire pour la prochaine fois';

  @override
  String get courierSavedRecipients => 'Destinataires enregistrés';

  @override
  String get factureSelectBillType =>
      'Veuillez sélectionner le type de facture';

  @override
  String get factureEnterPickupAddress =>
      'Veuillez indiquer votre adresse de ramassage';

  @override
  String get factureEnterOfficeAddress =>
      'Veuillez indiquer l\'adresse du bureau';

  @override
  String get factureNotSignedIn => 'Non connecté';

  @override
  String get factureReferenceRequired => 'Obligatoire — numéro de référence';

  @override
  String get factureAmountRequired => 'Obligatoire — montant de la facture';

  @override
  String get facturePhoneRequired => 'Obligatoire — numéro de téléphone';

  @override
  String get factureBillTypeTitle => 'Type de facture';

  @override
  String get factureReferenceLabel => 'Numéro de référence / contrat';

  @override
  String get factureAmountLabel => 'Montant à payer (TND)';

  @override
  String get factureCustomerAddressTitle =>
      'Votre adresse (ramassage des espèces)';

  @override
  String get factureChooseYourAddress => 'Choisir votre adresse';

  @override
  String factureOfficeAddressTitle(String billType) {
    return 'Adresse du bureau $billType';
  }

  @override
  String get factureChooseOfficeAddress => 'Choisir l\'adresse du bureau';

  @override
  String get facturePhoneTitle => 'Votre numéro de téléphone';

  @override
  String get facturePhoneLabel => 'Téléphone (8 chiffres)';

  @override
  String get factureAddBillPhoto => 'Ajouter photo de la facture (optionnel)';

  @override
  String get factureRemovePhoto => 'Supprimer la photo';

  @override
  String get factureBillAmount => 'Montant de la facture';

  @override
  String get factureCollectedInCash => '(collecté en espèces)';

  @override
  String get factureServiceFee => 'Frais de service';

  @override
  String get factureLoyaltyHalf => 'Fidélité — -50%';

  @override
  String get factureSendRequest => 'Envoyer la demande';

  @override
  String get colisDisputeExplain =>
      'Décrivez ce qui s\'est passé. Un administrateur examinera les preuves (photos, heure, position) avant de décider.';

  @override
  String get colisDisputeMessageHint => 'Votre message (facultatif)';

  @override
  String get colisDisputeSendFailed =>
      'Le signalement n\'a pas pu être envoyé.';

  @override
  String get colisReceiptTitle => 'Bon de prise en charge';

  @override
  String get colisReceiptDeclaredContents => 'Contenu déclaré';

  @override
  String get colisReceiptHandedTo => 'Remise à';

  @override
  String get colisReceiptPlate => 'Plaque';

  @override
  String get colisReceiptDistanceToAddress => 'Distance à l\'adresse';

  @override
  String get colisProofPickup => 'Prise en charge';

  @override
  String get colisProofDelivery => 'Remise';

  @override
  String get colisDisputeSent =>
      'Signalement envoyé. Un administrateur va l\'examiner.';

  @override
  String get colisDisputeWindow =>
      'Un problème ? Vous avez 24 h après la livraison pour le signaler.';

  @override
  String get colisDisputeNotReceivedTitle => 'Colis non reçu';

  @override
  String get colisDisputeNotReceived => 'Non reçu';

  @override
  String get colisDisputeProblem => 'Problème avec le colis';

  @override
  String get colisCodeCopy => 'Copier';

  @override
  String get colisCodeCopied => 'Code copié';

  @override
  String get colisCodeShare => 'Partager';

  @override
  String get loyaltyAppliedFree =>
      '🎉 Livraison gratuite appliquée — merci de votre fidélité !';

  @override
  String get loyaltyAppliedHalf =>
      '🎉 -50% sur la livraison appliqué — merci de votre fidélité !';

  @override
  String loyaltyProgressOrders(String progress) {
    return '$progress/5 commandes avant votre prochaine réduction';
  }

  @override
  String get loyaltyBadgeFree => '🎉 Livraison gratuite';

  @override
  String get loyaltyBadgeHalf => '🎉 -50% sur la livraison';

  @override
  String get reorderButton => 'Commander à nouveau';

  @override
  String get reorderReplaceCartTitle => 'Remplacer le panier ?';

  @override
  String get reorderReplaceCartBody =>
      'Votre panier actuel contient déjà des articles. Le remplacer par ceux de cette commande ?';

  @override
  String get reorderReplace => 'Remplacer';

  @override
  String get reorderNothingAvailable =>
      'Aucun article de cette commande n\'est disponible actuellement.';

  @override
  String reorderSkipped(String count) {
    return '$count article(s) non disponible(s) ont été ignoré(s).';
  }

  @override
  String get reorderFailed => 'Erreur lors de la recommande. Réessayez.';

  @override
  String get orderTypeFacture => 'Paiement de facture';

  @override
  String get orderShopSupermarket => 'Supermarché';

  @override
  String get orderShopBakery => 'Pâtisserie';

  @override
  String get orderShopFlowers => 'Fleurs';

  @override
  String get orderShopPets => 'Animalerie';

  @override
  String get orderShopGifts => 'Cadeaux';

  @override
  String get orderShopElectronics => 'Électronique';

  @override
  String get orderShopRestaurant => 'Restaurant';

  @override
  String get homeEmptyBakery => 'Aucune pâtisserie disponible près de vous.';

  @override
  String get homeEmptyFlowers => 'Aucun fleuriste disponible près de vous.';

  @override
  String get homeEmptyPets => 'Aucune animalerie disponible près de vous.';

  @override
  String get homeEmptyGifts => 'Aucune boutique de cadeaux près de vous.';

  @override
  String get homeEmptyElectronics =>
      'Aucune boutique d\'électronique près de vous.';

  @override
  String get homeEmptyShops => 'Aucune boutique disponible près de vous.';

  @override
  String get profileUploadFailed => 'Échec du chargement. Veuillez réessayer.';

  @override
  String get profileBillReminders => 'Rappels de factures';

  @override
  String get ratingOrderQuestion => 'Comment était votre commande ?';

  @override
  String get vendorCatalogueLoadError => 'Impossible de charger le catalogue';

  @override
  String get vendorNoItemsYet => 'Aucun article pour le moment.';

  @override
  String get vendorDefaultSection => 'Articles';

  @override
  String get vendorClosedNotice => 'Cette boutique est actuellement fermée.';

  @override
  String get forgotPasswordIntro =>
      'Saisissez votre email et nous vous enverrons\nun code de réinitialisation à 6 chiffres.';

  @override
  String voiceRecordStartFailed(String error) {
    return 'Impossible de démarrer l\'enregistrement : $error';
  }

  @override
  String voiceRecordStopFailed(String error) {
    return 'Impossible d\'arrêter l\'enregistrement : $error';
  }

  @override
  String voicePlayFailed(String error) {
    return 'Impossible de lire l\'audio : $error';
  }

  @override
  String get addressLabelRequired => 'Veuillez saisir un nom';

  @override
  String get addressRequired => 'Veuillez saisir une adresse';

  @override
  String addressAptFloor(String apartment, String floor) {
    return 'Appt : $apartment, Étage : $floor';
  }

  @override
  String get aiChatTooltip => 'Assistant IA';

  @override
  String get ordersLoadError => 'Impossible de charger les commandes';

  @override
  String get orderTypeCourier => 'Envoi de colis';

  @override
  String etaMinutes(String minutes) {
    return '$minutes minutes';
  }

  @override
  String get helpEmailUs => 'Écrivez-nous';

  @override
  String get quantity => 'Quantité';

  @override
  String restaurantShareText(
      String name, String description, String rating, String minutes) {
    return 'Découvrez $name !\n$description\nNote : $rating ⭐\nLivraison : $minutes min';
  }

  @override
  String get aiChipSpicy => '🌶 Épicé';

  @override
  String get aiChipVegetarian => '🥦 Végétarien';

  @override
  String get aiChipFast => '⚡ Rapide';

  @override
  String get aiBadgeVeg => '🥦 Végé';

  @override
  String get aiThisDish => 'ce plat';

  @override
  String get aiSearchErrorNetwork => 'Erreur réseau. Vérifiez votre connexion.';

  @override
  String get aiSearchErrorUnavailable =>
      'Service temporairement indisponible. Réessayez plus tard.';

  @override
  String get aiSearchErrorNoDish =>
      'Aucun plat reconnu sur cette photo. Essayez une image plus nette.';

  @override
  String aiSearchErrorImageTooLarge(String size) {
    return 'L\'image est trop lourde ($size Mo). Utilisez une image de moins de 10 Mo.';
  }

  @override
  String get aiSearchErrorUnknown => 'Erreur inconnue';

  @override
  String get deleteAccount => 'Supprimer mon compte';

  @override
  String get deleteAccountIntro =>
      'La suppression est définitive. Vous ne pourrez plus vous connecter avec ce compte.';

  @override
  String get deleteAccountDeletedTitle => 'Ce qui sera supprimé';

  @override
  String get deleteAccountDeletedDevices =>
      'Vos notifications et vos appareils connectés';

  @override
  String get deleteAccountKeptTitle => 'Ce qui sera gardé';

  @override
  String get deleteAccountKeptWhy =>
      'Ces informations sont conservées pour la comptabilité et en cas de litige.';

  @override
  String get deleteAccountBlockedTitle =>
      'Votre compte ne peut pas encore être supprimé';

  @override
  String get deleteAccountContactTeam => 'Contacter l\'équipe Amana';

  @override
  String get deleteAccountBlockerAdmin =>
      'C\'est un compte administrateur : il ne peut pas être supprimé depuis l\'app.';

  @override
  String deleteAccountBlockerActiveOrders(int count) {
    return 'Vous avez $count commande(s) en cours. Attendez qu\'elles soient livrées ou annulées.';
  }

  @override
  String get deleteAccountBlockerOpenDisputes =>
      'Un litige colis est encore ouvert. Attendez que l\'équipe Amana le clôture.';

  @override
  String deleteAccountBlockerDriverOrders(int count) {
    return 'Vous avez $count livraison(s) en cours. Terminez-les d\'abord.';
  }

  @override
  String get deleteAccountBlockerDriverDisputes =>
      'Un litige colis vous concernant est encore ouvert. Attendez que l\'équipe Amana le clôture.';

  @override
  String get deleteAccountBlockerDriverPayouts =>
      'Amana vous doit encore des primes. Contactez l\'équipe Amana pour solder votre compte.';

  @override
  String deleteAccountBlockerShopOrders(int count) {
    return 'Votre boutique a $count commande(s) en cours. Terminez-les ou annulez-les d\'abord.';
  }

  @override
  String deleteAccountBlockerWallet(String amount) {
    return 'Il reste $amount TND sur votre solde. Contactez l\'équipe Amana pour solder votre compte.';
  }

  @override
  String get deleteAccountBlockerSettlements =>
      'Un règlement est en attente. Contactez l\'équipe Amana pour solder votre compte.';

  @override
  String get deleteAccountBlockerUnknown =>
      'Votre compte ne peut pas être supprimé pour le moment. Contactez l\'équipe Amana.';

  @override
  String get deleteAccountConfirmWord => 'SUPPRIMER';

  @override
  String deleteAccountTypeWord(String word) {
    return 'Pour confirmer, tapez $word';
  }

  @override
  String deleteAccountWordMismatch(String word) {
    return 'Tapez exactement $word';
  }

  @override
  String get deleteAccountPasswordHint =>
      'Pour votre sécurité, entrez votre mot de passe';

  @override
  String get deleteAccountPasswordLabel => 'Mot de passe';

  @override
  String get deleteAccountGoogleHint =>
      'Pour votre sécurité, vous allez vous reconnecter avec le compte Google de ce compte.';

  @override
  String get deleteAccountSubmit => 'Supprimer définitivement mon compte';

  @override
  String get deleteAccountErrorWrongPassword => 'Mot de passe incorrect.';

  @override
  String get deleteAccountErrorOtherGoogle =>
      'Ce compte Google n\'est pas celui de ce compte Amana.';

  @override
  String get deleteAccountErrorReauth =>
      'Votre confirmation a expiré. Recommencez.';

  @override
  String get deleteAccountErrorNoMethod =>
      'Ce compte ne peut pas être confirmé dans l\'app. Contactez l\'équipe Amana.';

  @override
  String get deleteAccountErrorFailed =>
      'La suppression a échoué. Réessayez ou contactez l\'équipe Amana.';

  @override
  String get deleteAccountLoadError =>
      'Impossible de vérifier votre compte. Vérifiez votre connexion.';

  @override
  String get deleteAccountRetry => 'Réessayer';

  @override
  String get deleteAccountDoneTitle => 'Compte supprimé';

  @override
  String get deleteAccountDoneOk => 'OK';

  @override
  String get deleteAccountDeletedContact =>
      'Vos coordonnées : nom, téléphone, email et photo';

  @override
  String get deleteAccountDeletedAddresses =>
      'Vos adresses et vos destinataires enregistrés';

  @override
  String get deleteAccountDeletedPayment =>
      'Vos cartes de paiement enregistrées';

  @override
  String get deleteAccountDeletedChat =>
      'Votre historique avec l\'assistant Amana';

  @override
  String get deleteAccountKeptOrders =>
      'Vos commandes, pour la comptabilité : dates, statut, articles, montants, frais et paiements, sans rien qui vous désigne';

  @override
  String get deleteAccountKeptColis =>
      'La preuve de remise de vos colis (photos, GPS, plaque et pièce d\'identité du livreur), 30 jours après votre dernière commande, puis elle est effacée';

  @override
  String get deleteAccountAppleHint =>
      'Pour votre sécurité, vous allez vous reconnecter avec Apple.';

  @override
  String get deleteAccountDoneBody =>
      'Votre compte a été supprimé. Merci d\'avoir utilisé Amana.';

  @override
  String get deleteAccountDeletedOrderDetails =>
      'Dans vos anciennes commandes : adresses, positions GPS, téléphones, noms, notes, messages vocaux et photos de facture, y compris le nom et le téléphone des destinataires de vos colis';
}
