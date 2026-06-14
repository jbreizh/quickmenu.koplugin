local Translation = {}

local I18N = {
    en = {
        ["Actions"] = "Actions", ["Frontlight"] = "Frontlight", ["Warmth"] = "Warmth",
        ["Shortcuts"] = "Shortcuts", ["Informations"] = "Informations", ["Skim"] = "Skim",
        ["Restart"] = "Restart", ["Exit"] = "Exit", ["Night"] = "Night", ["Light"] = "Light",
        ["Rotate"] = "Rotate", ["Lock"] = "Lock", ["Sleep"] = "Sleep", ["Search"] = "Search", ["Search in Calibre"] = "Search in Calibre", ["Resume"] = "Resume",
        ["Dictionary"] = "Dictionary", ["Cloud"] = "Cloud", ["History"] = "History",
        ["Collections"] = "Collections", ["Favorites"] = "Favorites", ["Statistics"] = "Statistics",
        ["Plugin not activated."] = "Plugin not activated.",
        ["Are you sure you want to restart KOReader ?"] = "Are you sure you want to restart KOReader ?",
        ["Are you sure you want to exit KOReader ?"] = "Are you sure you want to exit KOReader ?",
        ["Are you sure you want to exit book ?"] = "Are you sure you want to exit book ?",
        ["Quick menu"] = "Quick menu", ["Always start on quick menu tab"] = "Always start on quick menu tab",
        ["Add exit tab (need restart)"] = "Add exit tab (need restart)",
        ["Select controls"] = "Select controls", ["Arrange controls"] = "Arrange controls",
        ["Enabled in filemanager"] = "Enabled in filemanager", ["Enabled in reader"] = "Enabled in reader", ["Show labels"] = "Show labels",
        ["Columns"] = "Columns", ["Show thumbnail"] = "Show thumbnail", ["Show title"] = "Show title"
    },
    fr = {
        ["Actions"] = "Actions", ["Frontlight"] = "Éclairage", ["Warmth"] = "Température",
        ["Shortcuts"] = "Raccourcis", ["Informations"] = "Informations", ["Skim"] = "Feuilletage",
        ["Restart"] = "Redémarrer", ["Exit"] = "Quitter", ["Night"] = "Nuit", ["Light"] = "Éclairage",
        ["Rotate"] = "Tourner", ["Lock"] = "Bloquer", ["Sleep"] = "Suspendre", ["Search"] = "Rechercher", ["Search in Calibre"] = "Rechercher dans Calibre", ["Resume"] = "Reprendre",
        ["Dictionary"] = "Dictionnaire", ["Cloud"] = "Cloud", ["History"] = "Historique",
        ["Collections"] = "Collections", ["Favorites"] = "Favoris", ["Statistics"] = "Statistiques",
        ["Plugin not activated."] = "Plugin non activé.",
        ["Are you sure you want to restart KOReader ?"] = "Voulez-vous vraiment redémarrer KOReader ?",
        ["Are you sure you want to exit KOReader ?"] = "Voulez-vous vraiment quitter KOReader ?",
        ["Are you sure you want to exit book ?"] = "Voulez-vous vraiment fermer le livre ?",
        ["Quick menu"] = "Menu rapide", ["Always start on quick menu tab"] = "Toujours ouvrir sur l'onglet du menu rapide",
        ["Add exit tab (need restart)"] = "Ajouter l'onglet de sortie (redémarrage requis)",
        ["Select controls"] = "Sélectionner les contrôles", ["Arrange controls"] = "Organiser les contrôles",
        ["Enabled in filemanager"] = "Activé dans le gestionnaire de fichiers", ["Enabled in reader"] = "Activé dans le lecteur", ["Show labels"] = "Afficher les étiquettes",
        ["Columns"] = "Colonnes", ["Show thumbnail"] = "Afficher la vignette", ["Show title"] = "Afficher le titre"
    },
    pt = {
        ["Actions"] = "Ações", ["Frontlight"] = "Iluminação", ["Warmth"] = "Temperatura",
        ["Shortcuts"] = "Atalhos", ["Informations"] = "Informações", ["Skim"] = "Navegação",
        ["Restart"] = "Reiniciar", ["Exit"] = "Sair", ["Night"] = "Noite", ["Light"] = "Luz",
        ["Rotate"] = "Girar", ["Lock"] = "Bloquear", ["Sleep"] = "Suspender", ["Search"] = "Pesquisar", ["Search in Calibre"] = "Pesquisar no Calibre", ["Resume"] = "Retomar",
        ["Dictionary"] = "Dicionário", ["Cloud"] = "Nuvem", ["History"] = "Histórico",
        ["Collections"] = "Coleções", ["Favorites"] = "Favoritos", ["Statistics"] = "Estatísticas",
        ["Plugin not activated."] = "Plugin não ativado.",
        ["Are you sure you want to restart KOReader ?"] = "Tem certeza de que deseja reiniciar o KOReader?",
        ["Are you sure you want to exit KOReader ?"] = "Tem certeza de que deseja sair do KOReader?",
        ["Are you sure you want to exit book ?"] = "Tem certeza de que deseja fechar o livro ?",
        ["Quick menu"] = "Menu rápido", ["Always start on quick menu tab"] = "Sempre abrir na aba do menu rápido",
        ["Add exit tab (need restart)"] = "Adicionar aba de saída (requer reiniciar)",
        ["Select controls"] = "Selecionar controles", ["Arrange controls"] = "Organizar controles",
        ["Enabled in filemanager"] = "Ativado no gerenciador de arquivos", ["Enabled in reader"] = "Ativado no leitor", ["Show labels"] = "Mostrar rótulos",
        ["Columns"] = "Colunas", ["Show thumbnail"] = "Mostrar miniatura", ["Show title"] = "Mostrar título"
    },
    es = {
        ["Actions"] = "Acciones", ["Frontlight"] = "Luz frontal", ["Warmth"] = "Temperatura",
        ["Shortcuts"] = "Accesos directos", ["Informations"] = "Informaciones", ["Skim"] = "Lectura rápida",
        ["Restart"] = "Reiniciar", ["Exit"] = "Salir", ["Night"] = "Noche", ["Light"] = "Luz",
        ["Rotate"] = "Girar", ["Lock"] = "Bloquear", ["Sleep"] = "Suspender", ["Search"] = "Buscar", ["Search in Calibre"] = "Buscar en Calibre", ["Resume"] = "Continuar",
        ["Dictionary"] = "Diccionario", ["Cloud"] = "Nube", ["History"] = "Historial",
        ["Collections"] = "Colecciones", ["Favorites"] = "Favoritos", ["Statistics"] = "Estadísticas",
        ["Plugin not activated."] = "Plugin no activado.",
        ["Are you sure you want to restart KOReader ?"] = "¿Seguro que quieres reiniciar KOReader?",
        ["Are you sure you want to exit KOReader ?"] = "¿Seguro que quieres salir de KOReader?",
        ["Are you sure you want to exit book ?"] = "¿Seguro que quieres cerrar el libro ?",
        ["Quick menu"] = "Menú rápido", ["Always start on quick menu tab"] = "Abrir siempre en la pestaña del menú rápido",
        ["Add exit tab (need restart)"] = "Añadir pestaña de salida (requiere reiniciar)",
        ["Select controls"] = "Seleccionar controles", ["Arrange controls"] = "Organizar controles",
        ["Enabled in filemanager"] = "Activado en el gestor de archivos", ["Enabled in reader"] = "Activado en el lector", ["Show labels"] = "Mostrar etiquetas",
        ["Columns"] = "Columnas", ["Show thumbnail"] = "Mostrar miniatura", ["Show title"] = "Mostrar título"
    },
    de = {
        ["Actions"] = "Aktionen", ["Frontlight"] = "Beleuchtung", ["Warmth"] = "Farbtemperatur",
        ["Shortcuts"] = "Kurzbefehle", ["Informations"] = "Informationen", ["Skim"] = "Skim",
        ["Restart"] = "Neustart", ["Exit"] = "Beenden", ["Night"] = "Nacht", ["Light"] = "Licht",
        ["Rotate"] = "Drehen", ["Lock"] = "Sperren", ["Sleep"] = "Standby", ["Search"] = "Suchen", ["Search in Calibre"] = "In Calibre suchen", ["Resume"] = "Fortsetzen",
        ["Dictionary"] = "Wörterbuch", ["Cloud"] = "Cloud", ["History"] = "Verlauf",
        ["Collections"] = "Sammlungen", ["Favorites"] = "Favoriten", ["Statistics"] = "Statistik",
        ["Plugin not activated."] = "Plugin nicht aktiviert.",
        ["Are you sure you want to restart KOReader ?"] = "Möchtest du KOReader wirklich neu starten?",
        ["Are you sure you want to exit KOReader ?"] = "Möchtest du KOReader wirklich beenden?",
        ["Are you sure you want to exit book ?"] = "Möchtest du das Buch wirklich schließen?",
        ["Quick menu"] = "Schnellmenü", ["Always start on quick menu tab"] = "Immer auf dem Schnellmenü-Tab öffnen",
        ["Add exit tab (need restart)"] = "Beenden-Tab hinzufügen (Neustart nötig)",
        ["Select controls"] = "Bedienelemente auswählen", ["Arrange controls"] = "Bedienelemente anordnen",
        ["Enabled in filemanager"] = "Im Dateimanager aktiviert", ["Enabled in reader"] = "Im Reader aktiviert", ["Show labels"] = "Beschriftungen anzeigen",
        ["Columns"] = "Spalten", ["Show thumbnail"] = "Miniaturansicht anzeigen", ["Show title"] = "Titel anzeigen"
    },
    it = {
        ["Actions"] = "Azioni", ["Frontlight"] = "Luce frontale", ["Warmth"] = "Temperatura",
        ["Shortcuts"] = "Scorciatoie", ["Informations"] = "Informazioni", ["Skim"] = "Skim",
        ["Restart"] = "Riavvia", ["Exit"] = "Esci", ["Night"] = "Notte", ["Light"] = "Luce",
        ["Rotate"] = "Ruota", ["Lock"] = "Blocca", ["Sleep"] = "Sospendi", ["Search"] = "Cerca", ["Search in Calibre"] = "Cerca in Calibre", ["Resume"] = "Riprendi",
        ["Dictionary"] = "Dizionario", ["Cloud"] = "Cloud", ["History"] = "Cronologia",
        ["Collections"] = "Raccolte", ["Favorites"] = "Preferiti", ["Statistics"] = "Statistiche",
        ["Plugin not activated."] = "Plugin non attivato.",
        ["Are you sure you want to restart KOReader ?"] = "Sei sicuro di voler riavviare KOReader?",
        ["Are you sure you want to exit KOReader ?"] = "Sei sicuro di voler uscire da KOReader?",
        ["Are you sure you want to exit book ?"] = "Sei sicuro di voler chiudere il libro ?",
        ["Quick menu"] = "Menu rapido", ["Always start on quick menu tab"] = "Apri sempre sulla scheda del menu rapido",
        ["Add exit tab (need restart)"] = "Aggiungi scheda di uscita (riavvio richiesto)",
        ["Select controls"] = "Seleziona controlli", ["Arrange controls"] = "Organizza controlli",
        ["Enabled in filemanager"] = "Abilitato nel file manager", ["Enabled in reader"] = "Abilitato nel lettore", ["Show labels"] = "Mostra etichette",
        ["Columns"] = "Colonne", ["Show thumbnail"] = "Mostra miniatura", ["Show title"] = "Mostra titolo"
    },
    ru = {
        ["Actions"] = "Действия", ["Frontlight"] = "Подсветка", ["Warmth"] = "Теплота",
        ["Shortcuts"] = "Ярлыки", ["Informations"] = "Информация", ["Skim"] = "Навигация",
        ["Restart"] = "Перезапуск", ["Exit"] = "Выход", ["Night"] = "Ночь", ["Light"] = "Подсветка",
        ["Rotate"] = "Поворот", ["Lock"] = "Блокировка", ["Sleep"] = "Сон", ["Search"] = "Поиск", ["Search in Calibre"] = "Поиск в Calibre", ["Resume"] = "Продолжить",
        ["Dictionary"] = "Словарь", ["Cloud"] = "Облако", ["History"] = "История",
        ["Collections"] = "Коллекции", ["Favorites"] = "Избранное", ["Statistics"] = "Статистика",
        ["Plugin not activated."] = "Плагин не активирован.",
        ["Are you sure you want to restart KOReader ?"] = "Вы действительно хотите перезапустить KOReader?",
        ["Are you sure you want to exit KOReader ?"] = "Вы действительно хотите выйти из KOReader?",
        ["Are you sure you want to exit book ?"] = "Вы действительно хотите закрыть книгу?",
        ["Quick menu"] = "Быстрое меню", ["Always start on quick menu tab"] = "Всегда открывать на вкладке быстрого меню",
        ["Add exit tab (need restart)"] = "Добавить вкладку выхода (требуется перезапуск)",
        ["Select controls"] = "Выбрать элементы управления", ["Arrange controls"] = "Упорядочить элементы управления",
        ["Enabled in filemanager"] = "Включено в файловом менеджере", ["Enabled in reader"] = "Включено в читалке", ["Show labels"] = "Показать подписи",
        ["Columns"] = "Столбцы", ["Show thumbnail"] = "Показать миниатюру", ["Show title"] = "Показать заголовок"
    }
}

function Translation._(msg)
    local lang = "en"
    if G_reader_settings and G_reader_settings.readSetting then
        local current = G_reader_settings:readSetting("language")
        if current then lang = string.sub(current, 1, 2) end
    end
    -- Recherche dans la langue, sinon anglais par défaut, sinon le message original
    return (I18N[lang] and I18N[lang][msg]) or (I18N.en[msg] or msg)
end

return Translation
