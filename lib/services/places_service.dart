import 'dart:convert';
import 'dart:html'    as html;
import 'dart:js_util' as js_util;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AutocompletePrediction {
  final String placeId, description;
  AutocompletePrediction({ required this.placeId, required this.description });
}

class PlacesService {
  final String apiKey;
  final http.Client _http = http.Client();
  String _sessionToken = const Uuid().v4();

  PlacesService(this.apiKey);

  void resetSession() => _sessionToken = const Uuid().v4();

  Future<List<AutocompletePrediction>> autocomplete(String input) async {
    if (kIsWeb) {
      final jsList = await js_util.promiseToFuture<List>(
          js_util.callMethod(html.window, 'getPlacePredictions', [input, _sessionToken])
      );

      return jsList.map((jsObj) {
        final placeId    = js_util.getProperty(jsObj, 'place_id')    as String;
        final description = js_util.getProperty(jsObj, 'description') as String;
        return AutocompletePrediction(
          placeId: placeId,
          description: description,
        );
      }).toList();
    }
    // fallback mobile/server GET:
    final uri = Uri.https('maps.googleapis.com','/maps/api/place/autocomplete/json',{
      'input': input,
      'key': apiKey,
      'sessiontoken': _sessionToken,
      'components': 'country:in',
    });
    final res = await _http.get(uri);
    if (res.statusCode != 200) throw Exception(res.body);
    final data = json.decode(res.body);
    return (data['predictions'] as List).map((p) =>
        AutocompletePrediction(
          placeId:    p['place_id'],
          description:p['description'],
        )
    ).toList();
  }

  Future<LatLng> getPlaceLocation(String placeId) async {
    if (kIsWeb) {
      final jsLoc = await js_util.promiseToFuture<Object>(
          js_util.callMethod(html.window, 'getPlaceDetails', [placeId, _sessionToken])
      );
      final lat = js_util.getProperty(jsLoc, 'lat') as num;
      final lng = js_util.getProperty(jsLoc, 'lng') as num;
      return LatLng(lat.toDouble(), lng.toDouble());
    }
    // fallback mobile/server GET:
    final uri = Uri.https('maps.googleapis.com','/maps/api/place/details/json',{
      'place_id':  placeId,
      'fields':    'geometry',
      'key':       apiKey,
      'sessiontoken': _sessionToken,
    });
    final res = await _http.get(uri);
    if (res.statusCode != 200) throw Exception(res.body);
    final body = json.decode(res.body);
    final loc = body['result']['geometry']['location'];
    return LatLng(loc['lat'], loc['lng']);
  }
}
