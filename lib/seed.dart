import 'models.dart';

const Map<String, String> brandStories = {
  'NORTH': 'NORTH makes clean, comfortable everyday wear and carry essentials. Honest fabrics, simple cuts and prices that make sense.',
  'FORME': 'FORME designs refined accessories and gadgets with a minimal look, built for daily use and made to last.',
  'CASA': 'CASA brings calm, modern pieces for the home. Neutral tones and practical design for every room.',
  'PURE': 'PURE focuses on simple personal-care and lifestyle essentials, thoughtfully selected for a better daily routine.',
};

Product _p(int id, String name, String brand, String cat, int price, int mrp, String desc,
    {List<String> sizes = const [], List<String> colors = const [], Map<String, String> specs = const {}, int stock = 25}) {
  return Product(
    id: id,
    name: name,
    brand: brand,
    category: cat,
    description: desc,
    price: price,
    mrp: mrp,
    sizes: List.of(sizes),
    colors: List.of(colors),
    specs: Map.of(specs),
    stock: stock,
    sku: 'ZN-$id',
    aboutBrand: brandStories[brand] ?? '',
  );
}

const _clothSizes = ['S', 'M', 'L', 'XL'];

List<Product> seedProducts() => [
      _p(101, 'Classic Cotton T-Shirt', 'NORTH', 'Fashion', 599, 899,
          'A soft, breathable everyday cotton T-shirt with a clean silhouette and comfortable regular fit.',
          sizes: _clothSizes,
          colors: ['Black', 'White', 'Navy'],
          specs: {'Fabric': '100% Cotton', 'Fit': 'Regular', 'Neck': 'Round neck', 'Wash care': 'Machine wash cold'}),
      _p(102, 'Minimal Everyday Hoodie', 'NORTH', 'Fashion', 1299, 1799,
          'A versatile layer with a soft inner finish, clean detailing and an easy everyday fit.',
          sizes: _clothSizes,
          colors: ['Grey', 'Black'],
          specs: {'Fabric': 'Cotton fleece', 'Fit': 'Relaxed', 'Sleeve': 'Full sleeve', 'Wash care': 'Machine wash cold'}),
      _p(103, 'Urban Crossbody Bag', 'FORME', 'Accessories', 1199, 1699,
          'A practical crossbody bag with organised storage and a timeless minimal design.',
          colors: ['Black', 'Tan'], specs: {'Material': 'Vegan leather', 'Compartments': '3', 'Closure': 'Zip'}),
      _p(104, 'Classic Analog Watch', 'FORME', 'Accessories', 1499, 2199,
          'A refined everyday timepiece with a simple dial and versatile styling.',
          colors: ['Silver', 'Black'], specs: {'Display': 'Analog', 'Strap': 'Stainless steel', 'Water resistance': '3 ATM'}),
      _p(105, 'Slim Everyday Wallet', 'FORME', 'Accessories', 749, 1099,
          'A compact wallet designed to keep your everyday essentials organised.',
          colors: ['Brown', 'Black'], specs: {'Material': 'Genuine leather', 'Card slots': '6'}),
      _p(106, 'Ceramic Table Vase', 'CASA', 'Home', 899, 1299,
          'A clean ceramic accent piece that adds a quiet, modern touch to your space.',
          colors: ['White', 'Sand'], specs: {'Material': 'Ceramic', 'Height': '22 cm'}),
      _p(107, 'Soft Glow Desk Lamp', 'CASA', 'Home', 1299, 1899,
          'A modern desk lamp for a comfortable reading and working environment.',
          colors: ['White', 'Black'], specs: {'Power': '9W LED', 'Modes': '3 brightness levels'}),
      _p(108, 'Minimal Cushion Set', 'CASA', 'Home', 699, 999,
          'A soft, neutral cushion set made to complement contemporary interiors.',
          colors: ['Beige', 'Grey'], specs: {'Pieces': '2', 'Size': '40 x 40 cm'}),
      _p(109, 'Daily Care Essentials', 'PURE', 'Essentials', 399, 599,
          'Thoughtfully selected everyday personal care essentials for your daily routine.',
          specs: {'Pack': 'Combo of 3'}),
      _p(110, 'Travel Grooming Kit', 'PURE', 'Essentials', 649, 899,
          'A compact grooming kit that keeps your routine simple at home or on the move.',
          specs: {'Pieces': '5', 'Case': 'Zip pouch'}),
      _p(111, 'Insulated Steel Bottle', 'PURE', 'Essentials', 549, 799,
          'A reusable bottle with a clean finish for daily hydration.',
          colors: ['Steel', 'Black'], specs: {'Capacity': '750 ml', 'Keeps': 'Hot 12h / Cold 24h'}),
      _p(112, 'Everyday Canvas Tote', 'NORTH', 'Fashion', 499, 749,
          'A lightweight carry-all tote for everyday errands and casual outings.',
          colors: ['Natural', 'Black'], specs: {'Material': 'Cotton canvas', 'Capacity': '15 L'}),
      _p(113, 'Wireless Earbuds', 'FORME', 'Electronics', 1799, 2999,
          'True wireless earbuds with clear sound, quick pairing and a compact charging case.',
          colors: ['Black', 'White'], specs: {'Battery': 'Up to 24h with case', 'Bluetooth': '5.3'}),
      _p(114, 'Power Bank 10000 mAh', 'NORTH', 'Electronics', 1099, 1599,
          'Slim 10000 mAh power bank with fast charging and dual output.',
          colors: ['Black'], specs: {'Capacity': '10000 mAh', 'Output': '22.5W'}),
      _p(115, 'Gentle Face Wash', 'PURE', 'Beauty', 249, 349,
          'A mild, daily face wash that cleans without drying your skin.',
          specs: {'Quantity': '100 ml', 'Skin type': 'All skin types'}),
      _p(116, 'Kids Graphic Tee', 'NORTH', 'Kids', 449, 699,
          'Soft cotton tee for kids with a fun, comfortable fit.',
          sizes: ['2-3Y', '4-5Y', '6-7Y'], colors: ['Yellow', 'Blue'], specs: {'Fabric': '100% Cotton'}),
      _p(117, 'Everyday Sneakers', 'NORTH', 'Footwear', 1599, 2499,
          'Lightweight sneakers with cushioned soles for all-day comfort.',
          sizes: ['6', '7', '8', '9', '10'], colors: ['White', 'Black'], specs: {'Sole': 'EVA', 'Upper': 'Knit mesh'}),
    ];

List<CategoryItem> seedCategories() => [
      CategoryItem(name: 'Fashion', icon: 'checkroom'),
      CategoryItem(name: 'Accessories', icon: 'watch'),
      CategoryItem(name: 'Home', icon: 'home'),
      CategoryItem(name: 'Essentials', icon: 'spa'),
      CategoryItem(name: 'Electronics', icon: 'devices'),
      CategoryItem(name: 'Beauty', icon: 'beauty'),
      CategoryItem(name: 'Kids', icon: 'kids'),
      CategoryItem(name: 'Footwear', icon: 'shoes'),
    ];

List<BannerItem> seedBanners() => [
      BannerItem(category: 'Fashion'),
      BannerItem(category: 'Accessories'),
      BannerItem(category: 'Home'),
    ];

List<Coupon> seedCoupons() => [
      Coupon(code: 'WELCOME10', title: 'Welcome offer', percent: true, value: 10, minOrder: 499),
      Coupon(code: 'FLAT100', title: 'Flat Rs 100 off', percent: false, value: 100, minOrder: 999),
    ];

List<AdminUser> seedAdmins() => [AdminUser(name: 'Owner', phone: kOwnerPhone, pin: kOwnerPin, role: 'owner')];
