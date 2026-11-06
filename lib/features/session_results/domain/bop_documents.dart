/// The BoP documents the app holds, oldest first (PACE-FACTORS §5.6).
///
/// Each is generated from Studio 397's PDF for that patch. Earlier patches
/// are not here: a session before the oldest document's date, or on a game
/// version none of them shipped with, has no BoP in the app.
library;

import 'bop.dart';

part 'bop_1_4_3.dart';

const List<BopDocument> bopDocuments = [bop1_4_3];
