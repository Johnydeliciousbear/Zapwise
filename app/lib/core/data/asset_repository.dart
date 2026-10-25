// Loads the bundled reference data (assets/data) and the product image catalog.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'models.dart';

/// Embedding vectors of photographed products, used for image look-up.
/// catalog_embeddings.json: `{"dim": 1280, "items": [{"product_id": "...", "vectors": ["<base64 float32>", ...]}]}`
class ProductCatalog {
  final int dim;
  final Map<String, List<Float32List>> vectors;
  const ProductCatalog(this.dim, this.vectors);

  static const empty = ProductCatalog(1280, {});

  factory ProductCatalog.fromJson(Map<String, dynamic> j) {
    final out = <String, List<Float32List>>{};
    for (final it in (j['items'] as List? ?? const [])) {
      final m = it as Map<String, dynamic>;
      out[m['product_id'] as String] = [
        for (final b in m['vectors'] as List) Uint8List.fromList(base64Decode(b as String)).buffer.asFloat32List(),
      ];
    }
    return ProductCatalog((j['dim'] ?? 1280) as int, out);
  }

  bool get isEmpty => vectors.isEmpty;
}

class ZapAssets {
  final ZapParams params;
  final List<Product> products;
  final ProductCatalog catalog;
  final Map<String, Product> byId;

  ZapAssets(this.params, this.products, this.catalog) : byId = {for (final p in products) p.id: p};

  factory ZapAssets.fromStrings(String paramsJson, String productsJson, [String? catalogJson]) {
    final params = ZapParams.fromJson(jsonDecode(paramsJson) as Map<String, dynamic>);
    final products = [
      for (final p in (jsonDecode(productsJson) as Map<String, dynamic>)['products'] as List) Product.fromJson(p as Map<String, dynamic>),
    ];
    final catalog = catalogJson == null ? ProductCatalog.empty : ProductCatalog.fromJson(jsonDecode(catalogJson) as Map<String, dynamic>);
    return ZapAssets(params, products, catalog);
  }

  static Future<ZapAssets> load([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    final params = await b.loadString('assets/data/zapwise_params.json');
    final products = await b.loadString('assets/data/products.json');
    String? catalog;
    try {
      catalog = await b.loadString('assets/data/catalog_embeddings.json');
    } catch (_) {
      catalog = null; // no product photos yet
    }
    return ZapAssets.fromStrings(params, products, catalog);
  }

  /// Seed products plus products the user registered on this phone.
  ZapAssets withUserProducts(List<Product> extra) {
    final merged = [...products];
    for (final p in extra) {
      merged.removeWhere((q) => q.id == p.id);
      merged.add(p);
    }
    return ZapAssets(params, merged, catalog);
  }
}
