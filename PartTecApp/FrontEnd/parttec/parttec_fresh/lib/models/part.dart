class Part {
  final String id;
  final String name;
  final String? manufacturer;
  final String model;
  final int year;
  final String fuelType;
  final String status;
  final double price;
  final String _imageUrl; // جعل متغيرة الرابط خاصة
  final String category;
  final String? serialNumber;
  final String? description;
  final double averageRating;
  final int reviewsCount;
  final int count;

  // رابط السيرفر الأساسي
  static const String baseUrl = 'http://187.124.131.209/';

  Part({
    required this.id,
    required this.name,
    this.manufacturer,
    required this.model,
    required this.year,
    required this.fuelType,
    required this.status,
    required this.price,
    required String imageUrl, // استقبال قيمة imageUrl
    required this.category,
    required this.count,
    this.serialNumber,
    this.description,
    this.averageRating = 0.0,
    this.reviewsCount = 0,
  }) : _imageUrl = imageUrl; // إسنادها للمتغير الخاص

  // Getter لإرجاع رابط الصورة كاملاً بشكل دائم
  String get imageUrl {
    if (_imageUrl.isEmpty) return '';
    
    // إذا كان الرابط يحتوي بالفعل على http أو https نرجعه كما هو
    if (_imageUrl.startsWith('http://') || _imageUrl.startsWith('https://')) {
      return _imageUrl;
    }
    
    // تنظيف السلاش الزائد من بداية مسار الصورة
    final cleanPath = _imageUrl.startsWith('/') ? _imageUrl.substring(1) : _imageUrl;
    return '$baseUrl$cleanPath';
  }

  static double _asDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim()) ?? 0.0;
    return 0.0;
  }

  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim()) ?? 0;
    return 0;
  }

  factory Part.fromJson(Map<String, dynamic> json) {
    return Part(
      id: (json['_id'] ?? json['id'])?.toString() ?? '',
      name: json['name'] ?? '',
      manufacturer: json['manufacturer'],
      model: json['model'] ?? '',
      year: _asInt(json['year']),
      fuelType: json['fuelType'] ?? json['fuel_type'] ?? '',
      status: json['status'] ?? '',
      price: _asDouble(json['price']),
      imageUrl: json['imageUrl'] ?? json['image_url'] ?? '',
      category: json['category'] ?? '',
      count: _asInt(json['count']),
      serialNumber: json['serialNumber'] ?? json['serial_number'],
      description: json['description'],
      averageRating: _asDouble(
        json['averageRating'] ?? json['avgRating'] ?? json['rating'],
      ),
      reviewsCount: _asInt(
        json['reviewsCount'] ?? json['ratingsCount'] ?? json['numReviews'],
      ),
    );
  }
}