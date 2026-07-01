import json
import os

translations_dir = "/Users/onyet/Onyet_Apps/kiblat/assets/translations"

data_to_add = {
    "en": {
        "permission_onboarding_title": "Location Access Required",
        "permission_onboarding_desc": "Kiblat requires your location coordinates to calculate the exact direction of the Kaaba and local prayer times. This calculation is performed entirely offline to protect your privacy.",
        "grant_permission": "Grant Location Access",
        "permission_denied_title": "Permission Required",
        "permission_denied_desc": "Location permission was denied. Please enable it in the app settings to continue using Kiblat."
    },
    "in": {
        "permission_onboarding_title": "Akses Lokasi Diperlukan",
        "permission_onboarding_desc": "Kiblat memerlukan koordinat lokasi Anda untuk menghitung arah Ka'bah secara tepat dan jadwal shalat setempat. Perhitungan ini dilakukan sepenuhnya secara offline untuk menjaga privasi Anda.",
        "grant_permission": "Berikan Akses Lokasi",
        "permission_denied_title": "Izin Diperlukan",
        "permission_denied_desc": "Izin lokasi ditolak. Harap aktifkan izin lokasi di pengaturan aplikasi untuk terus menggunakan Kiblat."
    },
    "id": {
        "permission_onboarding_title": "Akses Lokasi Diperlukan",
        "permission_onboarding_desc": "Kiblat memerlukan koordinat lokasi Anda untuk menghitung arah Ka'bah secara tepat dan jadwal shalat setempat. Perhitungan ini dilakukan sepenuhnya secara offline untuk menjaga privasi Anda.",
        "grant_permission": "Berikan Akses Lokasi",
        "permission_denied_title": "Izin Diperlukan",
        "permission_denied_desc": "Izin lokasi ditolak. Harap aktifkan izin lokasi di pengaturan aplikasi untuk terus menggunakan Kiblat."
    },
    "ar": {
        "permission_onboarding_title": "مطلوب الوصول إلى الموقع",
        "permission_onboarding_desc": "يتطلب تطبيق قبلة إحداثيات موقعك لحساب الاتجاه الدقيق للكعبة وأوقات الصلاة المحلية. يتم إجراء هذا الحساب بالكامل دون اتصال بالإنترنت لحماية خصوصيتك.",
        "grant_permission": "منح الوصول إلى الموقع",
        "permission_denied_title": "الإذن مطلوب",
        "permission_denied_desc": "تم رفض إذن الموقع. يرجى تمكينه في إعدادات التطبيق لمواصلة استخدام قبلة."
    },
    "de": {
        "permission_onboarding_title": "Standortzugriff erforderlich",
        "permission_onboarding_desc": "Kiblat benötigt Ihre Standortkoordinaten, um die genaue Richtung der Kaaba und die lokalen Gebetszeiten zu berechnen. Diese Berechnung wird vollständig offline durchgeführt, um Ihre Privatsphäre zu schützen.",
        "grant_permission": "Standortzugriff gewähren",
        "permission_denied_title": "Berechtigung erforderlich",
        "permission_denied_desc": "Der Standortzugriff wurde verweigert. Bitte aktivieren Sie ihn in den App-Einstellungen, um Kiblat weiterhin zu nutzen."
    },
    "ja": {
        "permission_onboarding_title": "位置情報のアクセスが必要です",
        "permission_onboarding_desc": "正確なカアバ神殿の方向と地域の礼拝時間を計算するために、位置情報が必要です。プライバシー保護のため、この計算は完全にオフラインで実行されます。",
        "grant_permission": "位置情報のアクセスを許可する",
        "permission_denied_title": "権限が必要です",
        "permission_denied_desc": "位置情報の権限が拒否されました。引き続きアプリを使用するには、設定画面で権限を許可してください。"
    },
    "pt": {
        "permission_onboarding_title": "Acesso à Localização Necessário",
        "permission_onboarding_desc": "O Kiblat requer as coordenadas da sua localização para calcular a direção exata da Caaba e os horários das orações locais. Este cálculo é realizado inteiramente offline para proteger a sua privacidade.",
        "grant_permission": "Permitir Acesso à Localização",
        "permission_denied_title": "Permissão Necessária",
        "permission_denied_desc": "A permissão de localização foi negada. Por favor, ative-a nas definições da aplicação para continuar a utilizar o Kiblat."
    },
    "ru": {
        "permission_onboarding_title": "Требуется доступ к местоположению",
        "permission_onboarding_desc": "Приложению Kiblat требуются координаты вашего местоположения для расчета точного направления на Каабу и времени местных молитв. Этот расчет выполняется полностью в автономном режиме для защиты вашей конфиденциальности.",
        "grant_permission": "Разрешить доступ к местоположению",
        "permission_denied_title": "Требуется разрешение",
        "permission_denied_desc": "Доступ к местоположению запрещен. Пожалуйста, включите его в настройках приложения, чтобы продолжить использование Kiblat."
    },
    "zh": {
        "permission_onboarding_title": "需要定位权限",
        "permission_onboarding_desc": "Kiblat 需要您的定位坐标来计算克尔白的精确方向和本地礼拜时间。此计算完全在离线状态下进行，以保护您的隐私。",
        "grant_permission": "授予定位权限",
        "permission_denied_title": "需要权限",
        "permission_denied_desc": "定位权限已被拒绝。请在应用设置中启用它以继续使用 Kiblat."
    }
}

for filename in os.listdir(translations_dir):
    if not filename.endswith(".json"):
        continue
    
    lang_code = filename.split(".")[0]
    file_path = os.path.join(translations_dir, filename)
    
    # Check if we have data for this language
    lang_data = data_to_add.get(lang_code, data_to_add["en"])
    
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            content = json.load(f)
        
        # Merge keys
        content.update(lang_data)
        
        with open(file_path, "w", encoding="utf-8") as f:
            json.dump(content, f, ensure_ascii=False, indent=2)
            
        print(f"Updated translations for {filename}")
    except Exception as e:
        print(f"Error updating {filename}: {e}")
