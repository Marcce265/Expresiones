import 'package:flutter/material.dart';

typedef CheckoutFieldIconOption = ({String key, IconData icon, String label});

abstract final class CheckoutFieldIcons {
  static const fallbackKey = 'edit';

  static const options = <CheckoutFieldIconOption>[
    (key: 'edit', icon: Icons.edit_note_rounded, label: 'General'),
    (key: 'badge', icon: Icons.badge_outlined, label: 'Documento'),
    (key: 'person', icon: Icons.person_outline_rounded, label: 'Persona'),
    (key: 'place', icon: Icons.place_outlined, label: 'Ubicación'),
    (key: 'home', icon: Icons.home_outlined, label: 'Dirección'),
    (key: 'gift', icon: Icons.card_giftcard_outlined, label: 'Regalo'),
    (key: 'palette', icon: Icons.palette_outlined, label: 'Color'),
    (key: 'celebration', icon: Icons.celebration_outlined, label: 'Ocasión'),
    (key: 'notes', icon: Icons.notes_rounded, label: 'Indicaciones'),
  ];

  static IconData resolve(String key) {
    for (final option in options) {
      if (option.key == key) return option.icon;
    }
    return options.first.icon;
  }
}
