/// 都市・国名と3レターコードの対応表
/// キーは全て小文字で登録すること
const Map<String, String> cityCodes = {
  // ==========================================
  // 🇯🇵 日本 (Japan)
  // ==========================================
  // 主要都市
  'tokyo': 'TYO', '東京': 'TYO', 'とうきょう': 'TYO',
  'haneda': 'HND', '羽田': 'HND',
  'narita': 'NRT', '成田': 'NRT',
  'osaka': 'OSA', '大阪': 'OSA', 'おおさか': 'OSA',
  'kix': 'KIX', 'kansai': 'KIX', '関西': 'KIX', '関空': 'KIX',
  'itami': 'ITM', '伊丹': 'ITM',
  'kyoto': 'KYO', '京都': 'KYO', 'きょうと': 'KYO',
  'sapporo': 'SPK', '札幌': 'SPK', 'さっぽろ': 'SPK',
  'chitose': 'CTS', 'new chitose': 'CTS', '新千歳': 'CTS', '千歳': 'CTS',
  'fukuoka': 'FUK', '福岡': 'FUK', 'ふくおか': 'FUK', 'hakata': 'FUK', '博多': 'FUK',
  'nagoya': 'NGO', '名古屋': 'NGO', 'なごや': 'NGO',
  'centrair': 'NGO', 'chubu': 'NGO', '中部': 'NGO', 'セントレア': 'NGO',
  'okinawa': 'OKA', '沖縄': 'OKA', 'おきなわ': 'OKA',
  'naha': 'OKA', '那覇': 'OKA', 'なは': 'OKA',
  
  // 地方都市・観光地
  'ishigaki': 'ISG', '石垣': 'ISG',
  'miyako': 'MMY', '宮古': 'MMY',
  'sendai': 'SDJ', '仙台': 'SDJ',
  'hiroshima': 'HIJ', '広島': 'HIJ',
  'kagoshima': 'KOJ', '鹿児島': 'KOJ',
  'kumamoto': 'KMJ', '熊本': 'KMJ',
  'nagasaki': 'NGS', '長崎': 'NGS',
  'kobe': 'UKB', '神戸': 'UKB',
  'shizuoka': 'FSZ', '静岡': 'FSZ', '富士山': 'FSZ', 'mt fuji': 'FSZ',
  'kanazawa': 'KMQ', '金沢': 'KMQ',
  'komatsu': 'KMQ', '小松': 'KMQ',
  'matsuyama': 'MYJ',
  'takamatsu': 'TAK', '高松': 'TAK',
  'kochi': 'KCZ', '高知': 'KCZ',
  'miyazaki': 'KMI', '宮崎': 'KMI',
  'oita': 'OIT', '大分': 'OIT', 'beppu': 'OIT', '別府': 'OIT',
  'hakodate': 'HKD', '函館': 'HKD',
  'asahikawa': 'AKJ', '旭川': 'AKJ',
  'aomori': 'AOJ', '青森': 'AOJ',
  'akita': 'AXT', '秋田': 'AXT',
  'niigata': 'KIJ', '新潟': 'KIJ',
  'toyama': 'TOY', '富山': 'TOY',
  'okayama': 'OKJ', '岡山': 'OKJ',
  'izumo': 'IZO', '出雲': 'IZO',

  // ==========================================
  // 🌏 アジア (Asia)
  // ==========================================
  // 韓国
  'seoul': 'SEL', 'ソウル': 'SEL',
  'incheon': 'ICN', '仁川': 'ICN', 'インチョン': 'ICN',
  'gimpo': 'GMP', '金浦': 'GMP',
  'busan': 'PUS', '釜山': 'PUS', 'プサン': 'PUS',
  'jeju': 'CJU', '済州': 'CJU', 'チェジュ': 'CJU',
  'daegu': 'TAE', '大邱': 'TAE',

  // 台湾
  'taipei': 'TPE', '台北': 'TPE', 'タイペイ': 'TPE',
  'songshan': 'TSA',
  'kaohsiung': 'KHH', '高雄': 'KHH',

  // 中国・香港・マカオ
  'hong kong': 'HKG', '香港': 'HKG', 'ホンコン': 'HKG',
  'macau': 'MFM', 'マカオ': 'MFM',
  'shanghai': 'SHA', '上海': 'SHA', 'シャンハイ': 'SHA',
  'pudong': 'PVG', '浦東': 'PVG',
  'beijing': 'BJS', '北京': 'BJS', 'ペキン': 'BJS',
  'guangzhou': 'CAN', '広州': 'CAN',
  'dalian': 'DLC', '大連': 'DLC',

  // 東南アジア
  'bangkok': 'BKK', 'バンコク': 'BKK',
  'don mueang': 'DMK', 'ドンムアン': 'DMK',
  'phuket': 'HKT', 'プーケット': 'HKT',
  'chiang mai': 'CNX', 'チェンマイ': 'CNX',
  'singapore': 'SIN', 'シンガポール': 'SIN',
  'kuala lumpur': 'KUL', 'クアラルンプール': 'KUL',
  'penang': 'PEN', 'ペナン': 'PEN',
  'kota kinabalu': 'BKI', 'コタキナバル': 'BKI',
  'ho chi minh': 'SGN', 'ホーチミン': 'SGN',
  'hanoi': 'HAN', 'ハノイ': 'HAN',
  'da nang': 'DAD', 'ダナン': 'DAD',
  'manila': 'MNL', 'マニラ': 'MNL',
  'cebu': 'CEB', 'セブ': 'CEB',
  'jakarta': 'JKT', 'ジャカルタ': 'JKT',
  'bali': 'DPS', 'バリ': 'DPS',
  'denpasar': 'DPS', 'デンパサール': 'DPS',
  'siem reap': 'REP', 'シェムリアップ': 'REP', 'angkor wat': 'REP', 'アンコールワット': 'REP',
  'phnom penh': 'PNH', 'プノンペン': 'PNH',
  
  // 南アジア・その他
  'new delhi': 'DEL', 'デリー': 'DEL',
  'mumbai': 'BOM', 'ムンバイ': 'BOM',
  'male': 'MLE', 'maldives': 'MLE', 'モルディブ': 'MLE', 'マレ': 'MLE',
  'colombo': 'CMB', 'コロンボ': 'CMB', 'sri lanka': 'CMB', 'スリランカ': 'CMB',
  'kathmandu': 'KTM', 'カトマンズ': 'KTM',
  'ulaanbaatar': 'UBN', 'ウランバートル': 'UBN',

  // ==========================================
  // 🗽 北米・ハワイ (North America)
  // ==========================================
  'new york': 'NYC', 'ニューヨーク': 'NYC',
  'jfk': 'JFK',
  'newark': 'EWR',
  'los angeles': 'LAX', 'ロサンゼルス': 'LAX', 'ロス': 'LAX',
  'san francisco': 'SFO', 'サンフランシスコ': 'SFO',
  'las vegas': 'LAS', 'ラスベガス': 'LAS',
  'seattle': 'SEA', 'シアトル': 'SEA',
  'chicago': 'CHI', 'シカゴ': 'CHI',
  'ohare': 'ORD',
  'boston': 'BOS', 'ボストン': 'BOS',
  'washington': 'WAS', 'ワシントン': 'WAS',
  'miami': 'MIA', 'マイアミ': 'MIA',
  'orlando': 'MCO', 'オーランド': 'MCO', 'disney world': 'MCO',
  'honolulu': 'HNL', 'ホノルル': 'HNL',
  'hawaii': 'HNL', 'ハワイ': 'HNL',
  'kona': 'KOA', 'コナ': 'KOA',
  'guam': 'GUM', 'グアム': 'GUM',
  'saipan': 'SPN', 'サイパン': 'SPN',
  'vancouver': 'YVR', 'バンクーバー': 'YVR',
  'toronto': 'YYZ', 'トロント': 'YYZ',
  'montreal': 'YUL', 'モントリオール': 'YUL',
  'mexico city': 'MEX', 'メキシコシティ': 'MEX',
  'cancun': 'CUN', 'カンクン': 'CUN',

  // ==========================================
  // 🏰 ヨーロッパ (Europe)
  // ==========================================
  'london': 'LON', 'ロンドン': 'LON',
  'heathrow': 'LHR', 'ヒースロー': 'LHR',
  'paris': 'PAR', 'パリ': 'PAR',
  'charles de gaulle': 'CDG',
  'rome': 'ROM', 'ローマ': 'ROM',
  'fiumicino': 'FCO',
  'milan': 'MIL', 'ミラノ': 'MIL',
  'venice': 'VCE', 'ベネチア': 'VCE', 'ヴェネツィア': 'VCE',
  'florence': 'FLR', 'フィレンツェ': 'FLR',
  'frankfurt': 'FRA', 'フランクフルト': 'FRA',
  'munich': 'MUC', 'ミュンヘン': 'MUC',
  'berlin': 'BER', 'ベルリン': 'BER',
  'barcelona': 'BCN', 'バルセロナ': 'BCN',
  'madrid': 'MAD', 'マドリード': 'MAD',
  'amsterdam': 'AMS', 'アムステルダム': 'AMS',
  'zurich': 'ZRH', 'チューリッヒ': 'ZRH',
  'geneva': 'GVA', 'ジュネーブ': 'GVA',
  'vienna': 'VIE', 'ウィーン': 'VIE',
  'brussels': 'BRU', 'ブリュッセル': 'BRU',
  'copenhagen': 'CPH', 'コペンハーゲン': 'CPH',
  'stockholm': 'STO', 'ストックホルム': 'STO',
  'helsinki': 'HEL', 'ヘルシンキ': 'HEL',
  'oslo': 'OSL', 'オスロ': 'OSL',
  'athens': 'ATH', 'アテネ': 'ATH',
  'santorini': 'JTR', 'サントリーニ': 'JTR',
  'istanbul': 'IST', 'イスタンブール': 'IST',
  'dublin': 'DUB', 'ダブリン': 'DUB',
  'prague': 'PRG', 'プラハ': 'PRG',
  'budapest': 'BUD', 'ブダペスト': 'BUD',
  'lisbon': 'LIS', 'リスボン': 'LIS',
  'warsaw': 'WAW', 'ワルシャワ': 'WAW',
  'edinburgh': 'EDI', 'エディンバラ': 'EDI',

  // ==========================================
  // 🐨 オセアニア (Oceania)
  // ==========================================
  'sydney': 'SYD', 'シドニー': 'SYD',
  'melbourne': 'MEL', 'メルボルン': 'MEL',
  'brisbane': 'BNE', 'ブリスベン': 'BNE',
  'gold coast': 'OOL', 'ゴールドコースト': 'OOL',
  'cairns': 'CNS', 'ケアンズ': 'CNS',
  'perth': 'PER', 'パース': 'PER',
  'auckland': 'AKL', 'オークランド': 'AKL',
  'christchurch': 'CHC', 'クライストチャーチ': 'CHC',
  'queenstown': 'ZQN', 'クイーンズタウン': 'ZQN',
  'fiji': 'NAN', 'nadi': 'NAN', 'フィジー': 'NAN',
  'tahiti': 'PPT', 'papeete': 'PPT', 'タヒチ': 'PPT',
  'noumea': 'NOU', 'ヌメア': 'NOU', 'new caledonia': 'NOU',

  // ==========================================
  // 🐫 中東・アフリカ (Middle East / Africa)
  // ==========================================
  'dubai': 'DXB', 'ドバイ': 'DXB',
  'abu dhabi': 'AUH', 'アブダビ': 'AUH',
  'doha': 'DOH', 'ドーハ': 'DOH',
  'cairo': 'CAI', 'カイロ': 'CAI', 'egypt': 'CAI',
  'johannesburg': 'JNB', 'ヨハネスブルグ': 'JNB',
  'cape town': 'CPT', 'ケープタウン': 'CPT',
  'casablanca': 'CMN', 'カサブランカ': 'CMN', 'morocco': 'CMN',
  'marrakech': 'RAK', 'マラケシュ': 'RAK',

  // ==========================================
  // 💃 南米 (South America)
  // ==========================================
  'sao paulo': 'GRU', 'サンパウロ': 'GRU',
  'rio de janeiro': 'GIG', 'リオデジャネイロ': 'GIG', 'リオ': 'GIG',
  'buenos aires': 'EZE', 'ブエノスアイレス': 'EZE',
  'santiago': 'SCL', 'サンティアゴ': 'SCL',
  'lima': 'LIM', 'リマ': 'LIM',
  'cusco': 'CUZ', 'クスコ': 'CUZ', 'machu picchu': 'CUZ', 'マチュピチュ': 'CUZ',
  'bogota': 'BOG', 'ボゴタ': 'BOG',
};