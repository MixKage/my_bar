enum MeasurementSystem { flOz, ml, cl }

extension MeasurementSystemX on MeasurementSystem {
  String get storageValue {
    switch (this) {
      case MeasurementSystem.flOz:
        return 'fl_oz';
      case MeasurementSystem.ml:
        return 'ml';
      case MeasurementSystem.cl:
        return 'cl';
    }
  }

  static MeasurementSystem fromStorage(String? rawValue) {
    switch (rawValue) {
      case 'ml':
        return MeasurementSystem.ml;
      case 'cl':
        return MeasurementSystem.cl;
      case 'fl_oz':
      default:
        return MeasurementSystem.flOz;
    }
  }
}
