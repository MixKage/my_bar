// Development-only generator. Runtime localization is entirely offline.
// Run: node tool/generate_ui_translations.mjs [--check]
import fs from 'node:fs/promises';
import path from 'node:path';

const locales = ['es', 'pt', 'de', 'fr', 'it', 'tr', 'zh', 'ja', 'ko', 'hi', 'ar'];
const outputPath = 'lib/core/localization/app_translations.g.dart';
const cachePath = '.dart_tool/ui_translation_cache';
// Short UI fragments and measurement abbreviations need explicit context.
const reviewedOverrides = {
  es: {'More · {0}': 'Más · {0}', 'can': 'lata', 'twist': 'tira de piel', 'Ready only': 'Solo disponibles'},
  pt: {'More · {0}': 'Mais · {0}', 'can': 'lata', 'twist': 'tira de casca', 'Ready only': 'Só disponíveis'},
  de: {'More · {0}': 'Mehr · {0}', 'can': 'Dose', 'twist': 'Zeste'},
  fr: {'More · {0}': 'Plus · {0}', 'can': 'canette', 'twist': 'zeste'},
  it: {'More · {0}': 'Altro · {0}', 'can': 'lattina', 'twist': 'scorza'},
  tr: {'More · {0}': 'Daha fazla · {0}', 'can': 'kutu', 'twist': 'kabuk şeridi'},
  zh: {'More · {0}': '更多 · {0}', 'can': '罐', 'twist': '果皮条'},
  ja: {'More · {0}': 'その他 · {0}', 'can': '缶', 'twist': 'ツイストピール'},
  ko: {'More · {0}': '더보기 · {0}', 'can': '캔', 'twist': '과일 껍질'},
  hi: {'More · {0}': 'और · {0}', 'can': 'कैन', 'twist': 'छिलके की पट्टी'},
  ar: {'More · {0}': 'المزيد · {0}', 'can': 'علبة', 'twist': 'شريط قشر'},
};
const semanticKeys = ['Light', 'Strong', 'Long drinks', 'Shots', 'Custom', 'Medium strength', 'Non-alcoholic', 'Coupe glass', 'Wine glass', 'Irish glass', 'Collins', 'Mug', 'Goblet', 'Margarita glass', 'Martini glass', 'Pint', 'Pitcher', 'Rocks', 'Shot glass', 'Flute', 'Highball', 'Hurricane', 'Shot', 'shot', 'cup', 'wedge', 'pcs', 'drop', 'to taste', 'sprig', 'leaf', 'scoop', 'stick', 'cube', 'bottle', 'package', 'inch', 'pint', 'handful', 'dash', 'part', 'Ready only', 'Surprise me', 'Bar Menu'];
// Reviewed in cocktail/measurement context: literal word translation would turn
// "shots" into photographs, "light" into illumination, or "cl" into chlorine.
const reviewedSemanticRows = {
  es: ['Suaves', 'Fuertes', 'Tragos largos', 'Chupitos', 'Personalizados', 'Graduación media', 'Sin alcohol', 'Copa coupé', 'Copa de vino', 'Copa de café irlandés', 'Vaso Collins', 'Taza', 'Copa', 'Copa Margarita', 'Copa Martini', 'Vaso de pinta', 'Jarra', 'Vaso bajo', 'Vaso de chupito', 'Copa flauta', 'Vaso alto', 'Copa Hurricane', 'Chupito', 'chupito', 'taza', 'gajo', 'uds.', 'gota', 'al gusto', 'ramita', 'hoja', 'bola', 'rama', 'cubito', 'botella', 'paquete', 'pulg.', 'pinta', 'puñado', 'chorrito', 'parte', 'Solo disponibles', 'Sorpréndeme', 'Carta de cócteles'],
  pt: ['Leves', 'Fortes', 'Long drinks', 'Shots', 'Personalizados', 'Teor alcoólico médio', 'Sem álcool', 'Taça coupé', 'Taça de vinho', 'Taça de café irlandês', 'Copo Collins', 'Caneca', 'Cálice', 'Taça Margarita', 'Taça Martini', 'Copo de pint', 'Jarra', 'Copo baixo', 'Copo de shot', 'Taça flute', 'Copo alto', 'Taça Hurricane', 'Shot', 'shot', 'xícara', 'gomo', 'un.', 'gota', 'a gosto', 'ramo', 'folha', 'bola', 'pau', 'cubo', 'garrafa', 'pacote', 'pol.', 'pint', 'punhado', 'gota', 'parte', 'Só disponíveis', 'Surpreenda-me', 'Carta de coquetéis'],
  de: ['Leicht', 'Kräftig', 'Longdrinks', 'Shots', 'Eigene', 'Mittlere Stärke', 'Alkoholfrei', 'Coupé-Glas', 'Weinglas', 'Irish-Coffee-Glas', 'Collins-Glas', 'Becher', 'Kelch', 'Margarita-Glas', 'Martini-Glas', 'Pintglas', 'Krug', 'Tumbler', 'Schnapsglas', 'Sektflöte', 'Highball-Glas', 'Hurricane-Glas', 'Shot', 'Shot', 'Tasse', 'Spalte', 'Stk.', 'Tropfen', 'nach Geschmack', 'Zweig', 'Blatt', 'Kugel', 'Stange', 'Würfel', 'Flasche', 'Packung', 'Zoll', 'Pint', 'Handvoll', 'Spritzer', 'Teil', 'Nur verfügbare', 'Überrasche mich', 'Cocktailkarte'],
  fr: ['Légers', 'Forts', 'Long drinks', 'Shooters', 'Personnalisés', 'Force moyenne', 'Sans alcool', 'Coupe à cocktail', 'Verre à vin', 'Verre à Irish coffee', 'Verre Collins', 'Tasse', 'Coupe', 'Verre à margarita', 'Verre à martini', 'Verre à pinte', 'Pichet', 'Verre old fashioned', 'Verre à shot', 'Flûte', 'Verre highball', 'Verre hurricane', 'Shot', 'shot', 'tasse', 'quartier', 'pièce(s)', 'goutte', 'selon le goût', 'brin', 'feuille', 'boule', 'bâton', 'cube', 'bouteille', 'paquet', 'pouce', 'pinte', 'poignée', 'trait', 'mesure', 'Disponibles uniquement', 'Surprenez-moi', 'Carte des cocktails'],
  it: ['Leggeri', 'Forti', 'Long drink', 'Shot', 'Personalizzati', 'Gradazione media', 'Analcolici', 'Coppa da cocktail', 'Calice da vino', 'Bicchiere da Irish coffee', 'Bicchiere Collins', 'Tazza', 'Calice', 'Bicchiere da margarita', 'Bicchiere da martini', 'Bicchiere da pinta', 'Brocca', 'Bicchiere basso', 'Bicchiere da shot', 'Flûte', 'Bicchiere highball', 'Bicchiere hurricane', 'Shot', 'shot', 'tazza', 'spicchio', 'pz', 'goccia', 'a piacere', 'rametto', 'foglia', 'pallina', 'stecca', 'cubetto', 'bottiglia', 'confezione', 'pollice', 'pinta', 'manciata', 'spruzzo', 'parte', 'Solo disponibili', 'Sorprendimi', 'Carta dei cocktail'],
  tr: ['Hafif', 'Sert', 'Uzun içecekler', 'Shotlar', 'Özel', 'Orta sertlikte', 'Alkolsüz', 'Coupe kadehi', 'Şarap kadehi', 'İrlanda kahvesi bardağı', 'Collins bardağı', 'Kupa', 'Kadeh', 'Margarita kadehi', 'Martini kadehi', 'Pint bardağı', 'Sürahi', 'Viski bardağı', 'Shot bardağı', 'Flüt kadeh', 'Highball bardağı', 'Hurricane bardağı', 'Shot', 'shot', 'fincan', 'dilim', 'adet', 'damla', 'damak tadına göre', 'dal', 'yaprak', 'top', 'çubuk', 'küp', 'şişe', 'paket', 'inç', 'pint', 'avuç', 'birkaç damla', 'ölçü', 'Yalnızca hazırlanabilenler', 'Beni şaşırt', 'Kokteyl menüsü'],
  zh: ['低度', '高度', '长饮', '一口饮', '自定义', '中等酒精度', '无酒精', '碟形鸡尾酒杯', '葡萄酒杯', '爱尔兰咖啡杯', '柯林斯杯', '马克杯', '高脚杯', '玛格丽塔杯', '马提尼杯', '品脱杯', '调酒壶', '古典杯', '烈酒杯', '香槟笛形杯', '高球杯', '飓风杯', '一口杯', '小杯', '杯', '瓣', '个', '滴', '按口味添加', '枝', '片', '球', '根', '块', '瓶', '包', '英寸', '品脱', '把', '少许', '份', '仅可制作', '随机推荐', '鸡尾酒单'],
  ja: ['軽め', '強め', 'ロングドリンク', 'ショット', 'オリジナル', '中程度', 'ノンアルコール', 'クーペグラス', 'ワイングラス', 'アイリッシュコーヒーグラス', 'コリンズグラス', 'マグカップ', 'ゴブレット', 'マルガリータグラス', 'マティーニグラス', 'パイントグラス', 'ピッチャー', 'ロックグラス', 'ショットグラス', 'フルートグラス', 'ハイボールグラス', 'ハリケーングラス', 'ショット', 'ショット', 'カップ', '切れ', '個', '滴', 'お好みで', '枝', '枚', 'スクープ', '本', '個', '本', '袋', 'インチ', 'パイント', 'ひとつかみ', 'ダッシュ', 'パート', '今作れるものだけ', 'おまかせ', 'カクテルメニュー'],
  ko: ['낮은 도수', '높은 도수', '롱 드링크', '샷', '사용자 정의', '중간 도수', '무알코올', '쿠페 잔', '와인잔', '아이리시 커피 잔', '콜린스 잔', '머그컵', '고블릿', '마가리타 잔', '마티니 잔', '파인트 잔', '피처', '록 글라스', '샷 잔', '플루트 잔', '하이볼 잔', '허리케인 잔', '샷', '샷', '컵', '조각', '개', '방울', '기호에 따라', '줄기', '장', '스쿱', '개', '개', '병', '봉지', '인치', '파인트', '한 줌', '대시', '비율', '만들 수 있는 것만', '랜덤 추천', '칵테일 메뉴'],
  hi: ['हल्के', 'तेज़', 'लॉन्ग ड्रिंक्स', 'शॉट्स', 'कस्टम', 'मध्यम अल्कोहल', 'बिना अल्कोहल', 'कूप गिलास', 'वाइन गिलास', 'आयरिश कॉफ़ी गिलास', 'कॉलिन्स गिलास', 'मग', 'गोब्लेट', 'मार्गरीटा गिलास', 'मार्टिनी गिलास', 'पिंट गिलास', 'जग', 'रॉक्स गिलास', 'शॉट गिलास', 'फ्लूट गिलास', 'हाईबॉल गिलास', 'हरिकेन गिलास', 'शॉट', 'शॉट', 'कप', 'फाँक', 'नग', 'बूँद', 'स्वादानुसार', 'टहनी', 'पत्ता', 'स्कूप', 'डंडी', 'टुकड़ा', 'बोतल', 'पैकेट', 'इंच', 'पिंट', 'मुट्ठी', 'कुछ बूंदें', 'भाग', 'केवल उपलब्ध सामग्री वाले', 'कुछ नया सुझाएँ', 'कॉकटेल मेनू'],
  ar: ['خفيفة', 'قوية', 'مشروبات طويلة', 'شوت', 'وصفاتك', 'متوسطة القوة', 'بدون كحول', 'كأس كوبيه', 'كأس نبيذ', 'كأس قهوة أيرلندية', 'كوب كولينز', 'مج', 'كأس', 'كأس مارغريتا', 'كأس مارتيني', 'كوب باينت', 'إبريق', 'كوب روكس', 'كأس شوت', 'كأس فلوت', 'كوب هاي بول', 'كأس هاريكين', 'شوت', 'جرعة', 'كوب', 'شريحة', 'قطعة', 'قطرة', 'حسب الذوق', 'غصن', 'ورقة', 'كرة', 'عود', 'مكعب', 'زجاجة', 'عبوة', 'بوصة', 'باينت', 'حفنة', 'قطرات قليلة', 'جزء', 'القابلة للتحضير فقط', 'فاجئني', 'قائمة الكوكتيلات'],
};
const reviewedServings = {
  es: '{0} raciones', pt: '{0} porç.', de: '{0} Port.', fr: '{0} portions',
  it: '{0} porz.', tr: '{0} pors.', zh: '{0} 份', ja: '{0} 杯分', ko: '{0} 잔',
  hi: '{0} सर्विंग', ar: '{0} حصة',
};

async function filesUnder(directory) {
  const entries = await fs.readdir(directory, {withFileTypes: true});
  const files = await Promise.all(entries.map(entry => {
    const file = path.join(directory, entry.name);
    return entry.isDirectory() ? filesUnder(file) : [file];
  }));
  return files.flat();
}

function skipSpace(source, offset) {
  while (/\s/.test(source[offset] ?? '') && offset < source.length) offset++;
  return offset;
}

function quoted(source, start, withTemplates = true) {
  let offset = start;
  const raw = source[offset] === 'r' && /['"]/.test(source[offset + 1] ?? '');
  if (raw) offset++;
  const quote = source[offset];
  if (quote !== "'" && quote !== '"') throw new Error(`Expected literal at ${source.slice(start, start + 60)}`);
  const delimiter = source.slice(offset, offset + 3) === quote.repeat(3) ? quote.repeat(3) : quote;
  offset += delimiter.length;
  let value = '';
  let placeholderCount = 0;
  while (offset < source.length && !source.startsWith(delimiter, offset)) {
    const ch = source[offset++];
    if (!raw && ch === '\\') {
      const escaped = source[offset++];
      value += ({n: '\n', r: '\r', t: '\t', b: '\b', f: '\f'}[escaped] ?? escaped);
    } else if (!raw && ch === '$') {
      if (source[offset] === '{') {
        offset++;
        let depth = 1;
        while (offset < source.length && depth) {
          if (source[offset] === "'" || source[offset] === '"') {
            offset = quoted(source, offset, false).end;
          } else if (source[offset] === '{') {
            depth++; offset++;
          } else if (source[offset] === '}') {
            depth--; offset++;
          } else {
            offset++;
          }
        }
      } else {
        while (/[\w]/.test(source[offset] ?? '') && offset < source.length) offset++;
      }
      if (withTemplates) value += `{${placeholderCount++}}`;
    } else {
      value += ch;
    }
  }
  return {value, end: offset + delimiter.length};
}

function literal(source, start) {
  let offset = skipSpace(source, start);
  let value = '';
  let count = 0;
  while (/['"]/.test(source[offset] ?? '') || (source[offset] === 'r' && /['"]/.test(source[offset + 1] ?? ''))) {
    const part = quoted(source, offset);
    value += part.value.replace(/\{(\d+)\}/g, (_, n) => `{${Number(n) + count}}`);
    count += (part.value.match(/\{\d+\}/g) ?? []).length;
    offset = skipSpace(source, part.end);
  }
  if (!value) throw new Error(`Cannot parse literal: ${source.slice(start, start + 100)}`);
  return {value, end: offset};
}

async function extractKeys() {
  const keys = new Set();
  for (const file of await filesUnder('lib')) {
    if (!file.endsWith('.dart') || file.endsWith('.g.dart')) continue;
    const source = await fs.readFile(file, 'utf8');
    for (const match of source.matchAll(/\btr\s*\(/g)) {
      const argumentStart = skipSpace(source, match.index + match[0].length);
      if (!/['"]/.test(source[argumentStart] ?? '')) continue;
      try {
        const russian = literal(source, match.index + match[0].length);
        if (source[russian.end] !== ',') continue;
        const english = literal(source, russian.end + 1);
        keys.add(english.value);
      } catch (error) {
        throw new Error(`${file}: ${error.message}`);
      }
    }
    // Semantic labels use English as the common translation key.
    if (file.endsWith('app_localization.dart')) {
      for (const match of source.matchAll(/\ben:\s*/g)) keys.add(literal(source, match.index + match[0].length).value);
    }
  }
  for (const name of ['System', 'Russian', 'English', 'Spanish', 'Portuguese', 'German', 'French', 'Italian', 'Turkish', 'Chinese (Simplified)', 'Japanese', 'Korean', 'Hindi', 'Arabic']) keys.add(name);
  return [...keys].sort();
}

function dartString(value) {
  return JSON.stringify(value).replace(/\$/g, '\\$');
}

function normalizeTokens(text) {
  return text.replace(/\{\s*(\d+)\s*\}/g, '{$1}').replace(/\u200b/g, '');
}

function tokens(text) {
  return (text.match(/\{\d+\}/g) ?? []).sort().join(',');
}

async function translateBatch(locale, batch) {
  const url = new URL('https://clients5.google.com/translate_a/t');
  url.searchParams.set('client', 'dict-chrome-ex');
  url.searchParams.set('sl', 'en');
  url.searchParams.set('tl', locale);
  for (const text of batch) url.searchParams.append('q', text);
  for (let attempt = 0; attempt < 5; attempt++) {
    try {
      const response = await fetch(url, {signal: AbortSignal.timeout(30000)});
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const result = await response.json();
      if (!Array.isArray(result) || result.length !== batch.length || result.some(item => typeof item !== 'string')) throw new Error('Unexpected translation response');
      return result.map(normalizeTokens);
    } catch (error) {
      if (attempt === 4) throw error;
      await new Promise(resolve => setTimeout(resolve, 1200 * (attempt + 1)));
    }
  }
}

const keys = await extractKeys();
if (process.argv.includes('--check')) {
  const generated = await fs.readFile(outputPath, 'utf8');
  const committed = {};
  for (const section of generated.matchAll(/^  '(\w+)': <String, String>\{([\s\S]*?)^  \},/gm)) {
    const dictionary = committed[section[1]] = {};
    for (const entry of section[2].matchAll(/("(?:\\.|[^"])*"):\s*("(?:\\.|[^"])*"),/g)) {
      dictionary[JSON.parse(entry[1].replace(/\\\$/g, '$'))] = JSON.parse(entry[2].replace(/\\\$/g, '$'));
    }
  }
  for (const code of locales) {
    for (const key of keys) {
      const value = committed[code]?.[key];
      if (!value || tokens(value) !== tokens(key)) throw new Error(`${code}: missing or invalid translation: ${key}`);
    }
    if (Object.keys(committed[code]).length !== keys.length) throw new Error(`${code}: stale generated dictionary`);
  }
  console.log(`${keys.length} keys × ${locales.length} locales: committed offline UI coverage verified.`);
  process.exit(0);
}
await fs.mkdir(cachePath, {recursive: true});
const dictionaries = {};
const pending = [...locales];
async function worker() {
  for (let locale; (locale = pending.shift());) {
    const cacheFile = `${cachePath}/${locale}.json`;
    let cache = {};
    try { cache = JSON.parse(await fs.readFile(cacheFile, 'utf8')); } catch {}
    Object.assign(cache, reviewedOverrides[locale]);
    const semanticValues = reviewedSemanticRows[locale];
    if (semanticValues.length !== semanticKeys.length) throw new Error(`${locale}: invalid reviewed semantic row`);
    semanticKeys.forEach((key, index) => cache[key] = semanticValues[index]);
    cache['{0} serv.'] = reviewedServings[locale];
    for (const unit of ['l', 'ml', 'cl', 'g', 'fl oz', 'lb', 'qt', 'gal']) cache[unit] = unit;
    const missing = keys.filter(key => !cache[key] || tokens(cache[key]) !== tokens(key));
    for (let offset = 0; offset < missing.length; offset += 14) {
      const batch = missing.slice(offset, offset + 14);
      const translated = await translateBatch(locale, batch);
      for (let index = 0; index < batch.length; index++) {
        if (!translated[index] || tokens(batch[index]) !== tokens(translated[index])) {
          const protectedText = batch[index].replace(/\{(\d+)\}/g, 'ZXQPH$1QXZ');
          const [retry] = await translateBatch(locale, [protectedText]);
          translated[index] = retry.replace(/ZXQPH\s*(\d+)\s*QXZ/gi, '{$1}');
        }
      }
      batch.forEach((key, index) => {
        if (tokens(key) !== tokens(translated[index])) throw new Error(`${locale}: placeholder mismatch ${key} => ${translated[index]}`);
        cache[key] = translated[index];
      });
      await fs.writeFile(cacheFile, JSON.stringify(cache, null, 2) + '\n');
      process.stdout.write(`${locale}: ${Math.min(offset + 14, missing.length)}/${missing.length}\n`);
    }
    dictionaries[locale] = Object.fromEntries(keys.map(key => [key, cache[key]]));
  }
}
await Promise.all([worker(), worker()]);
{
  let output = '// Generated offline UI translations. Update with tool/generate_ui_translations.mjs.\n';
  output += '// ignore_for_file: lines_longer_than_80_chars\n\n';
  output += 'const Map<String, Map<String, String>> appTranslations = <String, Map<String, String>>{\n';
  for (const locale of locales) {
    output += `  '${locale}': <String, String>{\n`;
    for (const [key, value] of Object.entries(dictionaries[locale])) output += `    ${dartString(key)}: ${dartString(value)},\n`;
    output += '  },\n';
  }
  output += '};\n';
  await fs.writeFile(outputPath, output);
}
console.log(`${keys.length} keys × ${locales.length} locales: complete offline UI coverage.`);
