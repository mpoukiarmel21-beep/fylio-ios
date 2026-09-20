# FYLIO — `scripts/build_localizable.py` (génère proprement les 7 langues, zéro JSON manuel)

```python
#!/usr/bin/env python3
"""Fylio — Générateur de Localizable.xcstrings (7 langues).
Construit le catalogue de traductions complet à partir d'une table Python,
pas de JSON rédigé à la main. Usage : python3 scripts/build_localizable.py
"""

import json
from pathlib import Path

LANGS = ["en", "zh-Hans", "hi", "es", "fr", "ar", "pt"]

# Table des traductions : clé → {langue: texte}
# Format des clés : "famille.clé" (identiques aux appels String(localized:) du code Swift).
TABLE = {
    "common.seeAll":        {"en": "See all",      "zh-Hans": "查看全部", "hi": "सभी देखें", "es": "Ver todo",       "fr": "Voir tout",     "ar": "عرض الكل",      "pt": "Ver tudo"},
    "common.search":        {"en": "Search",       "zh-Hans": "搜索",     "hi": "खोजें",    "es": "Buscar",         "fr": "Rechercher",    "ar": "بحث",           "pt": "Pesquisar"},
    "common.preview":       {"en": "Preview",      "zh-Hans": "预览",     "hi": "पूर्वावलोकन","es": "Vista previa",  "fr": "Aperçu",        "ar": "معاينة",        "pt": "Pré-visualizar"},
    "common.create":        {"en": "Create",       "zh-Hans": "创建",     "hi": "बनाएँ",     "es": "Crear",          "fr": "Créer",         "ar": "إنشاء",         "pt": "Criar"},
    "common.cancel":        {"en": "Cancel",       "zh-Hans": "取消",     "hi": "रद्द करें", "es": "Cancelar",       "fr": "Annuler",       "ar": "إلغاء",         "pt": "Cancelar"},
    "common.close":         {"en": "Close",        "zh-Hans": "关闭",     "hi": "बंद करें",  "es": "Cerrar",         "fr": "Fermer",        "ar": "إغلاق",         "pt": "Fechar"},

    "home.hello %@ 👋":     {"en": "Hello %@ 👋",  "zh-Hans": "你好 %@ 👋", "hi": "नमस्ते %@ 👋", "es": "Hola %@ 👋",  "fr": "Bonjour %@ 👋", "ar": "مرحبا %@ 👋",   "pt": "Olá %@ 👋"},
    "home.tagline":         {"en": "Your files, everywhere with you.", "zh-Hans": "您的文件，随时随地。", "hi": "आपकी फ़ाइलें, हर जगह आपके साथ।", "es": "Tus archivos, en todas partes contigo.", "fr": "Vos fichiers, partout avec vous.", "ar": "ملفاتك، في كل مكان معك.", "pt": "Seus arquivos, em todo lugar com você."},
    "home.alwaysConnected": {"en": "Always connected", "zh-Hans": "始终在线", "hi": "हमेशा जुड़े", "es": "Siempre conectado", "fr": "Toujours connecté", "ar": "متصل دائماً", "pt": "Sempre conectado"},
    "home.send":            {"en": "Send",         "zh-Hans": "发送",     "hi": "भेजें",    "es": "Enviar",         "fr": "Envoyer",       "ar": "إرسال",         "pt": "Enviar"},
    "home.send.subtitle":   {"en": "Share files",  "zh-Hans": "分享文件",  "hi": "फ़ाइलें साझा करें", "es": "Compartir archivos", "fr": "Partager des fichiers", "ar": "مشاركة الملفات", "pt": "Compartilhar arquivos"},
    "home.receive":         {"en": "Receive",      "zh-Hans": "接收",     "hi": "प्राप्त करें","es": "Recibir",       "fr": "Recevoir",      "ar": "استلام",        "pt": "Receber"},
    "home.receive.subtitle":{"en": "Wait for a transfer", "zh-Hans": "等待传输", "hi": "स्थानांतरण की प्रतीक्षा करें", "es": "Esperar una transferencia", "fr": "Attendre un transfert", "ar": "انتظر التحويل", "pt": "Aguardar transferência"},
    "home.recentDevices":   {"en": "Recent devices", "zh-Hans": "最近的设备", "hi": "हाल के उपकरण", "es": "Dispositivos recientes", "fr": "Appareils récents", "ar": "الأجهزة الحديثة", "pt": "Dispositivos recentes"},
    "home.transferHistory": {"en": "Transfer history", "zh-Hans": "传输历史", "hi": "स्थानांतरण इतिहास", "es": "Historial de transferencias", "fr": "Historique des transferts", "ar": "سجل التحويلات", "pt": "Histórico de transferências"},

    "onboarding.welcome.title":   {"en": "Welcome to Fylio", "zh-Hans": "欢迎使用 Fylio", "hi": "Fylio में आपका स्वागत है", "es": "Bienvenido a Fylio", "fr": "Bienvenue sur Fylio", "ar": "مرحبا بك في Fylio", "pt": "Bem-vindo ao Fylio"},
    "onboarding.welcome.subtitle":{"en": "Transfer files between all your devices, fast and simply.", "zh-Hans": "在所有设备之间快速简单地传输文件。", "hi": "अपने सभी उपकरणों के बीच तेज़ और आसान फ़ाइल स्थानांतरण।", "es": "Transfiere archivos entre todos tus dispositivos, rápido y simple.", "fr": "Transférez des fichiers entre tous vos appareils, vite et simplement.", "ar": "انقل الملفات بين جميع أجهزتك بسرعة وبساطة.", "pt": "Transfira arquivos entre todos os seus dispositivos, rápido e simples."},
    "onboarding.avatar.title":    {"en": "Choose your avatar", "zh-Hans": "选择您的头像", "hi": "अपना अवतार चुनें", "es": "Elige tu avatar", "fr": "Choisissez votre avatar", "ar": "اختر صورتك الرمزية", "pt": "Escolha seu avatar"},
    "onboarding.name.title":      {"en": "Name your device", "zh-Hans": "命名您的设备", "hi": "अपने उपकरण का नाम दें", "es": "Nombra tu dispositivo", "fr": "Nommez votre appareil", "ar": "سمِّ جهازك", "pt": "Dê um nome ao seu dispositivo"},
    "onboarding.name.subtitle":   {"en": "Other devices will see this name.", "zh-Hans": "其他设备将看到此名称。", "hi": "अन्य उपकरण इस नाम को देखेंगे।", "es": "Otros dispositivos verán este nombre.", "fr": "Les autres appareils verront ce nom.", "ar": "سترى الأجهزة الأخرى هذا الاسم.", "pt": "Outros dispositivos verão este nome."},
    "onboarding.name.placeholder":{"en": "e.g. Alex's iPhone", "zh-Hans": "例如：Alex 的 iPhone", "hi": "उदा. एलेक्स का iPhone", "es": "p. ej., iPhone de Alex", "fr": "ex. iPhone d'Alex", "ar": "مثال: هاتف أليكس", "pt": "ex. iPhone do Alex"},
    "onboarding.name.suggestion": {"en": "Use device name", "zh-Hans": "使用设备名称", "hi": "उपकरण नाम का उपयोग करें", "es": "Usar nombre del dispositivo", "fr": "Utiliser le nom de l'appareil", "ar": "استخدم اسم الجهاز", "pt": "Usar nome do dispositivo"},
    "onboarding.permissions.title":   {"en": "Allow permissions", "zh-Hans": "允许权限", "hi": "अनुमतियाँ दें", "es": "Permitir permisos", "fr": "Autoriser les permissions", "ar": "اسمح بالأذونات", "pt": "Permitir permissões"},
    "onboarding.permissions.0.title":  {"en": "Notifications", "zh-Hans": "通知", "hi": "सूचनाएँ", "es": "Notificaciones", "fr": "Notifications", "ar": "الإشعارات", "pt": "Notificações"},
    "onboarding.permissions.0.subtitle": {"en": "Know when a transfer arrives", "zh-Hans": "传输到达时通知您", "hi": "स्थानांतरण आने पर पता चलता है", "es": "Saber cuándo llega una transferencia", "fr": "Savoir quand un transfert arrive", "ar": "اعرف متى يصل التحويل", "pt": "Saber quando chega uma transferência"},
    "onboarding.permissions.1.title":  {"en": "Photos", "zh-Hans": "照片", "hi": "तस्वीरें", "es": "Fotos", "fr": "Photos", "ar": "الصور", "pt": "Fotos"},
    "onboarding.permissions.1.subtitle": {"en": "Send your photos and videos", "zh-Hans": "发送您的照片和视频", "hi": "अपनी तस्वीरें और वीडियो भेजें", "es": "Envía tus fotos y videos", "fr": "Envoyez vos photos et vidéos", "ar": "أرسل صورك ومقاطعك", "pt": "Envie suas fotos e vídeos"},
    "onboarding.permissions.2.title":  {"en": "Files", "zh-Hans": "文件", "hi": "फ़ाइलें", "es": "Archivos", "fr": "Fichiers", "ar": "الملفات", "pt": "Arquivos"},
    "onboarding.permissions.2.subtitle": {"en": "Access documents to share", "zh-Hans": "访问要共享的文档", "hi": "साझा करने के लिए दस्तावेज़ एक्सेस करें", "es": "Acceder a documentos para compartir", "fr": "Accéder aux documents à partager", "ar": "الوصول إلى الملفات للمشاركة", "pt": "Acessar documentos para compartilhar"},
    "onboarding.permissions.allow":    {"en": "Allow", "zh-Hans": "允许", "hi": "अनुमति दें", "es": "Permitir", "fr": "Autoriser", "ar": "السماح", "pt": "Permitir"},
    "onboarding.permissions.granted": {"en": "Granted", "zh-Hans": "已授权", "hi": "अनुमति मिली", "es": "Concedido", "fr": "Accordé", "ar": "تم السماح", "pt": "Concedido"},
    "onboarding.methods.title":    {"en": "Transfer methods", "zh-Hans": "传输方式", "hi": "स्थानांतरण विधियाँ", "es": "Métodos de transferencia", "fr": "Méthodes de transfert", "ar": "طرق التحويل", "pt": "Métodos de transferência"},
    "onboarding.methods.wifi":     {"en": "Same Wi-Fi network", "zh-Hans": "同一 Wi-Fi 网络", "hi": "एक ही Wi-Fi नेटवर्क", "es": "Misma red Wi-Fi", "fr": "Même réseau Wi-Fi", "ar": "نفس شبكة Wi-Fi", "pt": "Mesma rede Wi-Fi"},
    "onboarding.methods.qr":      {"en": "QR code", "zh-Hans": "二维码", "hi": "QR कोड", "es": "Código QR", "fr": "Code QR", "ar": "رمز QR", "pt": "Código QR"},
    "onboarding.methods.hotspot": {"en": "Local access point", "zh-Hans": "本地热点", "hi": "स्थानीय हॉटस्पॉट", "es": "Punto de acceso local", "fr": "Point d'accès local", "ar": "نقطة وصول محلية", "pt": "Ponto de acesso local"},
    "onboarding.methods.usb":     {"en": "USB cable", "zh-Hans": "USB 数据线", "hi": "USB केबल", "es": "Cable USB", "fr": "Câble USB", "ar": "كابل USB", "pt": "Cabo USB"},
    "onboarding.methods.remote":  {"en": "Remote over Internet", "zh-Hans": "互联网远程", "hi": "इंटरनेट पर दूरस्थ", "es": "Remoto por Internet", "fr": "À distance via Internet", "ar": "عن بعد عبر الإنترنت", "pt": "Remoto pela Internet"},
    "onboarding.methods.registered": {"en": "Registered devices", "zh-Hans": "已注册设备", "hi": "पंजीकृत उपकरण", "es": "Dispositivos registrados", "fr": "Appareils enregistrés", "ar": "الأجهزة المسجلة", "pt": "Dispositivos registrados"},
    "onboarding.start":           {"en": "Start", "zh-Hans": "开始", "hi": "शुरू करें", "es": "Comenzar", "fr": "Commencer", "ar": "ابدأ", "pt": "Começar"},
    "onboarding.next":            {"en": "Next", "zh-Hans": "下一步", "hi": "अगला", "es": "Siguiente", "fr": "Suivant", "ar": "التالي", "pt": "Próximo"},

    "devices.title":       {"en": "Recent devices", "zh-Hans": "最近的设备", "hi": "हाल के उपकरण", "es": "Dispositivos recientes", "fr": "Appareils récents", "ar": "الأجهزة الحديثة", "pt": "Dispositivos recentes"},
    "devices.empty.title": {"en": "No devices yet", "zh-Hans": "还没有设备", "hi": "अभी कोई उपकरण नहीं", "es": "Aún no hay dispositivos", "fr": "Aucun appareil pour le moment", "ar": "لا توجد أجهزة بعد", "pt": "Ainda não há dispositivos"},
    "devices.empty.subtitle": {"en": "Devices you transfer with will appear here.", "zh-Hans": "您传输的设备将显示在这里。", "hi": "जिन उपकरणों से आप स्थानांतरित करते हैं वे यहाँ दिखेंगे।", "es": "Los dispositivos con los que transfieras aparecerán aquí.", "fr": "Les appareils avec lesquels vous transférez apparaîtront ici.", "ar": "ستظهر هنا الأجهزة التي تنقل إليها.", "pt": "Os dispositivos com os quais você transfere aparecerão aqui."},
    "devices.rename":      {"en": "Rename", "zh-Hans": "重命名", "hi": "नाम बदलें", "es": "Renombrar", "fr": "Renommer", "ar": "إعادة تسمية", "pt": "Renomear"},
    "devices.delete":      {"en": "Delete", "zh-Hans": "删除", "hi": "मिटाएँ", "es": "Eliminar", "fr": "Supprimer", "ar": "حذف", "pt": "Excluir"},

    "send.title":       {"en": "Send", "zh-Hans": "发送", "hi": "भेजें", "es": "Enviar", "fr": "Envoyer", "ar": "إ    "send.title":       {"en": "Send", "zh-Hans": "发送", "hi": "भेजें", "es": "Enviar", "fr": "Envoyer", "ar": "إرسال", "pt": "Enviar"},
    "send.selectedCount": {"en": "%d file(s) selected", "zh-Hans": "已选择 %d 个文件", "hi": "%d फ़ाइलें चयनित", "es": "%d archivo(s) seleccionado(s)", "fr": "%d fichier(s) sélectionné(s)", "ar": "تم اختيار %d ملف", "pt": "%d arquivo(s) selecionado(s)"},
    "send.pickDevice":  {"en": "Send to device", "zh-Hans": "发送到设备", "hi": "उपकरण को भेजें", "es": "Enviar a dispositivo", "fr": "Envoyer à l'appareil", "ar": "إرسال إلى الجهاز", "pt": "Enviar para dispositivo"},

    "receive.title":    {"en": "Receive", "zh-Hans": "接收", "hi": "प्राप्त करें", "es": "Recibir", "fr": "Recevoir", "ar": "استلام", "pt": "Receber"},
    "receive.available": {"en": "Available connections", "zh-Hans": "可用连接", "hi": "उपलब्ध कनेक्शन", "es": "Conexiones disponibles", "fr": "Connexions disponibles", "ar": "الاتصالات المتاحة", "pt": "Conexões disponíveis"},
    "receive.searching": {"en": "Searching for devices…", "zh-Hans": "正在搜索设备…", "hi": "उपकरण खोज रहे हैं…", "es": "Buscando dispositivos…", "fr": "Recherche d'appareils…", "ar": "جاري البحث عن الأجهزة…", "pt": "Procurando dispositivos…"},
    "receive.searching.subtitle": {"en": "Make sure Fylio is open on the other device.", "zh-Hans": "确保另一台设备上已打开 Fylio。", "hi": "सुनिश्चित करें कि दूसरे उपकरण पर Fylio खुला है।", "es": "Asegúrate de que Fylio esté abierto en el otro dispositivo.", "fr": "Assurez-vous que Fylio est ouvert sur l'autre appareil.", "ar": "تأكد من أن Fylio مفتوح على الجهاز الآخر.", "pt": "Certifique-se de que o Fylio está aberto no outro dispositivo."},
    "receive.qr.hint": {"en": "Scan this code with the other device to connect instantly.", "zh-Hans": "用另一台设备扫描此码即可立即连接。", "hi": "दूसरे उपकरण से इस कोड को स्कैन करें और तुरंत जुड़ें।", "es": "Escanea este código con el otro dispositivo para conectar al instante.", "fr": "Scannez ce code avec l'autre appareil pour se connecter instantanément.", "ar": "امسح هذا الرمز بالجهاز الآخر للاتصال فوراً.", "pt": "Escaneie este código com o outro dispositivo para conectar instantaneamente."},
    "receive.incoming": {"en": "Incoming requests", "zh-Hans": "传入请求", "hi": "आने वाले अनुरोध", "es": "Solicitudes entrantes", "fr": "Demandes entrantes", "ar": "الطلبات الواردة", "pt": "Solicitações recebidas"},
    "receive.noIncoming": {"en": "No incoming requests", "zh-Hans": "没有传入请求", "hi": "कोई आने वाला अनुरोध नहीं", "es": "Sin solicitudes entrantes", "fr": "Aucune demande entrante", "ar": "لا توجد طلبات واردة", "pt": "Sem solicitações recebidas"},
    "receive.incoming.detail": {"en": "%d file(s) · %@", "zh-Hans": "%d 个文件 · %@", "hi": "%d फ़ाइलें · %@", "es": "%d archivo(s) · %@", "fr": "%d fichier(s) · %@", "ar": "%d ملف · %@", "pt": "%d arquivo(s) · %@"},

    "qr.scanner.hint": {"en": "Point the camera at the Fylio QR code", "zh-Hans": "将相机对准 Fylio 二维码", "hi": "कैमरा को Fylio QR कोड की ओर घुमाएँ", "es": "Apunta la cámara al código QR de Fylio", "fr": "Pointez la caméra vers le code QR Fylio", "ar": "وجه الكاميرا نحو رمز QR الخاص بـ Fylio", "pt": "Aponte a câmera para o código QR do Fylio"},

    "progress.title":     {"en": "Transferring", "zh-Hans": "传输中", "hi": "स्थानांतरण जारी", "es": "Transfiriendo", "fr": "Transfert en cours", "ar": "جارٍ التحويل", "pt": "Transferindo"},
    "progress.speed":     {"en": "Speed: %@/s", "zh-Hans": "速度：%@/秒", "hi": "गति: %@/सेकंड", "es": "Velocidad: %@/s", "fr": "Vitesse : %@/s", "ar": "السرعة: %@/ث", "pt": "Velocidade: %@/s"},
    "progress.remaining": {"en": "%@ remaining", "zh-Hans": "剩余 %@", "hi": "%@ शेष", "es": "Quedan %@", "fr": "%@ restantes", "ar": "تبقى %@", "pt": "Faltam %@"},
    "progress.pause":     {"en": "Pause", "zh-Hans": "暂停", "hi": "रोकें", "es": "Pausar", "fr": "Pause", "ar": "إيقاف مؤقت", "pt": "Pausar"},
    "progress.resume":    {"en": "Resume", "zh-Hans": "继续", "hi": "जारी रखें", "es": "Reanudar", "fr": "Reprendre", "ar": "استئناف", "pt": "Retomar"},
    "progress.cancel":    {"en": "Cancel", "zh-Hans": "取消", "hi": "रद्द करें", "es": "Cancelar", "fr": "Annuler", "ar": "إلغاء", "pt": "Cancelar"},

    "state.waitingAccept": {"en": "Waiting for acceptance…", "zh-Hans": "等待接受…", "hi": "स्वीकृति की प्रतीक्षा…", "es": "Esperando aceptación…", "fr": "En attente d'acceptation…", "ar": "في انتظار القبول…", "pt": "Aguardando aceitação…"},
    "state.preparing":     {"en": "Preparing…", "zh-Hans": "准备中…", "hi": "तैयारी जारी…", "es": "Preparando…", "fr": "Préparation…", "ar": "جارٍ التحضير…", "pt": "Preparando…"},
    "state.transferring":  {"en": "Transferring…", "zh-Hans": "传输中…", "hi": "स्थानांतरण जारी…", "es": "Transfiriendo…", "fr": "Transfert en cours…", "ar": "جارٍ التحويل…", "pt": "Transferindo…"},
    "state.paused":        {"en": "Paused", "zh-Hans": "已暂停", "hi": "रुका हुआ", "es": "Pausado", "fr": "En pause", "ar": "متوقف مؤقتاً", "pt": "Pausado"},
    "state.completed":     {"en": "Completed", "zh-Hans": "已完成", "hi": "पूर्ण", "es": "Completado", "fr": "Terminé", "ar": "مكتمل", "pt": "Concluído"},
    "state.failed":        {"en": "Failed", "zh-Hans": "失败", "hi": "असफल", "es": "Fallido", "fr": "Échec", "ar": "فشل", "pt": "Falhou"},
    "state.refused":       {"en": "Refused", "zh-Hans": "已拒绝", "hi": "अस्वीकृत", "es": "Rechazado", "fr": "Refusé", "ar": "مرفوض", "pt": "Recusado"},
    "state.cancelled":     {"en": "Cancelled", "zh-Hans": "已取消", "hi": "रद्द", "es": "Cancelado", "fr": "Annulé", "ar": "ملغى", "pt": "Cancelado"},

    "files.title":    {"en": "Files", "zh-Hans": "文件", "hi": "फ़ाइलें", "es": "Archivos", "fr": "Fichiers", "ar": "الملفات", "pt": "Arquivos"},
    "files.tab.all":       {"en": "All", "zh-Hans": "全部", "hi": "सभी", "es": "Todos", "fr": "Tous", "ar": "الكل", "pt": "Todos"},
    "files.tab.recent":    {"en": "Recent", "zh-Hans": "最近", "hi": "हाल के", "es": "Recientes", "fr": "Récents", "ar": "الحديثة", "pt": "Recentes"},
    "files.tab.received":  {"en": "Received", "zh-Hans": "已接收", "hi": "प्राप्त", "es": "Recibidos", "fr": "Reçus", "ar": "المستلمة", "pt": "Recebidos"},
    "files.tab.sent":      {"en": "Sent", "zh-Hans": "已发送", "hi": "भेजे गए", "es": "Enviados", "fr": "Envoyés", "ar": "المرسلة", "pt": "Enviados"},
    "files.tab.favorites": {"en": "Favorites", "zh-Hans": "收藏", "hi": "पसंदीदा", "es": "Favoritos", "fr": "Favoris", "ar": "المفضلة", "pt": "Favoritos"},
    "files.empty.title":    {"en": "No files yet", "zh-Hans": "还没有文件", "hi": "अभी कोई फ़ाइल नहीं", "es": "Aún no hay archivos", "fr": "Aucun fichier pour le moment", "ar": "لا توجد ملفات بعد", "pt": "Ainda não há arquivos"},
    "files.empty.subtitle": {"en": "Files you send and receive will appear here.", "zh-Hans": "您发送和接收的文件将显示在这里。", "hi": "आपकी भेजी और प्राप्त फ़ाइलें यहाँ दिखेंगी।", "es": "Los archivos que envíes y recibas aparecerán aquí.", "fr": "Les fichiers envoyés et reçus apparaîtront ici.", "ar": "ستظهر هنا الملفات التي ترسلها وتستلمها.", "pt": "Os arquivos que você envia e recebe aparecerão aqui."},
    "files.open":      {"en": "Open", "zh-Hans": "打开", "hi": "खोलें", "es": "Abrir", "fr": "Ouvrir", "ar": "فتح", "pt": "Abrir"},
    "files.share":     {"en": "Share", "zh-Hans": "分享", "hi": "साझा करें", "es": "Compartir", "fr": "Partager", "ar": "مشاركة", "pt": "Compartilhar"},
    "files.favorite":  {"en": "Favorite", "zh-Hans": "收藏", "hi": "पसंदीदा", "es": "Favorito", "fr": "Favori", "ar": "مفضلة", "pt": "Favoritar"},
    "files.delete":    {"en": "Delete", "zh-Hans": "删除", "hi": "मिटाएँ", "es": "Eliminar", "fr": "Supprimer", "ar": "حذف", "pt": "Excluir"},
    "files.newFolder": {"en": "New folder", "zh-Hans": "新建文件夹", "hi": "नया फ़ोल्डर", "es": "Nueva carpeta", "fr": "Nouveau dossier", "ar": "مجلد جديد", "pt": "Nova pasta"},
    "files.newFolder.name": {"en": "Folder name", "zh-Hans": "文件夹名称", "hi": "फ़ोल्डर का नाम", "es": "Nombre de la carpeta", "fr": "Nom du dossier", "ar": "اسم المجلد", "pt": "Nome da pasta"},

    "gallery.title":        {"en": "Gallery", "zh-Hans": "图库", "hi": "गैलरी", "es": "Galería", "fr": "Galerie", "ar": "المعرض", "pt": "Galeria"},
    "gallery.empty.title":    {"en": "No photos or videos", "zh-Hans": "没有照片或视频", "hi": "कोई तस्वीर या वीडियो नहीं", "es": "Sin fotos ni videos", "fr": "Aucune photo ni vidéo", "ar": "لا توجد صور أو مقاطع", "pt": "Sem fotos ou vídeos"},
    "gallery.empty.subtitle": {"en": "Import or receive media to see it here.", "zh-Hans": "导入或接收媒体文件后在此查看。", "hi": "मीडिया आयात या प्राप्त करने पर यहाँ दिखेगा।", "es": "Importa o recibe archivos multimedia para verlos aquí.", "fr": "Importez ou recevez des médias pour les voir ici.", "ar": "استورد أو استلم ملفات الوسائط لرؤيتها هنا.", "pt": "Importe ou receba mídias para vê-las aqui."},

    "music.title":       {"en": "Music", "zh-Hans": "音乐", "hi": "संगीत", "es": "Música", "fr": "Musique", "ar": "الموسيقى", "pt": "Música"},
    "music.empty.title":    {"en": "No music detected", "zh-Hans": "未检测到音乐", "hi": "कोई संगीत नहीं मिला", "es": "No se detectó música", "fr": "Aucune musique détectée", "ar": "لم يتم العثور على موسيقى", "pt": "Nenhuma música detectada"},
    "music.empty.subtitle": {"en": "Import or receive music files.", "zh-Hans": "导入或接收音乐文件。", "hi": "संगीत फ़ाइलें आयात करें या प्राप्त करें।", "es": "Importa o recibe archivos de música.", "fr": "Importez ou recevez des fichiers musicaux.", "ar": "استورد أو استلم ملفات الموسيقى.", "pt": "Importe ou receba arquivos de música."},

    "history.title":        {"en": "Transfer history", "zh-Hans": "传输历史", "hi": "स्थानांतरण इतिहास", "es": "Historial de transferencias", "fr": "Historique des transferts", "ar": "سجل التحويلات", "pt": "Histórico de transferências"},
    "history.empty.title":    {"en": "No transfers yet", "zh-Hans": "还没有传输记录", "hi": "अभी कोई स्थानांतरण नहीं", "es": "Aún no hay transferencias", "fr": "Aucun transfert pour le moment", "ar": "لا توجد تحويلات بعد", "pt": "Ainda não há transferências    "history.empty.subtitle": {"en": "Your transfers will appear here.", "zh-Hans": "您的传输记录将显示在这里。", "hi": "आपके स्थानांतरण यहाँ दिखेंगे।", "es": "Tus transferencias aparecerán aquí.", "fr": "Vos transferts apparaîtront ici.", "ar": "ستظهر تحويلاتك هنا.", "pt": "Suas transferências aparecerão aqui."},
    "history.clearAll":     {"en": "Clear all history", "zh-Hans": "清除全部历史", "hi": "सारा इतिहास मिटाएँ", "es": "Borrar todo el historial", "fr": "Effacer tout l'historique", "ar": "مسح كل السجل", "pt": "Apagar todo o histórico"},
    "history.cleared":      {"en": "History cleared", "zh-Hans": "历史已清除", "hi": "इतिहास मिटा दिया गया", "es": "Historial borrado", "fr": "Historique effacé", "ar": "تم مسح السجل", "pt": "Histórico apagado"},

    "settings.title":        {"en": "Settings", "zh-Hans": "设置", "hi": "सेटिंग्स", "es": "Ajustes", "fr": "Paramètres", "ar": "الإعدادات", "pt": "Configurações"},
    "settings.profile":      {"en": "PROFILE", "zh-Hans": "个人资料", "hi": "प्रोफ़ाइल", "es": "PERFIL", "fr": "PROFIL", "ar": "الملف الشخصي", "pt": "PERFIL"},
    "settings.appearance":   {"en": "APPEARANCE", "zh-Hans": "外观", "hi": "दिखावट", "es": "APARIENCIA", "fr": "APPARENCE", "ar": "المظهر", "pt": "APARÊNCIA"},
    "settings.appearance.theme": {"en": "Theme", "zh-Hans": "主题", "hi": "थीम", "es": "Tema", "fr": "Thème", "ar": "المظهر", "pt": "Tema"},
    "settings.appearance.auto":  {"en": "Automatic", "zh-Hans": "自动", "hi": "स्वचालित", "es": "Automático", "fr": "Automatique", "ar": "تلقائي", "pt": "Automático"},
    "settings.appearance.light": {"en": "Light", "zh-Hans": "浅色", "hi": "हल्का", "es": "Claro", "fr": "Clair", "ar": "فاتح", "pt": "Claro"},
    "settings.appearance.dark":  {"en": "Dark", "zh-Hans": "深色", "hi": "गहरा", "es": "Oscuro", "fr": "Sombre", "ar": "داكن", "pt": "Escuro"},
    "settings.language":     {"en": "LANGUAGE", "zh-Hans": "语言", "hi": "भाषा", "es": "IDIOMA", "fr": "LANGUE", "ar": "اللغة", "pt": "IDIOMA"},
    "settings.language.auto": {"en": "Automatic (phone language)", "zh-Hans": "自动（手机语言）", "hi": "स्वचालित (फ़ोन भाषा)", "es": "Automático (idioma del teléfono)", "fr": "Automatique (langue du téléphone)", "ar": "تلقائي (لغة الهاتف)", "pt": "Automático (idioma do telefone)"},
    "settings.transfers":    {"en": "TRANSFERS", "zh-Hans": "传输", "hi": "स्थानांतरण", "es": "TRANSFERENCIAS", "fr": "TRANSFERTS", "ar": "التحويلات", "pt": "TRANSFERÊNCIAS"},
    "settings.transfers.wifiOnly": {"en": "Transfer over Wi-Fi only", "zh-Hans": "仅通过 Wi-Fi 传输", "hi": "केवल Wi-Fi पर स्थानांतरण", "es": "Transferir solo por Wi-Fi", "fr": "Transférer uniquement via Wi-Fi", "ar": "التحويل عبر Wi-Fi فقط", "pt": "Transferir apenas por Wi-Fi"},
    "settings.transfers.autoAccept": {"en": "Auto-accept from trusted devices", "zh-Hans": "自动接受信任设备", "hi": "विश्वसनीय उपकरणों से स्वतः स्वीकार", "es": "Aceptar automáticamente de dispositivos de confianza", "fr": "Accepter automatiquement des appareils de confiance", "ar": "قبول تلقائي من الأجهزة الموثوقة", "pt": "Aceitar automaticamente de dispositivos confiáveis"},
    "settings.devices":      {"en": "DEVICES", "zh-Hans": "设备", "hi": "उपकरण", "es": "DISPOSITIVOS", "fr": "APPAREILS", "ar": "الأجهزة", "pt": "DISPOSITIVOS"},
    "settings.devices.list": {"en": "Manage devices", "zh-Hans": "管理设备", "hi": "उपकरण प्रबंधित करें", "es": "Gestionar dispositivos", "fr": "Gérer les appareils", "ar": "إدارة الأجهزة", "pt": "Gerenciar dispositivos"},
    "settings.notifications": {"en": "NOTIFICATIONS", "zh-Hans": "通知", "hi": "सूचनाएँ", "es": "NOTIFICACIONES", "fr": "NOTIFICATIONS", "ar": "الإشعارات", "pt": "NOTIFICAÇÕES"},
    "settings.notifications.complete": {"en": "Notify when transfers complete", "zh-Hans": "传输完成时通知", "hi": "स्थानांतरण पूर्ण होने पर सूचित करें", "es": "Notificar al completar transferencias", "fr": "Notifier à la fin des transferts", "ar": "إشعار عند اكتمال التحويل", "pt": "Notificar ao concluir transferências"},
    "settings.notifications.incoming": {"en": "Notify on incoming transfers", "zh-Hans": "有传入传输时通知", "hi": "आने वाले स्थानांतरण पर सूचित करें", "es": "Notificar transferencias entrantes", "fr": "Notifier les transferts entrants", "ar": "إشعار بالتحويلات الواردة", "pt": "Notificar transferências recebidas"},
    "settings.storage":      {"en": "STORAGE", "zh-Hans": "存储", "hi": "भंडारण", "es": "ALMACENAMIENTO", "fr": "STOCKAGE", "ar": "التخزين", "pt": "ARMAZENAMENTO"},
    "settings.storage.clearCache": {"en": "Clear cache", "zh-Hans": "清除缓存", "hi": "कैश साफ़ करें", "es": "Borrar caché", "fr": "Vider le cache", "ar": "مسح الذاكرة المؤقتة", "pt": "Limpar cache"},
    "settings.privacy":      {"en": "PRIVACY & SECURITY", "zh-Hans": "隐私与安全", "hi": "गोपनीयता और सुरक्षा", "es": "PRIVACIDAD Y SEGURIDAD", "fr": "CONFIDENTIALITÉ ET SÉCURITÉ", "ar": "الخصوصية والأمان", "pt": "PRIVACIDADE E SEGURANÇA"},
    "settings.privacy.encryption": {"en": "Encryption", "zh-Hans": "加密", "hi": "एन्क्रिप्शन", "es": "Cifrado", "fr": "Chiffrement", "ar": "التشفير", "pt": "Criptografia"},
    "settings.privacy.erase":      {"en": "Erase all data", "zh-Hans": "抹掉所有数据", "hi": "सारा डेटा मिटाएँ", "es": "Borrar todos los datos", "fr": "Effacer toutes les données", "ar": "مسح جميع البيانات", "pt": "Apagar todos os dados"},
    "settings.about":        {"en": "ABOUT", "zh-Hans": "关于", "hi": "परिचय", "es": "ACERCA DE", "fr": "À PROPOS", "ar": "حول", "pt": "SOBRE"},

    "tab.home":     {"en": "Home", "zh-Hans": "首页", "hi": "होम", "es": "Inicio", "fr": "Accueil", "ar": "الرئيسية", "pt": "Início"},
    "tab.files":    {"en": "Files", "zh-Hans": "文件", "hi": "फ़ाइलें", "es": "Archivos", "fr": "Fichiers", "ar": "الملفات", "pt": "Arquivos"},
    "tab.receive":  {"en": "Receive", "zh-Hans": "接收", "hi": "प्राप्त करें", "es": "Recibir", "fr": "Recevoir", "ar": "استلام", "pt": "Receber"},
    "tab.settings": {"en": "Settings", "zh-Hans": "设置", "hi": "सेटिंग्स", "es": "Ajustes", "fr": "Paramètres", "ar": "الإعدادات", "pt": "Configurações"},

    "notif.sent.title":     {"en": "Transfer complete", "zh-Hans": "传输完成", "hi": "स्थानांतरण पूर्ण", "es": "Transferencia completa", "fr": "Transfert terminé", "ar": "اكتمل التحويل", "pt": "Transferência concluída"},
    "notif.sent.body":      {"en": "Your files were sent successfully.", "zh-Hans": "文件发送成功。", "hi": "आपकी फ़ाइलें सफलतापूर्वक भेजी गईं।", "es": "Tus archivos se enviaron con éxito.", "fr": "Vos fichiers ont été envoyés avec succès.", "ar": "تم إرسال ملفاتك بنجاح.", "pt": "Seus arquivos foram enviados com sucesso."},
    "notif.incoming.title": {"en": "Incoming transfer", "zh-Hans": "传入传输", "hi": "आने वाला स्थानांतरण", "es": "Transferencia entrante", "fr": "Transfert entrant", "ar": "تحويل وارد", "pt": "Transferência recebida"},
    "notif.incoming.body":  {"en": "Someone is sending you files. Open Fylio to accept.", "zh-Hans": "有人正在向您发送文件。打开 Fylio 接受。", "hi": "कोई आपको फ़ाइलें भेज रहा है। स्वीकार करने के लिए Fylio खोलें।", "es": "Alguien te está enviando archivos. Abre Fylio para aceptar.", "fr": "Quelqu'un vous envoie des fichiers. Ouvrez Fylio pour accepter.", "ar": "شخص يرسل إليك ملفات. افتح Fylio للقبول.", "pt": "Alguém está enviando arquivos para você. Abra o Fylio para aceitar."},

    "preview.unavailable": {"en": "Preview unavailable", "zh-Hans": "无法预览", "hi": "पूर्वावलोकन अनुपलब्ध", "es": "Vista previa no disponible", "fr": "Aperçu indisponible", "ar": "المعاينة غير متوفرة", "pt": "Pré-visualização indisponível"},
    "pdf.search":   {"en": "Search in PDF", "zh-Hans": "在 PDF 中搜索", "hi": "PDF में खोजें", "es": "Buscar en PDF", "fr": "Rechercher dans le PDF", "ar": "البحث في PDF", "pt": "Pesquisar no PDF"},
    "sort.recent":  {"en": "Recent", "zh-Hans": "最近", "hi": "हाल के", "es": "Recientes", "fr": "Récents", "ar": "الحديثة", "pt": "Recentes"},
    "sort.name":    {"en": "Name", "zh-Hans": "名称", "hi": "नाम", "es": "Nombre", "fr": "Nom", "ar": "الاسم", "pt": "Nome"},
    "sort.size":    {"en": "Size", "zh-Hans": "大小", "hi": "आकार", "es": "Tamaño", "fr": "Taille", "ar": "الحجم", "pt": "Tamanho"},
}


def build_xcstrings() -> dict:
    strings = {}
    for key, translations in TABLE.items():
        localizations = {}
        for lang, value in translations.items():
            localizations[lang] = {
                "stringUnit": {"state": "translated", "value": value}
            }
        strings[key] = {
            "extractionState": "manual",
            "localizations": localizations,
        }
    return {
        "sourceLanguage": "en",
        "strings": strings,
        "version": "1.0",
    }


def main():
    project_root = Path(__file__).resolve().parents[1]
    output = project_root / "Fylio" / "Localizable.xcstrings"
    output.parent.mkdir(parents=True, exist_ok=True)
    catalog = build_xcstrings()
    output.write_text(json.dumps(catalog, ensure_ascii=False, indent=2),
                      encoding="utf-8")
    keys = len(TABLE)
    print(f"OK — Localizable.xcstrings généré : {keys} clés × {len(LANGS)} langues → {output}")


if __name__ == "__main__":
    main()
```

**Exécution :** `python3 scripts/build_localizable.py` → génère `Fylio/Localizable.xcstrings` (7 langues, RTL inclus pour l'arabe via le support natif xcstrings).
