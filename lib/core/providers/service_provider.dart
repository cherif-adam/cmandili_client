import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/service_category.dart';

class SelectedServiceNotifier extends StateNotifier<ServiceType> {
  SelectedServiceNotifier() : super(ServiceType.foodDelivery);

  void selectService(ServiceType service) {
    state = service;
  }
}

final selectedServiceProvider = StateNotifierProvider<SelectedServiceNotifier, ServiceType>((ref) {
  return SelectedServiceNotifier();
});
