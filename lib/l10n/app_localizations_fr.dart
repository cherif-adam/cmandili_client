// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Cmandili';

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
  String get pickupLocation => 'Lieu de ramassage';

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
  String get phoneInvalid => 'Veuillez entrer un numéro de téléphone valide';

  @override
  String get continueButton => 'Continuer';
}
