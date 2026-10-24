// Themed word lists for Twist boards.
//
// Why hand-written: the game targets all ages, so every word is a common, concrete,
// family-friendly noun a 9-year-old knows (no proper nouns, nothing scary or rude,
// no plurals, no palindromes — a palindrome reads the same both ways and could never
// have a single tracing). Each list is grouped by length (4 → 8) so the spread is easy
// to eyeball; the generator picks words whose lengths match its path cuts, and
// test/games/twist/word_bank_test.dart enforces these rules.
//
// Order matters: the generator draws from these lists with a seeded Random, so editing
// a list changes the puzzle produced for a given seed (fine between releases, but never
// rely on old seeds reproducing old boards after an edit).

/// Shortest word length in the bank (the smallest `TwistParams.minLen` allowed).
const int kTwistMinWordLength = 4;

/// Longest word length in the bank (the largest `TwistParams.maxLen` allowed).
const int kTwistMaxWordLength = 8;

// The formatter would put every word on its own line; keep the length groups instead.
// dart format off
/// Theme name (shown to the player) → upper-case A–Z words of length 4..8.
const Map<String, List<String>> kWordThemes = {
  'Ocean': [
    'FISH', 'CRAB', 'WAVE', 'TIDE', 'REEF', 'SAND', 'SHIP', 'BOAT', 'KELP', 'SEAL',
    'CLAM', 'SURF', 'FOAM', 'PIER', 'GULL', 'TUNA', 'SAIL', 'ORCA', 'RAFT',
    'SHELL', 'WHALE', 'SHARK', 'SQUID', 'PEARL', 'CORAL', 'BEACH', 'OCEAN', 'OTTER',
    'CANOE', 'YACHT', 'PRAWN', 'SHORE', 'COAST', 'DIVER', 'FERRY', 'WATER',
    'ANCHOR', 'OYSTER', 'MUSSEL', 'TURTLE', 'SHRIMP', 'ISLAND', 'LAGOON',
    'PIRATE', 'SAILOR', 'WALRUS', 'PUFFIN', 'SALMON', 'PEBBLE', 'SPONGE',
    'LOBSTER', 'DOLPHIN', 'SEAWEED', 'OCTOPUS', 'CURRENT', 'CAPTAIN', 'PELICAN',
    'MERMAID', 'SNORKEL', 'MANATEE',
    'SEAHORSE', 'STARFISH', 'SEASHORE', 'SAILBOAT', 'LIFEBOAT', 'SEASHELL',
    'BLOWFISH', 'FLOUNDER', 'SEAFLOOR',
  ],
  'Animals': [
    'BEAR', 'LION', 'WOLF', 'DEER', 'FROG', 'GOAT', 'LAMB', 'DUCK', 'MOLE', 'HARE',
    'SWAN', 'CROW', 'CALF', 'PONY', 'TOAD', 'FOAL', 'MOTH',
    'HORSE', 'TIGER', 'ZEBRA', 'CAMEL', 'MOUSE', 'SHEEP', 'PANDA', 'KOALA', 'LLAMA',
    'EAGLE', 'BISON', 'MOOSE', 'LEMUR', 'SLOTH', 'STORK', 'ROBIN', 'GOOSE', 'PUPPY',
    'BUNNY', 'HIPPO', 'RHINO',
    'MONKEY', 'RABBIT', 'DONKEY', 'PARROT', 'JAGUAR', 'BADGER', 'GERBIL', 'KITTEN',
    'PIGEON', 'FALCON', 'IGUANA', 'LIZARD', 'ALPACA', 'TOUCAN',
    'HAMSTER', 'GORILLA', 'GIRAFFE', 'CHEETAH', 'OSTRICH', 'PENGUIN', 'LEOPARD',
    'RACCOON', 'CHICKEN', 'BUFFALO', 'PANTHER',
    'HEDGEHOG', 'SQUIRREL', 'ELEPHANT', 'KANGAROO', 'TORTOISE', 'ANTELOPE',
    'FLAMINGO', 'REINDEER', 'CHIPMUNK',
  ],
  'Food': [
    'CAKE', 'RICE', 'MILK', 'SOUP', 'CORN', 'BEAN', 'PEAR', 'PLUM', 'LIME', 'KIWI',
    'TACO', 'ROLL', 'TOFU', 'LEEK', 'KALE', 'MINT',
    'BREAD', 'APPLE', 'LEMON', 'MANGO', 'GRAPE', 'PEACH', 'MELON', 'HONEY', 'PIZZA',
    'PASTA', 'SALAD', 'TOAST', 'CREAM', 'JUICE', 'OLIVE', 'BERRY', 'CANDY', 'FUDGE',
    'BAGEL', 'ONION',
    'CHEESE', 'BUTTER', 'CARROT', 'POTATO', 'TOMATO', 'BANANA', 'CHERRY', 'ORANGE',
    'WAFFLE', 'COOKIE', 'MUFFIN', 'NOODLE', 'CELERY', 'PEPPER', 'CEREAL', 'PICKLE',
    'RAISIN', 'BURGER', 'PEANUT', 'RADISH',
    'PANCAKE', 'CUPCAKE', 'PUDDING', 'POPCORN', 'PRETZEL', 'LETTUCE', 'CABBAGE',
    'SPINACH', 'AVOCADO', 'COCONUT', 'APRICOT', 'PUMPKIN', 'SAUSAGE', 'CRACKER',
    'DESSERT',
    'SANDWICH', 'BROCCOLI', 'MEATBALL', 'CUCUMBER', 'DUMPLING', 'MUSHROOM',
    'MEATLOAF', 'TORTILLA', 'CHESTNUT', 'HAZELNUT',
  ],
  'Space': [
    'STAR', 'MOON', 'DUST', 'RING', 'BEAM', 'ROCK', 'CREW', 'BASE', 'FUEL', 'LENS',
    'GLOW', 'DAWN', 'DOME',
    'COMET', 'ORBIT', 'ALIEN', 'SPACE', 'PROBE', 'ROVER', 'LIGHT', 'GLOBE', 'HATCH',
    'LASER', 'RADIO', 'FLARE', 'ROBOT', 'PILOT', 'CLOUD', 'CABIN',
    'PLANET', 'GALAXY', 'NEBULA', 'ROCKET', 'CRATER', 'SIGNAL', 'MODULE', 'HELMET',
    'LAUNCH', 'ENGINE', 'METEOR', 'COSMOS', 'SUNSET',
    'SHUTTLE', 'ORBITER', 'ECLIPSE', 'GRAVITY', 'CAPSULE', 'SUNRISE', 'ANTENNA',
    'STATION', 'MISSION', 'SUNSPOT',
    'ASTEROID', 'MOONBEAM', 'STARDUST', 'CRESCENT', 'UNIVERSE', 'MOONWALK',
    'STARSHIP', 'SUNLIGHT', 'MOONRISE',
  ],
  'Weather': [
    'RAIN', 'SNOW', 'HAIL', 'WIND', 'MIST', 'HEAT', 'GALE', 'HAZE', 'GUST', 'BOLT',
    'COAT', 'BOOT', 'KITE', 'SLED', 'DROP', 'THAW',
    'CLOUD', 'STORM', 'FROST', 'SLEET', 'FLOOD', 'CHILL', 'DRIFT', 'FLAKE', 'SCARF',
    'GLOVE', 'SLUSH', 'SHADE',
    'BREEZE', 'SHOWER', 'PUDDLE', 'ICICLE', 'SUMMER', 'WINTER', 'SPRING', 'AUTUMN',
    'SEASON', 'MITTEN', 'WARMTH',
    'RAINBOW', 'THUNDER', 'DRIZZLE', 'TORNADO', 'PARASOL', 'MONSOON', 'CLIMATE',
    'WEATHER', 'SNOWMAN', 'SUNBEAM', 'DEWDROP',
    'FORECAST', 'SNOWBALL', 'SNOWFALL', 'RAINDROP', 'RAINCOAT', 'UMBRELLA',
    'SUNSHINE', 'BLIZZARD', 'RAINFALL', 'HEATWAVE', 'SNOWSUIT',
  ],
  'Music': [
    'DRUM', 'HARP', 'BAND', 'SONG', 'TUNE', 'NOTE', 'BEAT', 'HORN', 'BELL', 'GONG',
    'OBOE', 'SOLO', 'DUET', 'BASS', 'JAZZ', 'ROCK', 'TUBA', 'PIPE',
    'PIANO', 'FLUTE', 'CELLO', 'BANJO', 'CHOIR', 'CHORD', 'MUSIC', 'SOUND', 'VOICE',
    'OPERA', 'DANCE', 'STAGE', 'RADIO', 'DISCO', 'BUGLE', 'ORGAN', 'KAZOO', 'VERSE',
    'SCALE',
    'GUITAR', 'VIOLIN', 'CYMBAL', 'RHYTHM', 'BALLAD', 'SINGER', 'RECORD', 'MELODY',
    'CHORUS', 'RATTLE', 'STEREO', 'ANTHEM', 'FIDDLE', 'ENCORE',
    'TRUMPET', 'CONCERT', 'SPEAKER', 'DRUMMER', 'WHISTLE', 'UKULELE', 'PIANIST',
    'PICCOLO', 'LULLABY', 'HARMONY', 'BAGPIPE', 'JUKEBOX',
    'TROMBONE', 'CLARINET', 'KEYBOARD', 'MUSICIAN', 'PLAYLIST', 'DRUMBEAT',
    'RECORDER', 'MANDOLIN', 'SONGBOOK', 'HANDBELL',
  ],
  'Sports': [
    'BALL', 'GOAL', 'TEAM', 'RACE', 'GOLF', 'JUDO', 'PUCK', 'BIKE', 'CLUB', 'RINK',
    'POOL', 'GAME', 'HOOP', 'YOGA', 'DART', 'JUMP', 'KICK',
    'TRACK', 'MEDAL', 'RUGBY', 'SKATE', 'COACH', 'FIELD', 'COURT', 'SCORE', 'CATCH',
    'RELAY', 'MATCH', 'CHESS', 'ARENA', 'BATON',
    'BOXING', 'TENNIS', 'KARATE', 'PADDLE', 'RACKET', 'HOCKEY', 'SOCCER', 'TROPHY',
    'PLAYER', 'SPRINT', 'JERSEY', 'GOALIE', 'WINNER', 'HURDLE', 'ROWING', 'HELMET',
    'CRICKET', 'BOWLING', 'CYCLING', 'ARCHERY', 'REFEREE', 'STADIUM', 'GYMNAST',
    'KICKOFF', 'WHISTLE', 'ATHLETE', 'SWIMMER',
    'BASEBALL', 'FOOTBALL', 'HANDBALL', 'MARATHON', 'SOFTBALL', 'TEAMMATE',
    'HALFTIME', 'SWIMSUIT', 'CHAMPION',
  ],
  'Garden': [
    'ROSE', 'LEAF', 'SEED', 'SOIL', 'TREE', 'BUSH', 'POND', 'MOSS', 'VINE', 'STEM',
    'ROOT', 'BULB', 'LILY', 'WORM', 'NEST', 'HOSE', 'RAKE', 'SHED', 'PATH', 'GATE',
    'LAWN', 'HERB', 'FERN', 'TWIG',
    'TULIP', 'DAISY', 'PETAL', 'GRASS', 'SNAIL', 'SPADE', 'FENCE', 'HEDGE', 'BLOOM',
    'ACORN', 'BENCH', 'LILAC', 'POPPY', 'PLANT', 'THORN', 'BASIL', 'SWING', 'MAPLE',
    'BIRCH', 'PATIO', 'GNOME', 'SHRUB', 'HOLLY',
    'SHOVEL', 'CLOVER', 'FLOWER', 'ORCHID', 'CACTUS', 'SPROUT', 'BRANCH', 'BEETLE',
    'BASKET', 'MEADOW', 'VIOLET', 'WILLOW', 'TOMATO', 'CARROT',
    'BLOSSOM', 'COMPOST', 'HAMMOCK', 'ORCHARD', 'BEEHIVE', 'SAPLING', 'SUNDIAL',
    'PUMPKIN', 'LETTUCE', 'ROSEBUD', 'SPINACH',
    'DAFFODIL', 'PRIMROSE', 'HONEYBEE', 'SEEDLING', 'BIRDBATH', 'LAVENDER',
    'BLUEBELL', 'SNOWDROP', 'FOUNTAIN', 'MARIGOLD', 'PINECONE', 'GARDENER',
  ],
  'Travel': [
    'TRIP', 'TAXI', 'ROAD', 'TENT', 'HIKE', 'TOUR', 'SEAT', 'GATE', 'FARE', 'CAMP',
    'BIKE', 'VIEW', 'CITY', 'TOWN', 'PARK', 'LAKE', 'TRAM', 'SHIP', 'BOAT',
    'TRAIN', 'PLANE', 'HOTEL', 'GUIDE', 'CABIN', 'FERRY', 'PILOT', 'ROUTE', 'TOWER',
    'TRAIL', 'STAMP', 'TRUNK', 'PHOTO', 'LODGE', 'BEACH', 'VISIT', 'METRO',
    'TICKET', 'BRIDGE', 'ISLAND', 'CAMERA', 'JACKET', 'CRUISE', 'SAFARI', 'CASTLE',
    'MUSEUM', 'TUNNEL', 'CANYON', 'DESERT', 'JUNGLE', 'VALLEY', 'PALACE', 'TRAVEL',
    'VOYAGE', 'PICNIC',
    'LUGGAGE', 'JOURNEY', 'AIRPORT', 'BAGGAGE', 'HIGHWAY', 'HOLIDAY', 'RAILWAY',
    'COMPASS', 'TOURIST', 'STATION', 'CARAVAN', 'SEASIDE', 'SCOOTER', 'BICYCLE',
    'SUITCASE', 'PASSPORT', 'POSTCARD', 'BACKPACK', 'SOUVENIR', 'VACATION',
    'MOUNTAIN', 'SIGNPOST', 'LANDMARK', 'SEAPLANE', 'CAMPSITE',
  ],
  'Home': [
    'DOOR', 'WALL', 'ROOF', 'SOFA', 'BATH', 'SINK', 'DESK', 'LAMP', 'OVEN', 'SOAP',
    'FORK', 'BOWL', 'DISH', 'VASE', 'HALL', 'BOOK', 'IRON', 'YARD',
    'TOWEL', 'ATTIC', 'PORCH', 'CLOCK', 'CHAIR', 'TABLE', 'FLOOR', 'STOVE', 'SHELF',
    'BROOM', 'SPOON', 'PLATE', 'GLASS', 'COUCH', 'HOUSE',
    'DRAWER', 'CARPET', 'PILLOW', 'MIRROR', 'WINDOW', 'KETTLE', 'FRIDGE', 'GARAGE',
    'CELLAR', 'CANDLE', 'LADDER', 'BUCKET', 'BASKET', 'HEATER', 'TEAPOT',
    'BLANKET', 'CURTAIN', 'TOASTER', 'FREEZER', 'HALLWAY', 'BEDROOM', 'KITCHEN',
    'BATHTUB', 'CHIMNEY', 'DOORMAT', 'LANTERN', 'CEILING', 'BALCONY', 'CUSHION',
    'DOORWAY',
    'CUPBOARD', 'BASEMENT', 'BOOKCASE', 'DOORBELL', 'BATHROOM', 'WARDROBE',
    'ARMCHAIR', 'STAIRWAY', 'PLAYROOM',
  ],
  'School': [
    'BOOK', 'DESK', 'PAGE', 'BELL', 'QUIZ', 'TEST', 'GLUE', 'TAPE', 'HALL', 'WORD',
    'POEM', 'CARD',
    'CLASS', 'CHALK', 'RULER', 'PAINT', 'LUNCH', 'STORY', 'GLOBE', 'EASEL', 'BOARD',
    'ATLAS', 'GRADE', 'MUSIC', 'ESSAY',
    'PENCIL', 'CRAYON', 'ERASER', 'FOLDER', 'LESSON', 'LOCKER', 'SCHOOL', 'MARKER',
    'PUZZLE', 'ANSWER', 'LETTER', 'NUMBER', 'ABACUS',
    'TEACHER', 'STUDENT', 'LIBRARY', 'SCIENCE', 'HISTORY', 'STAPLER', 'PROJECT',
    'CHAPTER', 'DRAWING', 'UNIFORM', 'STICKER',
    'SPELLING', 'HOMEWORK', 'NOTEBOOK', 'BACKPACK', 'ALPHABET', 'CALENDAR',
    'LUNCHBOX', 'TEXTBOOK', 'BOOKMARK', 'COMPUTER',
  ],
};
// dart format on
