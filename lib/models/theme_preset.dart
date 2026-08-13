import 'package:flutter/material.dart';

/// UI 主題預設（付費主題系統）
class ThemePreset {
  final String id;
  final String name;
  final Color seedColor;
  final bool premium; // true = 付費用戶解鎖
  final String description;

  const ThemePreset({
    required this.id,
    required this.name,
    required this.seedColor,
    required this.premium,
    required this.description,
  });
}

/// 內建主題清單
const List<ThemePreset> kThemePresets = [
  ThemePreset(
    id: 'forest',
    name: '經典森林',
    seedColor: Color(0xFF4F6B5A),
    premium: false,
    description: '穩重的森林綠，財務健康的象徵',
  ),
  ThemePreset(
    id: 'ocean',
    name: '海洋藍',
    seedColor: Color(0xFF2E5E8C),
    premium: false,
    description: '沉穩的海洋藍，冷靜與理性',
  ),
  ThemePreset(
    id: 'neon',
    name: '暗夜霓虹',
    seedColor: Color(0xFF6C4FB5),
    premium: true,
    description: '深色背景＋霓虹紫，夜貓子專屬',
  ),
  ThemePreset(
    id: 'pastel',
    name: '粉彩甜心',
    seedColor: Color(0xFFE89AA6),
    premium: true,
    description: '柔和粉彩，溫柔少女心',
  ),
  ThemePreset(
    id: 'ember',
    name: '大地暖棕',
    seedColor: Color(0xFF8B6B4F),
    premium: true,
    description: '溫暖大地色，手帳質感',
  ),
  ThemePreset(
    id: 'slate',
    name: '石墨科技',
    seedColor: Color(0xFF4A5568),
    premium: true,
    description: '低調石墨灰，極簡科技風',
  ),
  ThemePreset(
    id: 'inkwash',
    name: '水墨丹青',
    seedColor: Color(0xFF3A3A36),
    premium: true,
    description: '宣紙留白、墨韻天成，東方水墨美學',
  ),
];

ThemePreset themePresetById(String id) => kThemePresets.firstWhere(
  (preset) => preset.id == id,
  orElse: () => kThemePresets.first,
);
