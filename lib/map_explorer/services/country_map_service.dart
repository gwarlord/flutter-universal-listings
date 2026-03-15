import 'package:caribtap/map_explorer/data/caribbean_countries_seed.dart';
import 'package:caribtap/map_explorer/models/country_map_config.dart';

class CountryMapService {
  List<CountryMapConfig> getSupportedCountries() {
    return caribbeanCountriesSeed.where((country) => country.supported).toList();
  }

  CountryMapConfig? getCountryById(String id) {
    final normalized = id.trim().toLowerCase();
    for (final country in caribbeanCountriesSeed) {
      if (country.id == normalized) {
        return country;
      }
    }
    return null;
  }

  CountryMapConfig? getCountryByIsoCode(String isoCode) {
    final normalized = isoCode.trim().toUpperCase();
    for (final country in caribbeanCountriesSeed) {
      if (country.isoCode == normalized) {
        return country;
      }
    }
    return null;
  }
}
