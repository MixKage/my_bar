// Reviewed against the screens where these strings are used. Keep literal
// names of buttons out of onboarding prose: numbered arguments insert the
// same localized labels used by the real controls.
export const uiLocales = ['es', 'pt', 'de', 'fr', 'it', 'tr', 'zh', 'ja', 'ko', 'hi', 'ar'];

const reviewedRows = {
  'Clear': ['Borrar', 'Limpar', 'Leeren', 'Effacer', 'Cancella', 'Temizle', '清空', 'クリア', '지우기', 'साफ़ करें', 'مسح'],
  'Clear selection': ['Borrar selección', 'Limpar seleção', 'Auswahl aufheben', 'Effacer la sélection', 'Deseleziona tutto', 'Seçimi temizle', '清除选择', '選択を解除', '선택 해제', 'चयन हटाएँ', 'إلغاء التحديد'],
  'Clear shopping list?': ['¿Vaciar la lista de compras?', 'Esvaziar a lista de compras?', 'Einkaufsliste leeren?', 'Vider la liste de courses ?', 'Svuotare la lista della spesa?', 'Alışveriş listesi temizlensin mi?', '清空购物清单？', '買い物リストを空にしますか？', '장보기 목록을 비울까요?', 'खरीदारी की सूची खाली करें?', 'هل تريد إفراغ قائمة التسوق؟'],
  'All added items will be removed.': ['Se quitarán todos los ingredientes de la lista.', 'Todos os ingredientes serão removidos da lista.', 'Alle Zutaten werden aus der Liste entfernt.', 'Tous les ingrédients seront retirés de la liste.', 'Tutti gli ingredienti verranno rimossi dalla lista.', 'Listedeki tüm malzemeler kaldırılacak.', '清单中的所有配料都将移除。', 'リスト内の材料がすべて削除されます。', '목록에서 모든 재료가 삭제됩니다.', 'सूची से सभी सामग्रियाँ हटा दी जाएँगी।', 'ستُزال جميع المكوّنات من القائمة.'],
  'Search languages': ['Buscar idiomas', 'Buscar idiomas', 'Sprachen suchen', 'Rechercher une langue', 'Cerca lingue', 'Dil ara', '搜索语言', '言語を検索', '언어 검색', 'भाषाएँ खोजें', 'البحث عن لغة'],
  'Search ingredients...': ['Buscar ingredientes…', 'Buscar ingredientes…', 'Zutaten suchen…', 'Rechercher un ingrédient…', 'Cerca ingredienti…', 'Malzeme ara…', '搜索配料…', '材料を検索…', '재료 검색…', 'सामग्री खोजें…', 'البحث عن مكوّن…'],
  'Search cocktails': ['Buscar cócteles', 'Buscar coquetéis', 'Cocktails suchen', 'Rechercher un cocktail', 'Cerca cocktail', 'Kokteyl ara', '搜索鸡尾酒', 'カクテルを検索', '칵테일 검색', 'कॉकटेल खोजें', 'البحث عن كوكتيل'],
  'Search cocktails…': ['Buscar cócteles…', 'Buscar coquetéis…', 'Cocktails suchen…', 'Rechercher un cocktail…', 'Cerca cocktail…', 'Kokteyl ara…', '搜索鸡尾酒…', 'カクテルを検索…', '칵테일 검색…', 'कॉकटेल खोजें…', 'البحث عن كوكتيل…'],
  'Spirits': ['Destilados', 'Destilados', 'Spirituosen', 'Spiritueux', 'Distillati', 'Distile içkiler', '烈酒', '蒸留酒', '증류주', 'आसुत मदिरा', 'المشروبات الروحية'],
  'Sodas and non-alcoholic mixers': ['Refrescos y mezcladores sin alcohol', 'Refrigerantes e misturas sem álcool', 'Limonaden und alkoholfreie Mixer', 'Sodas et boissons sans alcool à mélanger', 'Bibite e mixer analcolici', 'Gazlı içecekler ve alkolsüz karıştırıcılar', '汽水及无酒精调饮', '炭酸飲料とノンアルコールの割り材', '탄산음료 및 무알코올 믹서', 'सोडा और बिना अल्कोहल वाले मिक्सर', 'المشروبات الغازية ومكوّنات الخلط غير الكحولية'],
  'Spices, herbs and bitters': ['Especias, hierbas y bitters', 'Especiarias, ervas e bitters', 'Gewürze, Kräuter und Cocktailbitters', 'Épices, herbes et bitters', 'Spezie, erbe e bitter', 'Baharatlar, otlar ve kokteyl bitterleri', '香料、香草和苦精', 'スパイス・ハーブ・ビターズ', '향신료, 허브, 비터스', 'मसाले, जड़ी-बूटियाँ और बिटर्स', 'التوابل والأعشاب والبيترز'],
  'Glass type*': ['Tipo de vaso*', 'Tipo de copo*', 'Glasart*', 'Type de verre*', 'Tipo di bicchiere*', 'Bardak türü*', '杯型*', 'グラスの種類*', '잔 종류*', 'गिलास का प्रकार*', 'نوع الكأس*'],
  'Glass: {0}': ['Vaso: {0}', 'Copo: {0}', 'Glas: {0}', 'Verre : {0}', 'Bicchiere: {0}', 'Bardak: {0}', '杯型：{0}', 'グラス：{0}', '잔: {0}', 'गिलास: {0}', 'الكأس: {0}'],
  'Missing 1': ['Falta 1', 'Falta 1', '1 Zutat fehlt', 'Il manque 1 ingrédient', 'Manca 1 ingrediente', '1 malzeme eksik', '缺 1 种配料', '材料があと1つ', '재료 1개 부족', '1 सामग्री कम', 'ينقص مكوّن واحد'],
  'Missing 2': ['Faltan 2', 'Faltam 2', '2 Zutaten fehlen', 'Il manque 2 ingrédients', 'Mancano 2 ingredienti', '2 malzeme eksik', '缺 2 种配料', '材料があと2つ', '재료 2개 부족', '2 सामग्रियाँ कम', 'ينقص مكوّنان'],
  'Missing ingredients: {0}': ['Ingredientes que faltan: {0}', 'Ingredientes que faltam: {0}', 'Fehlende Zutaten: {0}', 'Ingrédients manquants : {0}', 'Ingredienti mancanti: {0}', 'Eksik malzemeler: {0}', '缺少的配料：{0}', '足りない材料：{0}', '부족한 재료: {0}', 'कम सामग्री: {0}', 'المكوّنات الناقصة: {0}'],
  'Missing: {0}': ['Faltan: {0}', 'Faltam: {0}', 'Es fehlen: {0}', 'Il manque : {0}', 'Mancano: {0}', 'Eksik: {0}', '缺少：{0}', '不足：{0}', '부족한 재료: {0}', 'कम: {0}', 'الناقص: {0}'],
  'Missing: {0} and {1} more': ['Faltan: {0} y {1} más', 'Faltam: {0} e mais {1}', 'Es fehlen: {0} und {1} weitere', 'Il manque : {0} et {1} de plus', 'Mancano: {0} e altri {1}', 'Eksik: {0} ve {1} malzeme daha', '缺少：{0}，另有 {1} 种', '不足：{0}、ほか{1}品', '부족한 재료: {0} 외 {1}개', 'कम: {0} और {1} अन्य', 'الناقص: {0} و{1} أخرى'],
  'Ready': ['Disponibles', 'Disponíveis', 'Verfügbar', 'Disponibles', 'Disponibili', 'Hazır', '可制作', '作れる', '만들 수 있음', 'बना सकते हैं', 'قابلة للتحضير'],
  'Ready now': ['Puedes prepararlo ahora', 'Você pode preparar agora', 'Jetzt mixbar', 'Réalisable maintenant', 'Puoi prepararlo ora', 'Şimdi hazırlanabilir', '现在就能制作', '今すぐ作れます', '지금 만들 수 있음', 'अभी बना सकते हैं', 'يمكن تحضيره الآن'],
  'Ready only': ['Solo disponibles', 'Só disponíveis', 'Nur verfügbare', 'Disponibles uniquement', 'Solo disponibili', 'Yalnızca hazırlanabilenler', '仅可制作', '今作れるものだけ', '만들 수 있는 것만', 'केवल उपलब्ध सामग्री वाले', 'القابلة للتحضير فقط'],
  'Select ready': ['Seleccionar disponibles', 'Selecionar disponíveis', 'Verfügbare auswählen', 'Sélectionner les cocktails disponibles', 'Seleziona i disponibili', 'Hazırlanabilenleri seç', '选择可制作的酒款', '作れるものを選択', '만들 수 있는 칵테일 선택', 'बन सकने वाले चुनें', 'تحديد القابلة للتحضير'],
  'Owned ingredients only': ['Solo ingredientes que tengo', 'Só ingredientes que tenho', 'Nur vorhandene Zutaten', 'Uniquement les ingrédients en stock', 'Solo ingredienti disponibili', 'Yalnızca elimdekiler', '仅显示已有配料', '持っている材料のみ', '보유한 재료만', 'केवल मौजूद सामग्री', 'المكوّنات المتوفرة فقط'],
  'Party mode': ['Modo fiesta', 'Modo festa', 'Party-Modus', 'Mode fête', 'Modalità festa', 'Parti modu', '聚会模式', 'パーティーモード', '파티 모드', 'पार्टी मोड', 'وضع الحفلة'],
  'Add missing to shopping · {0}': ['Añadir lo que falta a la lista · {0}', 'Adicionar o que falta à lista · {0}', 'Fehlende auf die Einkaufsliste · {0}', 'Ajouter les ingrédients manquants · {0}', 'Aggiungi alla lista ciò che manca · {0}', 'Eksikleri alışveriş listesine ekle · {0}', '将缺少的配料加入清单 · {0}', '足りない材料を買い物リストに追加 · {0}', '부족한 재료를 장보기 목록에 추가 · {0}', 'कम सामग्री सूची में जोड़ें · {0}', 'إضافة الناقص إلى قائمة التسوق · {0}'],
  'Added to shopping · {0}': ['Añadidos a la lista · {0}', 'Adicionados à lista · {0}', 'Auf der Einkaufsliste · {0}', 'Ajoutés à la liste de courses · {0}', 'Aggiunti alla lista della spesa · {0}', 'Alışveriş listesine eklendi · {0}', '已加入购物清单 · {0}', '買い物リストに追加済み · {0}', '장보기 목록에 추가됨 · {0}', 'खरीदारी की सूची में जोड़ा गया · {0}', 'تمت الإضافة إلى قائمة التسوق · {0}'],
  'Smart shopping list': ['Lista de compras inteligente', 'Lista de compras inteligente', 'Intelligente Einkaufsliste', 'Liste de courses intelligente', 'Lista della spesa intelligente', 'Akıllı alışveriş listesi', '智能购物清单', 'スマート買い物リスト', '스마트 장보기 목록', 'स्मार्ट खरीदारी सूची', 'قائمة التسوق الذكية'],
  'Your home bar': ['Tu bar en casa', 'Seu bar em casa', 'Deine Hausbar', 'Votre bar à la maison', 'Il tuo bar di casa', 'Ev barınız', '你的家庭酒吧', 'おうちバー', '나만의 홈 바', 'आपका होम बार', 'البار المنزلي'],
  'Almost ready to mix': ['A un paso del cóctel', 'Quase tudo pronto', 'Fast alle Zutaten vorhanden', 'Il ne manque presque rien', 'Manca poco', 'Çok az malzeme eksik', '只差一两种配料', 'あと少しで作れる', '한두 가지 재료만 더', 'बस एक-दो चीज़ें और', 'لم يتبقَّ سوى مكوّن أو اثنين'],
  'Cocktails for a group': ['Cócteles para varias personas', 'Coquetéis para o grupo', 'Cocktails für mehrere Personen', 'Des cocktails pour tout le monde', 'Cocktail per più persone', 'Herkes için kokteyller', '为多人调酒', '人数に合わせて作る', '여럿을 위한 칵테일', 'कई लोगों के लिए कॉकटेल', 'كوكتيلات للمجموعة'],
  'Discover a new favorite': ['Descubre nuevos cócteles', 'Descubra novos coquetéis', 'Entdecke neue Cocktails', 'Découvrez un nouveau cocktail', 'Scopri un nuovo cocktail', 'Yeni bir kokteyl keşfet', '发现新口味', '新しいカクテルに出会う', '새로운 칵테일 만나기', 'नया कॉकटेल खोजें', 'اكتشف كوكتيلًا جديدًا'],
  '1. Mark the ingredients you have at home in “{0}”. A check mark means you have it.\n\n2. Open “{1}” and select “{2}” to see which cocktails you can make.': [
    '1. Marca en «{0}» los ingredientes que tienes en casa. La marca indica que los tienes.\n\n2. Abre «{1}» y elige «{2}» para ver qué cócteles puedes preparar.',
    '1. Marque em “{0}” os ingredientes que você tem em casa. O sinal de seleção indica que você tem o ingrediente.\n\n2. Abra “{1}” e escolha “{2}” para ver os coquetéis que pode preparar.',
    '1. Markiere unter „{0}“, was du zu Hause hast. Ein Häkchen zeigt an, dass die Zutat vorhanden ist.\n\n2. Öffne „{1}“ und wähle „{2}“, um zu sehen, welche Cocktails du mixen kannst.',
    '1. Dans « {0} », cochez les ingrédients que vous avez chez vous. La coche indique que l’ingrédient est en stock.\n\n2. Ouvrez « {1} » et choisissez « {2} » pour voir quels cocktails vous pouvez préparer.',
    '1. In «{0}», seleziona gli ingredienti che hai in casa. Il segno di spunta indica che sono disponibili.\n\n2. Apri «{1}» e scegli «{2}» per vedere quali cocktail puoi preparare.',
    '1. Evinizdeki malzemeleri “{0}” bölümünde işaretleyin. Onay işareti, malzemenin elinizde olduğunu gösterir.\n\n2. “{1}” bölümünü açıp “{2}” seçeneğine dokunarak hazırlayabileceğiniz kokteylleri görün.',
    '1. 在“{0}”中勾选家里已有的配料。打勾表示你已经有这项配料。\n\n2. 打开“{1}”，选择“{2}”查看现在可以制作的鸡尾酒。',
    '1. 「{0}」で家にある材料にチェックを入れます。チェックは材料が手元にある印です。\n\n2. 「{1}」を開き、「{2}」を選ぶと、作れるカクテルが表示されます。',
    '1. “{0}”에서 집에 있는 재료를 선택하세요. 체크 표시는 재료가 있다는 뜻입니다.\n\n2. “{1}”를 열고 “{2}”를 선택해 만들 수 있는 칵테일을 확인하세요.',
    '1. “{0}” में घर पर मौजूद सामग्री चुनें। सही का निशान बताता है कि वह सामग्री आपके पास है।\n\n2. “{1}” खोलें और “{2}” चुनें। इससे पता चलेगा कि आप कौन-से कॉकटेल बना सकते हैं।',
    '١. حدّد المكوّنات الموجودة في منزلك ضمن «{0}». تشير علامة الصح إلى أن المكوّن متوفر لديك.\n\n٢. افتح «{1}» واختر «{2}» لمعرفة الكوكتيلات التي يمكنك تحضيرها.',
  ],
  'Use “{0}” and “{1}” to find recipes that need just one or two more ingredients. The shopping list helps you decide what to buy next.': [
    'Usa «{0}» y «{1}» para encontrar recetas a las que solo les faltan uno o dos ingredientes. La lista de compras te ayuda a decidir qué comprar.',
    'Use “{0}” e “{1}” para encontrar receitas que precisam de apenas mais um ou dois ingredientes. A lista de compras ajuda você a decidir o que comprar.',
    'Mit „{0}“ und „{1}“ findest du Rezepte, für die nur noch eine oder zwei Zutaten fehlen. Die Einkaufsliste hilft dir bei der Planung.',
    'Utilisez « {0} » et « {1} » pour trouver les recettes auxquelles il ne manque qu’un ou deux ingrédients. La liste de courses vous aide à choisir quoi acheter.',
    'Usa «{0}» e «{1}» per trovare le ricette a cui mancano solo uno o due ingredienti. La lista della spesa ti aiuta a decidere cosa acquistare.',
    'Sadece bir veya iki malzemesi eksik tarifleri görmek için “{0}” ve “{1}” filtrelerini kullanın. Alışveriş listesi ne alacağınıza karar vermenize yardımcı olur.',
    '用“{0}”和“{1}”筛选只差一两种配料的配方。购物清单可以帮你决定要买哪些配料。',
    '「{0}」や「{1}」で、あと1つか2つの材料で作れるレシピを探せます。買い物リストで、次に買う材料を決めましょう。',
    '“{0}”와 “{1}”로 재료가 한두 가지만 더 있으면 되는 레시피를 찾아보세요. 장보기 목록을 참고해 필요한 재료를 준비하세요.',
    'ऐसी रेसिपी ढूँढने के लिए “{0}” और “{1}” चुनें जिनमें सिर्फ़ एक या दो सामग्रियाँ कम हैं। खरीदारी की सूची से तय करें कि आगे क्या खरीदना है।',
    'استخدم «{0}» و«{1}» للعثور على وصفات لا ينقصها سوى مكوّن أو مكوّنين. تساعدك قائمة التسوق في تحديد ما تحتاج إلى شرائه.',
  ],
  'Adjust the ingredient amounts for the servings you need. In “{0}”, choose cocktails to get one combined ingredient list.': [
    'Ajusta las cantidades al número de porciones que necesitas. En «{0}», elige los cócteles para obtener una sola lista de ingredientes.',
    'Ajuste as quantidades ao número de porções que você precisa. Em “{0}”, escolha os coquetéis para obter uma lista única de ingredientes.',
    'Passe die Mengen an die gewünschte Portionszahl an. Wähle im „{0}“ Cocktails aus, um eine gemeinsame Zutatenliste zu erhalten.',
    'Ajustez les quantités au nombre de portions souhaité. Dans « {0} », choisissez vos cocktails pour obtenir une liste d’ingrédients commune.',
    'Adatta le quantità al numero di porzioni che ti serve. In «{0}», scegli i cocktail per ottenere un’unica lista degli ingredienti.',
    'Malzeme miktarlarını istediğiniz porsiyon sayısına göre ayarlayın. Tek bir malzeme listesi oluşturmak için “{0}” bölümünde kokteylleri seçin.',
    '按所需份数调整配料用量。在“{0}”中选择多款鸡尾酒，即可获得一份合并的配料清单。',
    '必要な杯数に合わせて、材料の分量を調整できます。「{0}」でカクテルを選ぶと、必要な材料をまとめて確認できます。',
    '필요한 잔 수에 맞춰 재료의 양을 조절하세요. “{0}”에서 칵테일을 선택하면 필요한 재료를 한 목록으로 볼 수 있습니다.',
    'ज़रूरत के हिसाब से सर्विंग की संख्या और सामग्री की मात्रा तय करें। “{0}” में कॉकटेल चुनें और सबकी सामग्री की एक सूची पाएँ।',
    'اضبط كميات المكوّنات بحسب عدد الحصص التي تحتاج إليها. اختر الكوكتيلات في «{0}» للحصول على قائمة موحّدة بالمكوّنات.',
  ],
  'Tap “{0}” for a random recipe and “{1}” to see another. Save the recipes you like to favorites. All these features are free and work offline.': [
    'Toca «{0}» para ver una receta al azar y «{1}» para ver otra. Guarda las que te gusten en favoritos. Todo es gratis y funciona sin conexión.',
    'Toque em “{0}” para ver uma receita aleatória e em “{1}” para ver outra. Salve as receitas de que gosta nos favoritos. Tudo é grátis e funciona sem internet.',
    'Tippe auf „{0}“ für ein zufälliges Rezept und auf „{1}“ für ein weiteres. Speichere deine Lieblingsrezepte als Favoriten. Alles ist kostenlos und funktioniert offline.',
    'Touchez « {0} » pour découvrir une recette au hasard, puis « {1} » pour en voir une autre. Enregistrez vos recettes préférées dans les favoris. Tout est gratuit et fonctionne hors connexion.',
    'Tocca «{0}» per una ricetta a caso e «{1}» per vederne un’altra. Salva le ricette che ti piacciono nei preferiti. È tutto gratuito e funziona offline.',
    'Rastgele bir tarif için “{0}”, başka bir tarif için “{1}” düğmesine dokunun. Beğendiğiniz tarifleri favorilere kaydedin. Bu özellikler ücretsizdir ve çevrimdışı çalışır.',
    '点按“{0}”随机查看一个配方，点按“{1}”换一个。喜欢的配方可以收藏。这些功能均免费，也可离线使用。',
    '「{0}」でランダムにレシピを表示し、「{1}」で別のレシピを見られます。気に入ったレシピはお気に入りに保存できます。すべて無料で、オフラインでも使えます。',
    '“{0}”로 무작위 레시피를 보고, “{1}”로 다른 레시피를 확인하세요. 마음에 드는 레시피는 즐겨찾기에 저장하세요. 이 기능은 모두 무료이며 오프라인에서도 사용할 수 있습니다.',
    'कोई भी एक रेसिपी देखने के लिए “{0}” दबाएँ और दूसरी देखने के लिए “{1}” दबाएँ। पसंद की रेसिपी को पसंदीदा में सहेजें। ये सुविधाएँ मुफ़्त हैं और बिना इंटरनेट के काम करती हैं।',
    'اضغط على «{0}» لعرض وصفة عشوائية، وعلى «{1}» لعرض وصفة أخرى. احفظ الوصفات التي تعجبك في المفضلة. كل هذه الميزات مجانية وتعمل دون اتصال بالإنترنت.',
  ],
};

for (const [key, values] of Object.entries(reviewedRows)) {
  if (values.length !== uiLocales.length || values.some(value => !value.trim())) {
    throw new Error(`Invalid reviewed UI translation row: ${key}`);
  }
}

export const contextualUiOverrides = Object.fromEntries(
  uiLocales.map((locale, index) => [
    locale,
    Object.fromEntries(Object.entries(reviewedRows).map(([key, values]) => [key, values[index]])),
  ]),
);
