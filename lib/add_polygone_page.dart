import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';
import 'package:flutter_map_line_editor/flutter_map_line_editor.dart';
import 'package:latlong2/latlong.dart';

class PolygonPage extends StatefulWidget {
  const PolygonPage({super.key});

  @override
  State<PolygonPage> createState() => _PolygonPageState();
}

class _PolygonPageState extends State<PolygonPage> {
  // L'éditeur de polygones, utilisé pour ajouter/modifier des points sur un polygone.
  late PolyEditor polyEditor;

  // Polygone temporaire en cours de dessin par l'utilisateur.
  var drawTempPolygon = Polygon(color: Colors.green, points: <LatLng>[]);

  // Liste des polygones ajoutés et sauvegardés.
  final List<Polygon> addedPolygons = [];

  // Polygone actuellement sélectionné (si un clic sur la carte détecte un polygone).
  Polygon? selectedPolygon;

  @override
  void initState() {
    super.initState();
    // Initialisation de l'éditeur avec des icônes et un rappel pour rafraîchir l'UI.
    polyEditor = PolyEditor(
      addClosePathMarker: true, // Ajoute un marqueur pour fermer le chemin du polygone.
      points: drawTempPolygon.points, // Points du polygone temporaire.
      pointIcon: const Icon(Icons.crop_square, size: 23), // Icône des points.
      intermediateIcon: const Icon(Icons.lens, size: 15, color: Colors.grey), // Icône des points intermédiaires.
      callbackRefresh: (LatLng? _) => setState(() {}), // Met à jour l'UI.
    );
  }

  // Vérifie si un point est à l'intérieur d'un polygone.
  bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
    int intersectCount = 0;
    for (int i = 0; i < polygon.length; i++) {
      LatLng a = polygon[i];
      LatLng b = polygon[(i + 1) % polygon.length];
      // Vérifie les intersections entre une ligne verticale depuis le point et les segments du polygone.
      bool intersect = ((a.latitude > point.latitude) != (b.latitude > point.latitude)) &&
          (point.longitude <
              (b.longitude - a.longitude) * (point.latitude - a.latitude) /
                  (b.latitude - a.latitude) +
                  a.longitude);
      if (intersect) intersectCount++;
    }
    // Si le nombre d'intersections est impair, le point est dans le polygone.
    return (intersectCount % 2) == 1;
  }

  // Gestion des clics sur la carte.
  void _onMapTapped(LatLng latLng) {
    Polygon? foundPolygon;
    // Recherche un polygone contenant le point cliqué.
    for (var poly in addedPolygons) {
      if (isPointInPolygon(latLng, poly.points)) {
        foundPolygon = poly;
        break;
      }
    }
    setState(() {
      selectedPolygon = foundPolygon;
      // Si aucun polygone n'est trouvé, on ajoute le point au polygone temporaire.
      if (selectedPolygon == null) {
        polyEditor.add(drawTempPolygon.points, latLng);
      }
    });
  }

  // Sauvegarde le polygone temporaire en tant que nouveau polygone.
  void _savePolygon() {
    setState(() {
      if (selectedPolygon != null) {
        addedPolygons.remove(selectedPolygon); // Remplace le polygone sélectionné, si nécessaire.
      }
      if (drawTempPolygon.points.isNotEmpty) {
        var poly = Polygon(
          points: drawTempPolygon.points.toList(),
          color: Colors.lightBlueAccent, // Couleur par défaut du polygone sauvegardé.
        );
        addedPolygons.add(poly);
        drawTempPolygon.points.clear(); // Réinitialise le polygone temporaire.
        selectedPolygon = poly;
      }
    });
  }

  // Réinitialise le polygone temporaire (annule la création en cours).
  void _resetPolygon() {
    setState(() {
      drawTempPolygon.points.clear();
      selectedPolygon = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Met à jour l'apparence des polygones pour mettre en surbrillance celui sélectionné.
    List<Polygon> displayedPolygons = addedPolygons.map((p) {
      if (p == selectedPolygon) {
        return Polygon(
          points: p.points,
          color: Colors.yellow.withOpacity(0.5), // Couleur de surbrillance.
          borderColor: Colors.yellow,
          borderStrokeWidth: 3,
        );
      }
      return p;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Constructions")),
      body: FlutterMap(
        options: MapOptions(
          onTap: (tapPos, latLng) => _onMapTapped(latLng), // Gestion des clics.
          initialCenter: LatLng(45.5231, -122.6765), // Position initiale de la carte.
          initialZoom: 10, // Niveau de zoom initial.
        ),
        children: [
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'), // Fond de carte.
          PolygonLayer(polygons: displayedPolygons), // Affiche les polygones sauvegardés.
          if (drawTempPolygon.points.isNotEmpty)
            PolygonLayer(polygons: [drawTempPolygon]), // Affiche le polygone temporaire.
          DragMarkers(markers: polyEditor.edit()), // Permet de déplacer les points.
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Bouton pour sauvegarder le polygone.
          FloatingActionButton(
            onPressed: _savePolygon,
            child: const Icon(Icons.save),
            tooltip: "Enregistrer le polygone",
          ),
          const SizedBox(height: 10),
          // Bouton pour réinitialiser le polygone temporaire.
          FloatingActionButton(
            onPressed: _resetPolygon,
            child: const Icon(Icons.refresh),
            tooltip: "Réinitialiser le polygone temporaire",
          ),
          const SizedBox(height: 10),
          // Bouton pour éditer un polygone.
          FloatingActionButton(
            onPressed: () {
              setState(() {
                if (selectedPolygon != null) {
                  polyEditor.points.clear();
                  polyEditor.points.addAll(selectedPolygon!.points); // Charge les points pour édition.
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Sélectionnez un polygone à éditer")),
                  );
                }
              });
            },
            child: const Icon(Icons.edit),
            tooltip: "Éditer un polygone",
          ),
          const SizedBox(height: 10),
          // Bouton pour supprimer un polygone.
          FloatingActionButton(
            onPressed: () {
              setState(() {
                if (selectedPolygon != null) {
                  addedPolygons.remove(selectedPolygon); // Supprime le polygone sélectionné.
                  selectedPolygon = null;
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Sélectionnez un polygone à supprimer")),
                  );
                }
              });
            },
            child: const Icon(Icons.delete),
            tooltip: "Supprimer un polygone",
          ),
        ],
      ),
    );
  }
}
