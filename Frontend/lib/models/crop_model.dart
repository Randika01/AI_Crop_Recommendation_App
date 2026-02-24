class Crop {
  final String id;
  final String name;
  final String imagePath;
  final String description;

  Crop({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.description,
  });
}

// Sample crop data
List<Crop> sampleCrops = [
  Crop(
    id: 'c1',
    name: 'Tomato',
    imagePath: 'assets/images/crops/c1.png',
    description: 'C1',
  ),
  Crop(
    id: 'c2',
    name: 'Potato',
    imagePath: 'assets/images/crops/c2.png',
    description: 'C2',
  ),
  Crop(
    id: 'c3',
    name: 'Carrot',
    imagePath: 'assets/images/crops/c3.png',
    description: 'C3',
  ),
  Crop(
    id: 'c4',
    name: 'Cabbage',
    imagePath: 'assets/images/crops/c4.png',
    description: 'C4',
  ),
];
