#!/usr/bin/env python3
"""Fylio — Génère Localizable.xcstrings (7 langues) à partir de la table i18n.
Les deux corruptions du doc (ligne send.title dupliquée, history.empty fusionnée)
sont corrigées : on ne garde que les dicts complets."""
import json, os

LANGS = ["en", "zh-Hans", "hi", "es", "fr", "ar", "pt"]

TABLE = {
    # ── Common ──
    "common.seeAll":    {"en": "See all", "zh-Hans": "查看全部", "hi": "सभी देखें", "es": "Ver todo", "fr": "Voir tout", "ar": "عرض الكل", "pt": "Ver tudo"},
    "common.search":    {"en": "Search", "zh-Hans": "搜索", "hi": "खोजें", "es": "Buscar", "fr": "Rechercher", "ar": "بحث", "pt": "Pesquisar"},
    "common.preview":   {"en": "Preview", "zh-Hans": "预览", "hi": "पूर्वावलोकन", "es": "Vista previa", "fr": "Aperçu", "ar": "معاينة", "pt": "Pré-visualização"},
    "common.create":    {"en": "Create", "zh-Hans": "创建", "hi": "बनाएं", "es": "Crear", "fr": "Créer", "ar": "إنشاء", "pt": "Criar"},
    "common.cancel":    {"en": "Cancel", "zh-Hans": "取消", "hi": "रद्द करें", "es": "Cancelar", "fr": "Annuler", "ar": "إلغاء", "pt": "Cancelar"},
    "common.close":     {"en": "Close", "zh-Hans": "关闭", "hi": "बंद करें", "es": "Cerrar", "fr": "Fermer", "ar": "إغلاق", "pt": "Fechar"},
    "common.done":      {"en": "Done", "zh-Hans": "完成", "hi": "पूर्ण", "es": "Hecho", "fr": "Terminé", "ar": "تم", "pt": "Concluído"},
    "common.retry":     {"en": "Retry", "zh-Hans": "重试", "hi": "पुनः प्रयास करें", "es": "Reintentar", "fr": "Réessayer", "ar": "إعادة المحاولة", "pt": "Tentar novamente"},

    # ── Home ──
    "home.hello":         {"en": "Hello %@ 👋", "zh-Hans": "你好 %@ 👋", "hi": "नमस्ते %@ 👋", "es": "Hola %@ 👋", "fr": "Salut %@ 👋", "ar": "مرحباً %@ 👋", "pt": "Olá %@ 👋"},
    "home.greeting":      {"en": "Ready to share", "zh-Hans": "准备好分享", "hi": "साझा करने के लिए तैयार", "es": "Listo para compartir", "fr": "Prêt à partager", "ar": "جاهز للمشاركة", "pt": "Pronto para partilhar"},
    "home.send":          {"en": "Send", "zh-Hans": "发送", "hi": "भेजें", "es": "Enviar", "fr": "Envoyer", "ar": "إرسال", "pt": "Enviar"},
    "home.send.subtitle":  {"en": "Files, photos, videos…", "zh-Hans": "文件、照片、视频…", "hi": "फ़ाइलें, फ़ोटो, वीडियो…", "es": "Archivos, fotos, vídeos…", "fr": "Fichiers, photos, vidéos…", "ar": "الملفات والصور والفيديوهات…", "pt": "Ficheiros, fotos, vídeos…"},
    "home.receive":       {"en": "Receive", "zh-Hans": "接收", "hi": "प्राप्त करें", "es": "Recibir", "fr": "Recevoir", "ar": "استقبال", "pt": "Receber"},
    "home.receive.subtitle": {"en": "From nearby devices", "zh-Hans": "从附近的设备", "hi": "आस-पास के डिवाइस से", "es": "Desde dispositivos cercanos", "fr": "Depuis les appareils à proximité", "ar": "من الأجهزة القريبة", "pt": "De dispositivos próximos"},
    "home.recentDevices": {"en": "Recent devices", "zh-Hans": "最近设备", "hi": "हाल के उपकरण", "es": "Dispositivos recientes", "fr": "Appareils récents", "ar": "الأجهزة الأخيرة", "pt": "Dispositivos recentes"},
    "home.transferHistory": {"en": "Transfer history", "zh-Hans": "传输记录", "hi": "स्थानांतरण इतिहास", "es": "Historial de transferencias", "fr": "Historique des transferts", "ar": "سجل التحويلات", "pt": "Histórico de transferências"},
# ── Send ──
    "send.title":          {"en": "Send", "zh-Hans": "发送", "hi": "भेजें", "es": "Enviar", "fr": "Envoyer", "ar": "إرسال", "pt": "Enviar"},
    "send.chooseFolder":   {"en": "Choose a folder", "zh-Hans": "选择文件夹", "hi": "फ़ोल्डर चुनें", "es": "Elegir carpeta", "fr": "Choisir un dossier", "ar": "اختر مجلداً", "pt": "Escolher pasta"},
    "send.selectDestination": {"en": "Select destination", "zh-Hans": "选择目的地", "hi": "गंतव्य चुनें", "es": "Seleccionar destino", "fr": "Choisissez la destination", "ar": "اختر الوجهة", "pt": "Selecionar destino"},
    "send.toComputer":     {"en": "Send to computer", "zh-Hans": "发送到电脑", "hi": "कंप्यूटर पर भेजें", "es": "Enviar al ordenador", "fr": "Envoyer vers un ordinateur", "ar": "إرسال إلى الكمبيوتر", "pt": "Enviar para computador"},
    "send.empty":          {"en": "No files yet", "zh-Hans": "还没有文件", "hi": "अभी कोई फ़ाइल नहीं", "es": "Aún no hay archivos", "fr": "Aucun fichier pour le moment", "ar": "لا توجد ملفات بعد", "pt": "Ainda não há ficheiros"},
    "send.offline":        {"en": "No device connected", "zh-Hans": "没有连接的设备", "hi": "कोई डिवाइस कनेक्ट नहीं", "es": "No hay dispositivo conectado", "fr": "Aucun appareil connecté", "ar": "لا يوجد جهاز متصل", "pt": "Nenhum dispositivo ligado"},
    "send.send":           {"en": "Send", "zh-Hans": "发送", "hi": "भेजें", "es": "Enviar", "fr": "Envoyer", "ar": "إرسال", "pt": "Enviar"},

    # ── Receive ──
    "receive.title":   {"en": "Receive", "zh-Hans": "接收", "hi": "प्राप्त करें", "es": "Recibir", "fr": "Recevoir", "ar": "استقبال", "pt": "Receber"},
    "receive.showQr":  {"en": "Show QR code", "zh-Hans": "显示二维码", "hi": "QR कोड दिखाएं", "es": "Mostrar código QR", "fr": "Afficher le QR code", "ar": "إظهار رمز QR", "pt": "Mostrar código QR"},
    "receive.media":   {"en": "Media", "zh-Hans": "媒体", "hi": "मीडिया", "es": "Multimedia", "fr": "Médias", "ar": "وسائط", "pt": "Multimédia"},
    "receive.photos":  {"en": "Photos", "zh-Hans": "照片", "hi": "तस्वीरें", "es": "Fotos", "fr": "Photos", "ar": "صور", "pt": "Fotos"},
    "receive.history": {"en": "Recent transfers", "zh-Hans": "最近传输", "hi": "हाल के स्थानांतरण", "es": "Transferencias recientes", "fr": "Transferts récents", "ar": "التحويلات الأخيرة", "pt": "Transferências recentes"},
    "receive.devices": {"en": "Devices", "zh-Hans": "设备", "hi": "डिवाइस", "es": "Dispositivos", "fr": "Appareils", "ar": "الأجهزة", "pt": "Dispositivos"},

    # ── Devices ──
    "devices.title":       {"en": "Devices", "zh-Hans": "设备", "hi": "डिवाइस", "es": "Dispositivos", "fr": "Appareils", "ar": "الأجهزة", "pt": "Dispositivos"},
    "devices.noDevices":   {"en": "No devices yet", "zh-Hans": "还没有设备", "hi": "अभी कोई डिवाइस नहीं", "es": "Aún no hay dispositivos", "fr": "Aucun appareil pour le moment", "ar": "لا توجد أجهزة بعد", "pt": "Ainda não há dispositivos"},
    "devices.connectFirst": {"en": "Connect a device to start transferring", "zh-Hans": "连接设备开始传输", "hi": "स्थानांतरण शुरू करने के लिए डिवाइस कनेक्ट करें", "es": "Conecta un dispositivo para transferir", "fr": "Connectez un appareil pour commencer", "ar": "قم بتوصيل جهاز للبدء", "pt": "Ligue um dispositivo para começar"},
    "devices.scanQr":      {"en": "Scan a QR code", "zh-Hans": "扫描二维码", "hi": "QR कोड स्कैन करें", "es": "Escanear código QR", "fr": "Scanner un QR code", "ar": "مسح رمز QR", "pt": "Digitalizar código QR"},
    "devices.rename":      {"en": "Rename", "zh-Hans": "重命名", "hi": "नाम बदलें", "es": "Renombrar", "fr": "Renommer", "ar": "إعادة تسمية", "pt": "Renomear"},
    "devices.delete":      {"en": "Delete", "zh-Hans": "删除", "hi": "हटाएं", "es": "Eliminar", "fr": "Supprimer", "ar": "حذف", "pt": "Eliminar"},
# ── Files ──
    "files.title":    {"en": "Files", "zh-Hans": "文件", "hi": "फ़ाइलें", "es": "Archivos", "fr": "Fichiers", "ar": "الملفات", "pt": "Ficheiros"},
    "files.empty":    {"en": "No files", "zh-Hans": "没有文件", "hi": "कोई फ़ाइल नहीं", "es": "Sin archivos", "fr": "Aucun fichier", "ar": "لا ملفات", "pt": "Sem ficheiros"},
    "files.character": {"en": "Your transferred files will appear here", "zh-Hans": "传输的文件将显示在这里", "hi": "आपकी स्थानांतरित फ़ाइलें यहाँ दिखेंगी", "es": "Tus archivos transferidos aparecerán aquí", "fr": "Vos fichiers transférés apparaîtront ici", "ar": "ستظهر ملفاتك المنقولة هنا", "pt": "Os seus ficheiros transferidos aparecerão aqui"},

    # ── Gallery ──
    "gallery.title":   {"en": "Gallery", "zh-Hans": "相册", "hi": "गैलरी", "es": "Galería", "fr": "Galerie", "ar": "المعرض", "pt": "Galeria"},
    "gallery.empty":   {"en": "No photos or videos yet", "zh-Hans": "还没有照片或视频", "hi": "अभी कोई फ़ोटो या वीडियो नहीं", "es": "Aún no hay fotos ni vídeos", "fr": "Aucune photo ou vidéo pour le moment", "ar": "لا توجد صور أو مقاطع فيديو بعد", "pt": "Ainda não há fotos ou vídeos"},
    "gallery.selectToShare": {"en": "Select items to share", "zh-Hans": "选择要分享的项目", "hi": "साझा करने के लिए आइटम चुनें", "es": "Selecciona elementos para compartir", "fr": "Sélectionnez des éléments à partager", "ar": "حدد عناصر للمشاركة", "pt": "Selecione itens para partilhar"},

    # ── Music ──
    "music.title":      {"en": "Music", "zh-Hans": "音乐", "hi": "संगीत", "es": "Música", "fr": "Musique", "ar": "موسيقى", "pt": "Música"},
    "music.empty":      {"en": "No music found", "zh-Hans": "未找到音乐", "hi": "कोई संगीत नहीं मिला", "es": "No se encontró música", "fr": "Aucune musique trouvée", "ar": "لا توجد موسيقى", "pt": "Nenhuma música encontrada"},
    "music.nowPlaying": {"en": "Now playing", "zh-Hans": "正在播放", "hi": "अभी चल रहा है", "es": "Reproduciendo", "fr": "En cours de lecture", "ar": "قيد التشغيل", "pt": "A tocar agora"},
    "music.playlist":   {"en": "Playlist", "zh-Hans": "播放列表", "hi": "प्लेलिस्ट", "es": "Lista de reproducción", "fr": "Playlist", "ar": "قائمة التشغيل", "pt": "Lista de reprodução"},

    # ── History ──
    "history.title":    {"en": "History", "zh-Hans": "历史记录", "hi": "इतिहास", "es": "Historial", "fr": "Historique", "ar": "السجل", "pt": "Histórico"},
    "history.sent":     {"en": "Sent", "zh-Hans": "已发送", "hi": "भेजा गया", "es": "Enviado", "fr": "Envoyé", "ar": "أُرسل", "pt": "Enviado"},
    "history.received": {"en": "Received", "zh-Hans": "已接收", "hi": "प्राप्त किया", "es": "Recibido", "fr": "Reçu", "ar": "مُستلَم", "pt": "Recebido"},
    # (corruption corrigée : les deux clés étaient fusionnées sur la même ligne)
    "history.empty.title":    {"en": "No transfers yet", "zh-Hans": "还没有传输记录", "hi": "अभी कोई स्थानांतरण नहीं", "es": "Aún no hay transferencias", "fr": "Aucun transfert pour le moment", "ar": "لا توجد تحويلات بعد", "pt": "Ainda não há transferências"},
    "history.empty.subtitle": {"en": "Your transfers will appear here", "zh-Hans": "您的传输将显示在这里", "hi": "आपके स्थानांतरण यहाँ दिखेंगे", "es": "Tus transferencias aparecerán aquí", "fr": "Vos transferts apparaîtront ici", "ar": "ستظهر تحويلاتك هنا", "pt": "As suas transferências aparecerão aqui"},
# ── Settings ──
    "settings.title":   {"en": "Settings", "zh-Hans": "设置", "hi": "सेटिंग्स", "es": "Ajustes", "fr": "Réglages", "ar": "الإعدادات", "pt": "Definições"},
    "settings.profile": {"en": "Profile", "zh-Hans": "个人资料", "hi": "प्रोफ़ाइल", "es": "Perfil", "fr": "Profil", "ar": "الملف الشخصي", "pt": "Perfil"},
    "settings.notifications": {"en": "Notifications", "zh-Hans": "通知", "hi": "सूचनाएँ", "es": "Notificaciones", "fr": "Notifications", "ar": "الإشعارات", "pt": "Notificações"},
    "settings.about":   {"en": "About", "zh-Hans": "关于", "hi": "परिचय", "es": "Acerca de", "fr": "À propos", "ar": "حول", "pt": "Sobre"},
    "settings.version": {"en": "Version", "zh-Hans": "版本", "hi": "संस्करण", "es": "Versión", "fr": "Version", "ar": "الإصدار", "pt": "Versão"},

    # ── Notifications ──
    "notifications.enabled":  {"en": "Notifications enabled", "zh-Hans": "通知已启用", "hi": "सूचनाएँ सक्षम", "es": "Notificaciones activadas", "fr": "Notifications activées", "ar": "الإشعارات مفعلة", "pt": "Notificações ativadas"},
    "notifications.disabled": {"en": "Notifications disabled", "zh-Hans": "通知已禁用", "hi": "सूचनाएँ अक्षम", "es": "Notificaciones desactivadas", "fr": "Notifications désactivées", "ar": "الإشعارات معطلة", "pt": "Notificações desativadas"},

    # ── QR Scanner ──
    "qr.title":   {"en": "Scan QR code", "zh-Hans": "扫描二维码", "hi": "QR कोड स्कैन करें", "es": "Escanear código QR", "fr": "Scanner un QR code", "ar": "مسح رمز QR", "pt": "Digitalizar código QR"},
    "qr.invalid": {"en": "Invalid QR code", "zh-Hans": "无效的二维码", "hi": "अमान्य QR कोड", "es": "Código QR inválido", "fr": "QR code invalide", "ar": "رمز QR غير صالح", "pt": "Código QR inválido"},

    # ── Progress ──
    "progress.preparing":    {"en": "Preparing…", "zh-Hans": "正在准备…", "hi": "तैयार हो रहा है…", "es": "Preparando…", "fr": "Préparation…", "ar": "جارٍ التحضير…", "pt": "A preparar…"},
    "progress.transferring": {"en": "Transferring…", "zh-Hans": "传输中…", "hi": "स्थानांतरित…", "es": "Transfiriendo…", "fr": "Transfert en cours…", "ar": "جارٍ النقل…", "pt": "A transferir…"},
    "progress.paused":       {"en": "Paused", "zh-Hans": "已暂停", "hi": "रोका गया", "es": "Pausado", "fr": "En pause", "ar": "متوقف مؤقتاً", "pt": "Em pausa"},

    # ── Onboarding ──
    "onboarding.welcome":           {"en": "Welcome to Fylio", "zh-Hans": "欢迎使用 Fylio", "hi": "Fylio में आपका स्वागत है", "es": "Bienvenido a Fylio", "fr": "Bienvenue sur Fylio", "ar": "مرحباً بك في Fylio", "pt": "Bem-vindo ao Fylio"},
    "onboarding.chooseAvatar":      {"en": "Choose your avatar", "zh-Hans": "选择你的头像", "hi": "अपना अवतार चुनें", "es": "Elige tu avatar", "fr": "Choisissez votre avatar", "ar": "اختر صورتك الرمزية", "pt": "Escolha o seu avatar"},
    "onboarding.yourName":          {"en": "Your name", "zh-Hans": "你的名字", "hi": "आपका नाम", "es": "Tu nombre", "fr": "Votre nom", "ar": "اسمك", "pt": "O seu nome"},
    "onboarding.permissions":       {"en": "Permissions", "zh-Hans": "权限", "hi": "अनुमतियाँ", "es": "Permisos", "fr": "Autorisations", "ar": "الأذونات", "pt": "Permissões"},
    "onboarding.transferMethods":   {"en": "Transfer methods", "zh-Hans": "传输方式", "hi": "स्थानांतरण विधियाँ", "es": "Métodos de transferencia", "fr": "Méthodes de transfert", "ar": "طرق النقل", "pt": "Métodos de transferência"},
    "onboarding.avatar.importPhoto": {"en": "Import a photo", "zh-Hans": "导入照片", "hi": "एक फ़ोटो आयात करें", "es": "Importar una foto", "fr": "Importer une photo", "ar": "استيراد صورة", "pt": "Importar uma foto"},

    # ── Guide Vocal ──
    "guide.title":    {"en": "Welcome to Fylio!", "zh-Hans": "欢迎使用 Fylio！", "hi": "Fylio में आपका स्वागत है!", "es": "¡Bienvenido a Fylio!", "fr": "Bienvenue sur Fylio !", "ar": "مرحبا بك في Fylio!", "pt": "Bem-vindo ao Fylio!"},
    "guide.subtitle": {"en": "Tap Send or Receive to start a transfer.", "zh-Hans": "点击发送或接收开始传输。", "hi": "स्थानांतरण शुरू करने के लिए भेजें या प्राप्त करें दबाएँ।", "es": "Toca Enviar o Recibir para empezar.", "fr": "Touchez Envoyer ou Recevoir pour commencer.", "ar": "اضغط على إرسال أو استلام للبدء.", "pt": "Toque em Enviar ou Receber para começar."},

    # ── PDF Editor ──
    "pdf.saved":        {"en": "PDF saved", "zh-Hans": "PDF 已保存", "hi": "PDF सहेजा गया", "es": "PDF guardado", "fr": "PDF enregistré", "ar": "تم حفظ PDF", "pt": "PDF salvo"},
    "pdf.saveFailed":   {"en": "Save failed", "zh-Hans": "保存失败", "hi": "सहेजना असफल", "es": "Error al guardar", "fr": "Échec de l'enregistrement", "ar": "فشل الحفظ", "pt": "Falha ao salvar"},
    "pdf.tool.highlight": {"en": "Highlight", "zh-Hans": "高亮", "hi": "हाइलाइट", "es": "Resaltar", "fr": "Surligner", "ar": "تمييز", "pt": "Destacar"},
    "pdf.tool.pen":     {"en": "Pen", "zh-Hans": "画笔", "hi": "कलम", "es": "Lápiz", "fr": "Stylo", "ar": "قلم", "pt": "Caneta"},
    "pdf.tool.text":    {"en": "Text", "zh-Hans": "文本", "hi": "पाठ", "es": "Texto", "fr": "Texte", "ar": "نص", "pt": "Texto"},
    "pdf.tool.signature": {"en": "Signature", "zh-Hans": "签名", "hi": "हस्ताक्षर", "es": "Firma", "fr": "Signature", "ar": "توقيع", "pt": "Assinatura"},
    "pdf.rotatePage":   {"en": "Rotate page", "zh-Hans": "旋转页面", "hi": "पेज घुमाएँ", "es": "Girar página", "fr": "Pivoter la page", "ar": "تدوير الصفحة", "pt": "Girar página"},
    "pdf.deletePage":   {"en": "Delete page", "zh-Hans": "删除页面", "hi": "पेज मिटाएँ", "es": "Eliminar página", "fr": "Supprimer la page", "ar": "حذف الصفحة", "pt": "Excluir página"},

    # ── Tabs ──
    "tab.home":        {"en": "Home", "zh-Hans": "首页", "hi": "होम", "es": "Inicio", "fr": "Accueil", "ar": "الرئيسية", "pt": "Início"},
    "tab.files":       {"en": "Files", "zh-Hans": "文件", "hi": "फ़ाइलें", "es": "Archivos", "fr": "Fichiers", "ar": "الملفات", "pt": "Ficheiros"},
    "tab.gallery":     {"en": "Gallery", "zh-Hans": "相册", "hi": "गैलरी", "es": "Galería", "fr": "Galerie", "ar": "المعرض", "pt": "Galeria"},
    "tab.music":       {"en": "Music", "zh-Hans": "音乐", "hi": "संगीत", "es": "Música", "fr": "Musique", "ar": "موسيقى", "pt": "Música"},
    "tab.history":     {"en": "History", "zh-Hans": "历史记录", "hi": "इतिहास", "es": "Historial", "fr": "Historique", "ar": "السجل", "pt": "Histórico"},

    # ── App shell ──
    "feature.inProgress": {"en": "This feature is coming soon", "zh-Hans": "此功能即将推出", "hi": "यह सुविधा जल्द आ रही है", "es": "Esta función estará disponible pronto", "fr": "Cette fonctionnalité arrive bientôt", "ar": "هذه الميزة قريباً", "pt": "Em breve"},
    "home.alwaysConnected": {"en": "Always connected", "zh-Hans": "保持连接", "hi": "हमेशा जुड़े रहें", "es": "Siempre conectado", "fr": "Toujours connecté", "ar": "متصل دائماً", "pt": "Sempre conectado"},
    "history.cleared":  {"en": "History cleared", "zh-Hans": "历史记录已清除", "hi": "इतिहास साफ़ किया गया", "es": "Historial borrado", "fr": "Historique effacé", "ar": "تم مسح السجل", "pt": "Histórico apagado"},
    "receive.confirm":  {"en": "Accept", "zh-Hans": "接受", "hi": "स्वीकारें", "es": "Aceptar", "fr": "Accepter", "ar": "قبول", "pt": "Aceitar"},
    "notif.incoming.title": {"en": "Incoming transfer", "zh-Hans": "接收传输", "hi": "आने वाला स्थानांतरण", "es": "Transferencia entrante", "fr": "Transfert entrant", "ar": "نقل وارد", "pt": "Transferência recebida"},
    "notif.incoming.body":  {"en": "Someone nearby wants to send you files", "zh-Hans": "附近的某人想要给你发送文件", "hi": "पास में कोई आपको फ़ाइलें भेजना चाहता है", "es": "Alguien cercano quiere enviarte archivos", "fr": "Un appareil à proximité veut vous envoyer des fichiers", "ar": "يريد شخص قريب إرسال ملفات إليك", "pt": "Alguém próximo quer enviar-lhe ficheiros"},
    "notif.sent.title": {"en": "Sent", "zh-Hans": "已发送", "hi": "भेजा गया", "es": "Enviado", "fr": "Envoyé", "ar": "تم الإرسال", "pt": "Enviado"},
    "notif.sent.body":  {"en": "Your transfer completed successfully", "zh-Hans": "您的传输已成功完成", "hi": "आपका स्थानांतरण सफलतापूर्वक पूरा हुआ", "es": "Tu transferencia se completó correctamente", "fr": "Votre transfert s'est terminé avec succès", "ar": "اكتمل النقل بنجاح", "pt": "A sua transferência foi concluída com sucesso"},
    "state.transferring": {"en": "Transferring…", "zh-Hans": "传输中…", "hi": "स्थानांतरित…", "es": "Transfiriendo…", "fr": "Transfert en cours…", "ar": "جارٍ النقل…", "pt": "A transferir…"},
    "state.paused":       {"en": "Paused", "zh-Hans": "已暂停", "hi": "रोका गया", "es": "Pausado", "fr": "En pause", "ar": "متوقف مؤقتاً", "pt": "Em pausa"},

    # ── Onboarding screens ──
    "onboarding.welcome.title": {"en": "Welcome to Fylio", "zh-Hans": "欢迎使用 Fylio", "hi": "Fylio में आपका स्वागत है", "es": "Bienvenido a Fylio", "fr": "Bienvenue sur Fylio", "ar": "مرحباً بك في Fylio", "pt": "Bem-vindo ao Fylio"},
    "onboarding.next":       {"en": "Next", "zh-Hans": "下一步", "hi": "आगे", "es": "Siguiente", "fr": "Suivant", "ar": "التالي", "pt": "Seguinte"},
    "onboarding.done":       {"en": "Get started", "zh-Hans": "开始使用", "hi": "शुरू करें", "es": "Comenzar", "fr": "Commencer", "ar": "ابدأ", "pt": "Começar"},
    "onboarding.welcome.subtitle": {"en": "Send any file to any device, wirelessly and securely.", "zh-Hans": "将任何文件无线、安全地发送到任何设备。", "hi": "किसी भी फ़ाइल को किसी भी डिवाइस पर वायरलेस और सुरक्षित रूप से भेजें।", "es": "Envía cualquier archivo a cualquier dispositivo, de forma inalámbrica y segura.", "fr": "Envoyez n'importe quel fichier vers n'importe quel appareil, sans fil et en toute sécurité.", "ar": "أرسل أي ملف إلى أي جهاز، لاسلكياً وبأمان.", "pt": "Envie qualquer ficheiro para qualquer dispositivo, sem fios e de forma segura."},
    "onboarding.avatar.title": {"en": "Choose your avatar", "zh-Hans": "选择你的头像", "hi": "अपना अवतार चुनें", "es": "Elige tu avatar", "fr": "Choisissez votre avatar", "ar": "اختر صورتك الرمزية", "pt": "Escolha o seu avatar"},
    "onboarding.name.title": {"en": "Name your device", "zh-Hans": "命名你的设备", "hi": "अपने डिवाइस का नाम दें", "es": "Nombra tu dispositivo", "fr": "Nommez votre appareil", "ar": "سمّ جهازك", "pt": "Dê um nome ao seu dispositivo"},
    "onboarding.name.subtitle": {"en": "This is how friends will see you on the network.", "zh-Hans": "好友将通过此名称在网络中看到你。", "hi": "दोस्त आपको नेटवर्क पर इसी नाम से देखेंगे।", "es": "Así te verán tus amigos en la red.", "fr": "C'est ainsi que vos amis vous verront sur le réseau.", "ar": "هكذا سيراك أصدقاؤك على الشبكة.", "pt": "É assim que os amigos o verão na rede."},
    "onboarding.permissions.title": {"en": "Grant permissions", "zh-Hans": "授予权限", "hi": "अनुमतियाँ दें", "es": "Concede permisos", "fr": "Autoriser les accès", "ar": "منح الأذونات", "pt": "Conceder permissões"},
    "onboarding.permissions.0.title": {"en": "Local Network", "zh-Hans": "本地网络", "hi": "स्थानीय नेटवर्क", "es": "Red local", "fr": "Réseau local", "ar": "الشبكة المحلية", "pt": "Rede local"},
    "onboarding.permissions.0.subtitle": {"en": "Discover and connect to nearby devices.", "zh-Hans": "发现并连接附近的设备。", "hi": "पास के डिवाइस खोजें और कनेक्ट करें।", "es": "Descubre y conéctate a dispositivos cercanos.", "fr": "Découvrir et se connecter aux appareils à proximité.", "ar": "اكتشاف الأجهزة القريبة والاتصال بها.", "pt": "Descubra e ligue dispositivos próximos."},
    "onboarding.permissions.1.title": {"en": "Camera", "zh-Hans": "相机", "hi": "कैमरा", "es": "Cámara", "fr": "Appareil photo", "ar": "الكاميرا", "pt": "Câmara"},
    "onboarding.permissions.1.subtitle": {"en": "Scan QR codes to pair and transfer.", "zh-Hans": "扫描二维码以配对和传输。", "hi": "पेयर करने और स्थानांतरण के लिए QR कोड स्कैन करें।", "es": "Escanea códigos QR para parear y transferir.", "fr": "Scanner les QR codes pour appairer et transférer.", "ar": "مسح رموز QR للاقتران والنقل.", "pt": "Digitalize códigos QR para emparelhar e transferir."},
    "onboarding.permissions.2.title": {"en": "Photos", "zh-Hans": "照片", "hi": "तस्वीरें", "es": "Fotos", "fr": "Photos", "ar": "الصور", "pt": "Fotos"},
    "onboarding.permissions.2.subtitle": {"en": "Save received photos and videos to your library.", "zh-Hans": "将接收的照片和视频保存到你的相册。", "hi": "प्राप्त फ़ोटो और वीडियो अपनी लाइब्रेरी में सहेजें।", "es": "Guarda las fotos y vídeos recibidos en tu biblioteca.", "fr": "Enregistrer les photos et vidéos reçues dans votre bibliothèque.", "ar": "احفظ الصور والفيديوهات المستلمة في مكتبتك.", "pt": "Guarde as fotos e vídeos recebidos na sua biblioteca."},
    "onboarding.methods.title": {"en": "Transfer methods", "zh-Hans": "传输方式", "hi": "स्थानांतरण विधियाँ", "es": "Métodos de transferencia", "fr": "Méthodes de transfert", "ar": "طرق النقل", "pt": "Métodos de transferência"},
    "onboarding.methods.0.title": {"en": "Wi-Fi (local network)", "zh-Hans": "Wi-Fi（本地网络）", "hi": "वाई-फ़ाई (स्थानीय नेटवर्क)", "es": "Wi-Fi (red local)", "fr": "Wi-Fi (réseau local)", "ar": "واي فاي (الشبكة المحلية)", "pt": "Wi-Fi (rede local)"},
    "onboarding.methods.1.title": {"en": "QR code pairing", "zh-Hans": "二维码配对", "hi": "QR कोड पेयरिंग", "es": "Emparejamiento por QR", "fr": "Appairage par QR code", "ar": "الاقتران برمز QR", "pt": "Emparelhamento por QR"},
    "onboarding.methods.2.title": {"en": "Personal hotspot", "zh-Hans": "个人热点", "hi": "पर्सनल हॉटस्पॉट", "es": "Punto de acceso personal", "fr": "Point d'accès personnel", "ar": "نقطة اتصال شخصية", "pt": "Hotspot pessoal"},
    "onboarding.methods.3.title": {"en": "USB cable", "zh-Hans": "USB 数据线", "hi": "USB केबल", "es": "Cable USB", "fr": "Câble USB", "ar": "كابل USB", "pt": "Cabo USB"},
    "onboarding.methods.4.title": {"en": "Remote access", "zh-Hans": "远程访问", "hi": "दूरस्थ पहुँच", "es": "Acceso remoto", "fr": "Accès à distance", "ar": "الوصول عن بعد", "pt": "Acesso remoto"},
    "onboarding.methods.5.title": {"en": "Registered devices (Fylio ID)", "zh-Hans": "注册设备（Fylio ID）", "hi": "पंजीकृत डिवाइस (Fylio ID)", "es": "Dispositivos registrados (Fylio ID)", "fr": "Appareils enregistrés (Fylio ID)", "ar": "الأجهزة المسجلة (Fylio ID)", "pt": "Dispositivos registados (Fylio ID)"},

    # ── Tri (FileSortOrder) ──
    "sort.recent": {"en": "Recent", "zh-Hans": "最近", "hi": "हाल ही", "es": "Recientes", "fr": "Récents", "ar": "الأحدث", "pt": "Recentes"},
    "sort.name":   {"en": "Name", "zh-Hans": "名称", "hi": "नाम", "es": "Nombre", "fr": "Nom", "ar": "الاسم", "pt": "Nome"},
    "sort.size":   {"en": "Size", "zh-Hans": "大小", "hi": "आकार", "es": "Tamaño", "fr": "Taille", "ar": "الحجم", "pt": "Tamanho"},

    # ── Écran Envoyer (doc 14) ──
    "send.selectedCount": {"en": "%d selected", "zh-Hans": "已选择 %d 项", "hi": "%d चुने गए", "es": "%d seleccionados", "fr": "%d sélectionnés", "ar": "تم تحديد %d", "pt": "%d selecionados"},
    "send.pickDevice":    {"en": "Pick a device", "zh-Hans": "选择设备", "hi": "डिवाइस चुनें", "es": "Elige un dispositivo", "fr": "Choisissez un appareil", "ar": "اختر جهازاً", "pt": "Escolher um dispositivo"},

    # ── Écran Recevoir (doc 15) ──
    "receive.qr.hint":          {"en": "Scan this code with the other device", "zh-Hans": "用另一台设备扫描此代码", "hi": "इस कोड को दूसरे डिवाइस से स्कैन करें", "es": "Escanea este código con el otro dispositivo", "fr": "Scannez ce code avec l'autre appareil", "ar": "امسح هذا الرمز بالجهاز الآخر", "pt": "Digitalize este código com o outro dispositivo"},
    "receive.available":        {"en": "Available devices", "zh-Hans": "可用设备", "hi": "उपलब्ध डिवाइस", "es": "Dispositivos disponibles", "fr": "Appareils disponibles", "ar": "الأجهزة المتاحة", "pt": "Dispositivos disponíveis"},
    "receive.searching":        {"en": "Searching for devices…", "zh-Hans": "正在搜索设备…", "hi": "डिवाइस खोजे जा रहे हैं…", "es": "Buscando dispositivos…", "fr": "Recherche d'appareils…", "ar": "جارٍ البحث عن الأجهزة…", "pt": "À procura de dispositivos…"},
    "receive.searching.subtitle": {"en": "Make sure Wi-Fi is enabled", "zh-Hans": "请确保已开启 Wi-Fi", "hi": "सुनिश्चित करें कि वाई-फ़ाई चालू है", "es": "Asegúrate de que el Wi-Fi está activado", "fr": "Assurez-vous que le Wi-Fi est activé", "ar": "تأكد من تشغيل Wi-Fi", "pt": "Certifique-se de que o Wi-Fi está ligado"},
    "receive.incoming":         {"en": "Incoming requests", "zh-Hans": "接收请求", "hi": "आने वाले अनुरोध", "es": "Solicitudes entrantes", "fr": "Demandes entrantes", "ar": "الطلبات الواردة", "pt": "Pedidos recebidos"},
    "receive.noIncoming":       {"en": "No incoming requests", "zh-Hans": "暂无接收请求", "hi": "कोई आने वाला अनुरोध नहीं", "es": "No hay solicitudes entrantes", "fr": "Aucune demande entrante", "ar": "لا توجد طلبات واردة", "pt": "Sem pedidos recebidos"},
    "receive.incoming.detail":  {"en": "%d file(s) from %@", "zh-Hans": "%d 个文件来自 %@", "hi": "%d फ़ाइलें %@ से", "es": "%d archivo(s) de %@", "fr": "%d fichier(s) de %@", "ar": "%d ملف من %@", "pt": "%d ficheiro(s) de %@"},

    # ── Appareils (doc 16) ──
    "devices.empty.title":    {"en": "No saved devices", "zh-Hans": "没有已保存的设备", "hi": "कोई सहेजा गया डिवाइस नहीं", "es": "Sin dispositivos guardados", "fr": "Aucun appareil enregistré", "ar": "لا توجد أجهزة محفوظة", "pt": "Sem dispositivos guardados"},
    "devices.empty.subtitle": {"en": "Devices you connect to will be saved here", "zh-Hans": "您连接的设备将保存在这里", "hi": "आपके द्वारा कनेक्ट किए गए डिवाइस यहाँ सहेजे जाएँगे", "es": "Los dispositivos a los que te conectes se guardarán aquí", "fr": "Les appareils auxquels vous vous connectez seront enregistrés ici", "ar": "سيتم حفظ الأجهزة التي تتصل بها هنا", "pt": "Os dispositivos a que ligar serão guardados aqui"},

    # ── Progression (doc 16) ──
    "progress.title":     {"en": "Transfer", "zh-Hans": "传输", "hi": "स्थानांतरण", "es": "Transferencia", "fr": "Transfert", "ar": "نقل", "pt": "Transferência"},
    "progress.speed":     {"en": "Speed: %@", "zh-Hans": "速度：%@", "hi": "गति: %@", "es": "Velocidad: %@", "fr": "Vitesse : %@", "ar": "السرعة: %@", "pt": "Velocidade: %@"},
    "progress.remaining": {"en": "Remaining: %@", "zh-Hans": "剩余：%@", "hi": "शेष: %@", "es": "Restante: %@", "fr": "Restant : %@", "ar": "المتبقي: %@", "pt": "Restante: %@"},
    "progress.pause":     {"en": "Pause", "zh-Hans": "暂停", "hi": "रोकें", "es": "Pausar", "fr": "Pause", "ar": "إيقاف مؤقت", "pt": "Pausar"},
    "progress.resume":    {"en": "Resume", "zh-Hans": "继续", "hi": "जारी रखें", "es": "Reanudar", "fr": "Reprendre", "ar": "استئناف", "pt": "Retomar"},
    "progress.cancel":    {"en": "Cancel", "zh-Hans": "取消", "hi": "रद्द करें", "es": "Cancelar", "fr": "Annuler", "ar": "إلغاء", "pt": "Cancelar"},

    # ── Scanner QR (doc 16) ──
    "qr.scanner.hint": {"en": "Point your camera at the QR code", "zh-Hans": "将相机对准二维码", "hi": "कैमरे को QR कोड पर रखें", "es": "Apunta la cámara al código QR", "fr": "Visez le QR code avec l'appareil photo", "ar": "وجّه الكاميرا نحو رمز QR", "pt": "Aponte a câmara para o código QR"},

    # ── Fichiers (doc 17) ──
    "files.empty.title":    {"en": "No files yet", "zh-Hans": "还没有文件", "hi": "अभी कोई फ़ाइल नहीं", "es": "Aún no hay archivos", "fr": "Aucun fichier pour le moment", "ar": "لا توجد ملفات بعد", "pt": "Ainda não há ficheiros"},
    "files.empty.subtitle": {"en": "Transfer a file and it will appear here", "zh-Hans": "传输文件后它将显示在这里", "hi": "कोई फ़ाइल स्थानांतरित करने पर वह यहाँ दिखेगी", "es": "Transfiere un archivo y aparecerá aquí", "fr": "Transférez un fichier et il apparaîtra ici", "ar": "انقل ملفاً وسيظهر هنا", "pt": "Transfira um ficheiro e ele aparecerá aqui"},
    "files.newFolder":      {"en": "New folder", "zh-Hans": "新建文件夹", "hi": "नया फ़ोल्डर", "es": "Nueva carpeta", "fr": "Nouveau dossier", "ar": "مجلد جديد", "pt": "Nova pasta"},
    "files.newFolder.name": {"en": "Folder name", "zh-Hans": "文件夹名称", "hi": "फ़ोल्डर का नाम", "es": "Nombre de la carpeta", "fr": "Nom du dossier", "ar": "اسم المجلد", "pt": "Nome da pasta"},
    "files.open":           {"en": "Open", "zh-Hans": "打开", "hi": "खोलें", "es": "Abrir", "fr": "Ouvrir", "ar": "فتح", "pt": "Abrir"},
    "files.share":          {"en": "Share", "zh-Hans": "分享", "hi": "साझा करें", "es": "Compartir", "fr": "Partager", "ar": "مشاركة", "pt": "Partilhar"},
    "files.favorite":       {"en": "Favorite", "zh-Hans": "收藏", "hi": "पसंदीदा", "es": "Favorito", "fr": "Favori", "ar": "مفضّل", "pt": "Favorito"},
    "files.delete":         {"en": "Delete", "zh-Hans": "删除", "hi": "हटाएँ", "es": "Eliminar", "fr": "Supprimer", "ar": "حذف", "pt": "Eliminar"},
    "files.tab.all":        {"en": "All", "zh-Hans": "全部", "hi": "सभी", "es": "Todos", "fr": "Tous", "ar": "الكل", "pt": "Todos"},
    "files.tab.recent":     {"en": "Recent", "zh-Hans": "最近", "hi": "हाल ही", "es": "Recientes", "fr": "Récents", "ar": "الأحدث", "pt": "Recentes"},
    "files.tab.received":   {"en": "Received", "zh-Hans": "已接收", "hi": "प्राप्त", "es": "Recibidos", "fr": "Reçus", "ar": "مستلمة", "pt": "Recebidos"},
    "files.tab.sent":       {"en": "Sent", "zh-Hans": "已发送", "hi": "भेजे गए", "es": "Enviados", "fr": "Envoyés", "ar": "مرسلة", "pt": "Enviados"},
    "files.tab.favorites":  {"en": "Favorites", "zh-Hans": "收藏", "hi": "पसंदीदा", "es": "Favoritos", "fr": "Favoris", "ar": "المفضلة", "pt": "Favoritos"},

    # ── Galerie (doc 17) ──
    "gallery.empty.title":    {"en": "No photos or videos yet", "zh-Hans": "还没有照片或视频", "hi": "अभी कोई फ़ोटो या वीडियो नहीं", "es": "Aún no hay fotos ni vídeos", "fr": "Aucune photo ou vidéo pour le moment", "ar": "لا توجد صور أو مقاطع فيديو بعد", "pt": "Ainda não há fotos ou vídeos"},
    "gallery.empty.subtitle": {"en": "Transfer media and it will appear here", "zh-Hans": "传输媒体后将显示在这里", "hi": "मीडिया स्थानांतरित करने पर वह यहाँ दिखेगा", "es": "Transfiere contenido multimedia y aparecerá aquí", "fr": "Transférez des médias et ils apparaîtront ici", "ar": "انقل الوسائط وستظهر هنا", "pt": "Transfira multimédia e ela aparecerá aqui"},

    # ── Musique (doc 17) ──
    "music.empty.title":    {"en": "No music found", "zh-Hans": "未找到音乐", "hi": "कोई संगीत नहीं मिला", "es": "No se encontró música", "fr": "Aucune musique trouvée", "ar": "لا توجد موسيقى", "pt": "Nenhuma música encontrada"},
    "music.empty.subtitle": {"en": "Transfer audio files and they will appear here", "zh-Hans": "传输音频文件后将显示在这里", "hi": "ऑडियो फ़ाइलें स्थानांतरित करने पर वे यहाँ दिखेंगी", "es": "Transfiere archivos de audio y aparecerán aquí", "fr": "Transférez des fichiers audio et ils apparaîtront ici", "ar": "انقل ملفات الصوت وستظهر هنا", "pt": "Transfira ficheiros de áudio e eles aparecerão aqui"},

    # ── Historique (doc 17) ──
    "history.clearAll": {"en": "Clear all", "zh-Hans": "全部清除", "hi": "सभी साफ़ करें", "es": "Borrar todo", "fr": "Tout effacer", "ar": "مسح الكل", "pt": "Limpar tudo"},

    # ── Paramètres (doc 18) ──
    "settings.appearance":           {"en": "Appearance", "zh-Hans": "外观", "hi": "दिखावट", "es": "Apariencia", "fr": "Apparence", "ar": "المظهر", "pt": "Aparência"},
    "settings.appearance.theme":     {"en": "Theme", "zh-Hans": "主题", "hi": "थीम", "es": "Tema", "fr": "Thème", "ar": "السما", "pt": "Tema"},
    "settings.appearance.auto":      {"en": "System", "zh-Hans": "系统", "hi": "सिस्टम", "es": "Sistema", "fr": "Système", "ar": "النظام", "pt": "Sistema"},
    "settings.appearance.light":     {"en": "Light", "zh-Hans": "浅色", "hi": "हल्का", "es": "Claro", "fr": "Clair", "ar": "فاتح", "pt": "Claro"},
    "settings.appearance.dark":      {"en": "Dark", "zh-Hans": "深色", "hi": "गहरा", "es": "Oscuro", "fr": "Sombre", "ar": "داكن", "pt": "Escuro"},
    "settings.language":             {"en": "Language", "zh-Hans": "语言", "hi": "भाषा", "es": "Idioma", "fr": "Langue", "ar": "اللغة", "pt": "Idioma"},
    "settings.language.auto":        {"en": "System language", "zh-Hans": "系统语言", "hi": "सिस्टम भाषा", "es": "Idioma del sistema", "fr": "Langue du système", "ar": "لغة النظام", "pt": "Idioma do sistema"},
    "settings.transfers":            {"en": "Transfers", "zh-Hans": "传输", "hi": "स्थानांतरण", "es": "Transferencias", "fr": "Transferts", "ar": "التحويلات", "pt": "Transferências"},
    "settings.transfers.wifiOnly":   {"en": "Wi-Fi only", "zh-Hans": "仅限 Wi-Fi", "hi": "केवल वाई-फ़ाई", "es": "Solo Wi-Fi", "fr": "Wi-Fi uniquement", "ar": "Wi-Fi فقط", "pt": "Apenas Wi-Fi"},
    "settings.transfers.autoAccept": {"en": "Auto-accept from trusted devices", "zh-Hans": "自动接受可信设备", "hi": "विश्वसनीय डिवाइस से स्वतः स्वीकारें", "es": "Aceptar automáticamente desde dispositivos de confianza", "fr": "Accepter automatiquement les appareils de confiance", "ar": "قبول تلقائي من الأجهزة الموثوقة", "pt": "Aceitar automaticamente de dispositivos de confiança"},
    "settings.devices":              {"en": "Devices", "zh-Hans": "设备", "hi": "डिवाइस", "es": "Dispositivos", "fr": "Appareils", "ar": "الأجهزة", "pt": "Dispositivos"},
    "settings.devices.list":         {"en": "Saved devices", "zh-Hans": "已保存的设备", "hi": "सहेजे गए डिवाइस", "es": "Dispositivos guardados", "fr": "Appareils enregistrés", "ar": "الأجهزة المحفوظة", "pt": "Dispositivos guardados"},
    "settings.notifications.complete":  {"en": "Transfer complete", "zh-Hans": "传输完成", "hi": "स्थानांतरण पूर्ण", "es": "Transferencia completa", "fr": "Transfert terminé", "ar": "اكتمل النقل", "pt": "Transferência concluída"},
    "settings.notifications.incoming":  {"en": "Incoming transfers", "zh-Hans": "接收传输", "hi": "आने वाले स्थानांतरण", "es": "Transferencias entrantes", "fr": "Transferts entrants", "ar": "التحويلات الواردة", "pt": "Transferências recebidas"},
    "settings.storage":             {"en": "Storage", "zh-Hans": "存储", "hi": "संग्रहण", "es": "Almacenamiento", "fr": "Stockage", "ar": "التخزين", "pt": "Armazenamento"},
    "settings.storage.clearCache":  {"en": "Clear cache", "zh-Hans": "清除缓存", "hi": "कैश साफ़ करें", "es": "Borrar caché", "fr": "Vider le cache", "ar": "مسح ذاكرة التخزين المؤقت", "pt": "Limpar cache"},
    "settings.privacy":             {"en": "Privacy & security", "zh-Hans": "隐私与安全", "hi": "गोपनीयता और सुरक्षा", "es": "Privacidad y seguridad", "fr": "Confidentialité et sécurité", "ar": "الخصوصية والأمان", "pt": "Privacidade e segurança"},
    "settings.privacy.encryption":  {"en": "Encryption", "zh-Hans": "加密", "hi": "एन्क्रिप्शन", "es": "Cifrado", "fr": "Chiffrement", "ar": "التشفير", "pt": "Criptografia"},
    "settings.privacy.erase":       {"en": "Erase all data", "zh-Hans": "清除所有数据", "hi": "सभी डेटा मिटाएँ", "es": "Borrar todos los datos", "fr": "Effacer toutes les données", "ar": "مسح جميع البيانات", "pt": "Apagar todos os dados"},
}

# Vérifie que chaque clé possède les 7 langues
for key, translations in TABLE.items():
    missing = [lang for lang in LANGS if lang not in translations]
    if missing:
        raise SystemExit(f"Clé « {key} » : langues manquantes {missing}")

import re

SOURCE_DIR = os.path.join("Fylio")

def load_from_swift_files() -> set:
    """Extrait les clés String(localized:) réellement utilisées dans le code Swift."""
    keys = set()
    if not os.path.isdir(SOURCE_DIR):
        return keys
    pattern = re.compile(r'String\(localized:\s*"([a-zA-Z0-9_\.]+)"')
    for root, _, files in os.walk(SOURCE_DIR):
        for fname in sorted(files):
            if not fname.endswith(".swift"):
                continue
            path = os.path.join(root, fname)
            try:
                text = open(path, encoding="utf-8").read()
            except Exception:
                continue
            keys.update(pattern.findall(text))
    return keys


def build_xcstrings(extra_keys: set) -> dict:
    """Construit le JSON Localizable.xcstrings (String Catalog) au format Xcode."""
    all_keys = set(TABLE.keys()) | extra_keys
    strings = {}
    for key in sorted(all_keys):
        translations = TABLE.get(key, {lang: key for lang in LANGS})
        localizations = {}
        for lang in LANGS:
            value = translations[lang]
            localizations[lang] = {"stringUnit": {"state": "translated", "value": value}}
        if localizations:
            strings[key] = {"localizations": localizations}
    return {"sourceLanguage": "en", "strings": strings, "version": "1.0"}


def main():
    extra = load_from_swift_files()
    catalog = build_xcstrings(extra)
    path = os.path.join("Fylio", "Localizable.xcstrings")
    os.makedirs("Fylio", exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(catalog, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"OK -> {path} ({len(catalog['strings'])} clefs) sur {len(extra)} clefs detectees dans le code")


if __name__ == "__main__":
    main()