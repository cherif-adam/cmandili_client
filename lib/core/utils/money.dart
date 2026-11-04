/// Arrondi monétaire : un montant que l'app calcule est un multiple de
/// [kMoneyRoundingStep] DT (50 millimes), comme une somme qu'on peut
/// vraiment payer en espèces.
///
/// Même règle que la fonction SQL `public.round_money(x)` : le multiple du pas
/// le plus proche, moitié vers le haut (en valeur absolue, comme `ROUND`) :
///   0,805 -> 0,800   0,4025 -> 0,400   1,035 -> 1,050   2,375 -> 2,400
///
/// Le serveur reste l'autorité : il lit le pas dans
/// `global_settings.money_rounding_step` (modifiable dans l'admin) et
/// réarrondit à l'insertion de la commande. Le pas fixe ci-dessous est la
/// valeur par défaut de ce réglage ; il sert à ce que l'app AFFICHE, avant la
/// commande, le montant que le serveur retiendra.
library;

/// Pas d'arrondi par défaut, en DT (valeur par défaut de
/// `global_settings.money_rounding_step`).
const double kMoneyRoundingStep = 0.05;

/// [amount] arrondi au multiple de [step] le plus proche, moitié vers le haut.
///
/// Le calcul passe par des entiers (dix-millionièmes de dinar) pour tomber du
/// même côté que Postgres, qui calcule en décimal exact : en double, 2,375 ou
/// 1,75 x 0,23 ne valent pas exactement ce qu'ils affichent. Un montant à
/// 3 décimales multiplié par un taux à 4 décimales tient en 7 décimales, et
/// reste un entier exact jusqu'à des centaines de millions de dinars.
double roundMoney(double amount, {double step = kMoneyRoundingStep}) {
  if (!amount.isFinite) return amount;
  const scale = 10000000; // 1e7 : unités de 0,0000001 DT
  final stepUnits = (step * scale).round();
  if (stepUnits <= 0) return amount;
  final units = (amount * scale).round();
  final magnitude = units.abs();
  var steps = magnitude ~/ stepUnits;
  if ((magnitude % stepUnits) * 2 >= stepUnits) steps += 1;
  final rounded = steps * stepUnits;
  return (units < 0 ? -rounded : rounded) / scale;
}

/// [a] - [b] au millime près, sans le bruit binaire des doubles
/// (3,75 - 1,9 donne 1,85 et non 1,8499999999999999).
double subtractMoney(double a, double b) =>
    ((a * 1000).round() - (b * 1000).round()) / 1000;
