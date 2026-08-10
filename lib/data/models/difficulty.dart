import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Difficulty scale: ⭐ Beginner … ⭐⭐⭐⭐⭐ CA Final.
enum Difficulty {
  beginner,
  easy,
  intermediate,
  advanced,
  caFinal;

  static Difficulty fromString(String value) => switch (value) {
        'beginner' => beginner,
        'easy' => easy,
        'intermediate' => intermediate,
        'advanced' => advanced,
        'ca_final' => caFinal,
        _ => easy,
      };

  int get stars => index + 1;

  String get label => switch (this) {
        beginner => 'Beginner',
        easy => 'Easy',
        intermediate => 'Intermediate',
        advanced => 'Advanced',
        caFinal => 'CA Final',
      };

  String get starsLabel => '⭐' * stars;

  Color get accent => switch (this) {
        beginner => AppColors.diffBeginner,
        easy => AppColors.diffEasy,
        intermediate => AppColors.diffIntermediate,
        advanced => AppColors.diffAdvanced,
        caFinal => AppColors.diffCaFinal,
      };
}
