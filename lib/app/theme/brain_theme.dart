import 'package:material_ui/material_ui.dart';

/// A named dark palette for brain. All themes are dark — that is the brand.
class BrainTheme {
  const BrainTheme({
    required this.name,
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.text,
    required this.textDim,
    required this.accent,
    required this.codeBg,
    required this.green,
    required this.red,
    required this.yellow,
    required this.blue,
    required this.purple,
    required this.orange,
    required this.cyan,
  });

  final String name;
  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color text;
  final Color textDim;
  final Color accent;
  final Color codeBg;
  final Color green;
  final Color red;
  final Color yellow;
  final Color blue;
  final Color purple;
  final Color orange;
  final Color cyan;

  /// Maps a callout `> [!type]` name to a semantic color.
  Color calloutColor(String type) => switch (type) {
    'info' || 'note' || 'todo' => blue,
    'tip' || 'hint' || 'success' || 'check' || 'done' => green,
    'warning' || 'caution' || 'attention' => yellow,
    'danger' || 'error' || 'fail' || 'failure' || 'bug' => red,
    'important' => purple,
    'question' || 'help' || 'faq' => cyan,
    'quote' || 'cite' || 'example' => textDim,
    _ => accent,
  };
}

const githubDark = BrainTheme(
  name: 'GitHub Dark',
  bg: Color(0xFF0D1117),
  surface: Color(0xFF161B22),
  surfaceAlt: Color(0xFF21262D),
  border: Color(0xFF30363D),
  text: Color(0xFFE6EDF3),
  textDim: Color(0xFF7D8590),
  accent: Color(0xFF58A6FF),
  codeBg: Color(0xFF161B22),
  green: Color(0xFF3FB950),
  red: Color(0xFFF85149),
  yellow: Color(0xFFD29922),
  blue: Color(0xFF58A6FF),
  purple: Color(0xFFBC8CFF),
  orange: Color(0xFFD18616),
  cyan: Color(0xFF39C5CF),
);

const tokyoNight = BrainTheme(
  name: 'Tokyo Night',
  bg: Color(0xFF1A1B26),
  surface: Color(0xFF24283B),
  surfaceAlt: Color(0xFF1F2335),
  border: Color(0xFF292E42),
  text: Color(0xFFC0CAF5),
  textDim: Color(0xFF565F89),
  accent: Color(0xFF7AA2F7),
  codeBg: Color(0xFF1F2335),
  green: Color(0xFF9ECE6A),
  red: Color(0xFFF7768E),
  yellow: Color(0xFFE0AF68),
  blue: Color(0xFF7AA2F7),
  purple: Color(0xFFBB9AF7),
  orange: Color(0xFFFF9E64),
  cyan: Color(0xFF7DCFFF),
);

const dracula = BrainTheme(
  name: 'Dracula',
  bg: Color(0xFF282A36),
  surface: Color(0xFF44475A),
  surfaceAlt: Color(0xFF343746),
  border: Color(0xFF44475A),
  text: Color(0xFFF8F8F2),
  textDim: Color(0xFF6272A4),
  accent: Color(0xFFBD93F9),
  codeBg: Color(0xFF21222C),
  green: Color(0xFF50FA7B),
  red: Color(0xFFFF5555),
  yellow: Color(0xFFF1FA8C),
  blue: Color(0xFF8BE9FD),
  purple: Color(0xFFBD93F9),
  orange: Color(0xFFFFB86C),
  cyan: Color(0xFF8BE9FD),
);

const gruvbox = BrainTheme(
  name: 'Gruvbox',
  bg: Color(0xFF282828),
  surface: Color(0xFF3C3836),
  surfaceAlt: Color(0xFF32302F),
  border: Color(0xFF504945),
  text: Color(0xFFEBDBB2),
  textDim: Color(0xFFA89984),
  accent: Color(0xFFFABD2F),
  codeBg: Color(0xFF32302F),
  green: Color(0xFFB8BB26),
  red: Color(0xFFFB4934),
  yellow: Color(0xFFFABD2F),
  blue: Color(0xFF83A598),
  purple: Color(0xFFD3869B),
  orange: Color(0xFFFE8019),
  cyan: Color(0xFF8EC07C),
);

const catppuccinMocha = BrainTheme(
  name: 'Catppuccin Mocha',
  bg: Color(0xFF1E1E2E),
  surface: Color(0xFF313244),
  surfaceAlt: Color(0xFF181825),
  border: Color(0xFF45475A),
  text: Color(0xFFCDD6F4),
  textDim: Color(0xFF6C7086),
  accent: Color(0xFF89B4FA),
  codeBg: Color(0xFF181825),
  green: Color(0xFFA6E3A1),
  red: Color(0xFFF38BA8),
  yellow: Color(0xFFF9E2AF),
  blue: Color(0xFF89B4FA),
  purple: Color(0xFFCBA6F7),
  orange: Color(0xFFFAB387),
  cyan: Color(0xFF94E2D5),
);

const nord = BrainTheme(
  name: 'Nord',
  bg: Color(0xFF2E3440),
  surface: Color(0xFF3B4252),
  surfaceAlt: Color(0xFF434C5E),
  border: Color(0xFF4C566A),
  text: Color(0xFFECEFF4),
  textDim: Color(0xFF81A1C1),
  accent: Color(0xFF88C0D0),
  codeBg: Color(0xFF3B4252),
  green: Color(0xFFA3BE8C),
  red: Color(0xFFBF616A),
  yellow: Color(0xFFEBCB8B),
  blue: Color(0xFF81A1C1),
  purple: Color(0xFFB48EAD),
  orange: Color(0xFFD08770),
  cyan: Color(0xFF8FBCBB),
);

const brainThemes = <BrainTheme>[
  githubDark,
  tokyoNight,
  dracula,
  gruvbox,
  catppuccinMocha,
  nord,
];

const defaultThemeName = 'GitHub Dark';
