#!/usr/bin/env python3
"""Fill ChartAgent's String Catalog for every supported App Store locale.

The script uses the reviewed English catalog copy as the translation source,
protects Swift/C format placeholders, and writes only build-time resources.
There is no translation-service dependency in the shipped app.
"""

from __future__ import annotations

import json
import re
import sys
import time
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = ROOT / "ChartAgent" / "Localizable.xcstrings"

# Catalog locale -> Google Translate target used only by this maintenance tool.
TARGETS = {
    "ja": "ja",
    "de": "de",
    "fr": "fr",
    "es-MX": "es",
    "pt-BR": "pt",
    "zh-Hant": "zh-TW",
    "id": "id",
    "th": "th",
    "zh-Hans": "zh-CN",
    "vi": "vi",
    "it": "it",
    "tr": "tr",
    "es": "es",
    "fr-CA": "fr",
}

FORMAT_PATTERN = re.compile(r"%(?:\d+\$)?(?:@|lld|ld|d|f|s)")
MARKER_PATTERN = re.compile(r"\[\[S(\d{4})\]\]\s*")

# Direction labels are intentionally one word in every supported language.
# They are model/UI contracts, so they should not drift during catalog refreshes.
STANCE = {
    "ja": ("買い", "売り", "中立", "様子見"),
    "de": ("KAUFEN", "VERKAUFEN", "NEUTRAL", "ABWARTEN"),
    "fr": ("ACHAT", "VENTE", "NEUTRE", "ATTENDRE"),
    "es-MX": ("COMPRAR", "VENDER", "NEUTRAL", "ESPERAR"),
    "pt-BR": ("COMPRAR", "VENDER", "NEUTRO", "AGUARDAR"),
    "zh-Hant": ("買入", "賣出", "中立", "觀望"),
    "id": ("BELI", "JUAL", "NETRAL", "TUNGGU"),
    "th": ("ซื้อ", "ขาย", "เป็นกลาง", "รอดู"),
    "zh-Hans": ("买入", "卖出", "中立", "观望"),
    "vi": ("MUA", "BÁN", "TRUNG LẬP", "CHỜ"),
    "it": ("ACQUISTA", "VENDI", "NEUTRALE", "ATTENDI"),
    "tr": ("AL", "SAT", "NÖTR", "BEKLE"),
    "es": ("COMPRAR", "VENDER", "NEUTRAL", "ESPERAR"),
    "fr-CA": ("ACHAT", "VENTE", "NEUTRE", "ATTENDRE"),
}

SOURCE_OVERRIDES = {
    "한 장의 차트를\n다섯 시선으로 끝까지.": "One trading chart.\nFive expert perspectives through to a decision.",
    "종합 매매전략": "Trading Strategy",
    "현재 판단": "Current Market Outlook",
    "에이전트에게 후속 질문": "Ask a Chart Analysis Agent",
}

COPY_OVERRIDES = {
    "한 장의 차트를\n다섯 시선으로 끝까지.": {
        "ja": "1枚のチャートを\n5つの視点で最後まで。",
        "de": "Ein Chart.\nFünf Perspektiven bis zur Entscheidung.",
        "fr": "Un graphique.\nCinq regards jusqu’à la décision.",
        "es-MX": "Un gráfico.\nCinco perspectivas hasta la decisión.",
        "pt-BR": "Um gráfico.\nCinco perspectivas até a decisão.",
        "zh-Hant": "一張圖表\n五個視角，看到最後。",
        "id": "Satu grafik.\nLima sudut pandang hingga keputusan.",
        "th": "หนึ่งกราฟ\nวิเคราะห์ให้ถึงที่สุดด้วยห้ามุมมอง",
        "zh-Hans": "一张图表\n五个视角，看到最后。",
        "vi": "Một biểu đồ.\nNăm góc nhìn đến tận quyết định.",
        "it": "Un grafico.\nCinque prospettive fino alla decisione.",
        "tr": "Tek grafik.\nKarara kadar beş bakış açısı.",
        "es": "Un gráfico.\nCinco perspectivas hasta la decisión.",
        "fr-CA": "Un graphique.\nCinq regards jusqu’à la décision.",
    },
    "종합 매매전략": {
        "ja": "取引戦略", "de": "Handelsstrategie", "fr": "Stratégie de trading",
        "es-MX": "Estrategia de trading", "pt-BR": "Estratégia de trading",
        "zh-Hant": "交易策略", "id": "Strategi Trading", "th": "กลยุทธ์การเทรด",
        "zh-Hans": "交易策略", "vi": "Chiến lược giao dịch",
        "it": "Strategia di trading", "tr": "İşlem Stratejisi",
        "es": "Estrategia de trading", "fr-CA": "Stratégie de trading",
    },
    "현재 판단": {
        "ja": "現在の見通し", "de": "Aktueller Ausblick", "fr": "Perspective actuelle",
        "es-MX": "Perspectiva actual", "pt-BR": "Perspectiva atual",
        "zh-Hant": "當前判斷", "id": "Pandangan Saat Ini", "th": "มุมมองปัจจุบัน",
        "zh-Hans": "当前判断", "vi": "Nhận định hiện tại",
        "it": "Prospettiva attuale", "tr": "Güncel Görünüm",
        "es": "Perspectiva actual", "fr-CA": "Perspective actuelle",
    },
    "에이전트에게 후속 질문": {
        "ja": "エージェントに追加質問", "de": "Agenten fragen",
        "fr": "Poser une question à un agent", "es-MX": "Preguntar a un agente",
        "pt-BR": "Perguntar a um agente", "zh-Hant": "向分析代理提問",
        "id": "Tanya Agen", "th": "ถามเอเจนต์", "zh-Hans": "向分析智能体提问",
        "vi": "Hỏi thêm chuyên gia", "it": "Chiedi a un agente",
        "tr": "Temsilciye Sor", "es": "Preguntar a un agente",
        "fr-CA": "Poser une question à un agent",
    },
}

# Generic translators often interpret "trading" as ordinary commerce. Keep
# onboarding language in the market/investing domain instead.
DOMAIN_COPY_OVERRIDES = {
    "ja": {
        "AI TRADING OFFICE": "AIトレーディングオフィス",
        "LIVE": "ライブ",
        "손절": "損切り",
        "진입": "エントリー",
    },
    "de": {
        "AI TRADING OFFICE": "KI-HANDELSBÜRO",
        "LIVE": "LIVE",
        "손절": "STOPP",
        "진입": "EINSTIEG",
    },
    "fr": {
        "AI TRADING OFFICE": "BUREAU DE TRADING IA",
        "LIVE": "EN DIRECT",
        "손절": "STOP",
        "진입": "ENTRÉE",
    },
    "es": {
        "AI TRADING OFFICE": "OFICINA DE TRADING CON IA",
        "LIVE": "EN VIVO",
        "손절": "STOP",
        "진입": "ENTRADA",
        "실전 매매를 경험하고 있어요": "Tengo experiencia operando en mercados reales.",
        "어떤 스타일로\n거래하나요?": "¿Cuál es tu\nestilo de trading?",
        "트레이딩 경험은\n어느 정도인가요?": "¿Cuánta experiencia\ntienes haciendo trading?",
    },
    "es-MX": {
        "AI TRADING OFFICE": "OFICINA DE TRADING CON IA",
        "LIVE": "EN VIVO",
        "손절": "STOP",
        "진입": "ENTRADA",
        "실전 매매를 경험하고 있어요": "Tengo experiencia operando en mercados reales.",
        "어떤 스타일로\n거래하나요?": "¿Cuál es tu\nestilo de trading?",
        "트레이딩 경험은\n어느 정도인가요?": "¿Cuánta experiencia\ntienes haciendo trading?",
    },
    "pt-BR": {
        "AI TRADING OFFICE": "ESCRITÓRIO DE TRADING COM IA",
        "LIVE": "AO VIVO",
        "손절": "STOP",
        "진입": "ENTRADA",
    },
    "zh-Hant": {
        "AI TRADING OFFICE": "AI 交易室",
        "LIVE": "即時",
        "손절": "停損",
        "진입": "進場",
    },
    "id": {
        "AI TRADING OFFICE": "KANTOR TRADING AI",
        "LIVE": "LIVE",
        "손절": "STOP",
        "진입": "ENTRY",
    },
    "th": {
        "AI TRADING OFFICE": "ออฟฟิศเทรดดิ้ง AI",
        "LIVE": "สด",
        "손절": "จุดตัดขาดทุน",
        "진입": "จุดเข้า",
    },
    "zh-Hans": {
        "AI TRADING OFFICE": "AI 交易室",
        "LIVE": "实时",
        "손절": "止损",
        "진입": "入场",
    },
    "vi": {
        "AI TRADING OFFICE": "PHÒNG GIAO DỊCH AI",
        "LIVE": "TRỰC TIẾP",
        "손절": "CẮT LỖ",
        "진입": "ĐIỂM VÀO",
    },
    "it": {
        "AI TRADING OFFICE": "UFFICIO TRADING AI",
        "LIVE": "LIVE",
        "손절": "STOP",
        "진입": "INGRESSO",
    },
    "tr": {
        "AI TRADING OFFICE": "AI TRADING OFİSİ",
        "LIVE": "CANLI",
        "손절": "STOP",
        "진입": "GİRİŞ",
    },
    "fr-CA": {
        "AI TRADING OFFICE": "BUREAU DE TRADING IA",
        "LIVE": "EN DIRECT",
        "손절": "STOP",
        "진입": "ENTRÉE",
    },
}

BRAND_COPY_OVERRIDES = {
    "CHARTAGENT  PRO": "CHARTAGENT PRO",
    "ChartAgent AI": "ChartAgent AI",
}

KOREAN_FALLBACKS = {
    "5 ROLES · FIXED": "5개 역할 · 고정",
    "LIVE PREVIEW": "실시간 미리보기",
    "PROFILES": "프로필",
}

EXTRA_SOURCES = {
    "같은 입력으로 다시 시도": ("Try Again with the Same Image", "같은 입력으로 다시 시도"),
    "office.ambient.trendy": ("I’ll recheck the recent high structure.", "최근 고점 구조를 다시 볼게요."),
    "office.ambient.patty": ("Confirmation conditions come before the pattern.", "모양보다 확인 조건이 먼저예요."),
    "office.ambient.momo": ("I’ll wait for the next candle instead of chasing.", "추격보다 다음 캔들을 기다릴게요."),
    "office.ambient.gadi": ("Let’s verify the news source and timestamp first.", "뉴스는 출처와 시각부터 확인해요."),
    "office.ambient.devil": ("Let’s keep the opposing scenario open.", "반대 시나리오도 남겨둡시다."),
    "에이전트 스튜디오": ("Agent Studio", "에이전트 스튜디오"),
    "이름·말투·판단 관점만 직접 설계하세요": ("Customize each name, voice, and decision lens.", "이름·말투·판단 관점만 직접 설계하세요"),
    "내 분석팀": ("My Analysis Team", "내 분석팀"),
    "에이전트 편집": ("Edit Agent", "에이전트 편집"),
    "초기화": ("Reset", "초기화"),
    "저장": ("Save", "저장"),
    "투자 판단 컨셉": ("Investment Decision Lens", "투자 판단 컨셉"),
    "지원하지 않는 에이전트 역할입니다.": ("This agent role is not supported.", "지원하지 않는 에이전트 역할입니다."),
    "이름은 1~10자이며 줄바꿈을 포함할 수 없습니다.": ("Name must be 1–10 characters without line breaks.", "이름은 1~10자이며 줄바꿈을 포함할 수 없습니다."),
    "말투는 1~20자이며 줄바꿈을 포함할 수 없습니다.": ("Voice must be 1–20 characters without line breaks.", "말투는 1~20자이며 줄바꿈을 포함할 수 없습니다."),
    "지원하지 않는 외형입니다.": ("This appearance is not supported.", "지원하지 않는 외형입니다."),
    "간결하고 단호하게": ("Brief and decisive", "간결하고 단호하게"),
    "네트워크 오류가 발생했습니다.": ("A network error occurred.", "네트워크 오류가 발생했습니다."),
    "다른 차트 이미지로 다시 시도해 주세요.": ("Try again with a different chart image.", "다른 차트 이미지로 다시 시도해 주세요."),
    "종목명, 시간대, 캔들, 가격 축이 보이는 차트 캡처를 올려 주세요.": ("Upload a chart capture that clearly shows the symbol, timeframe, candles, and price axis.", "종목명, 시간대, 캔들, 가격 축이 보이는 차트 캡처를 올려 주세요."),
    "이미지 크기가 허용 범위를 벗어났습니다.": ("The image size is outside the allowed range.", "이미지 크기가 허용 범위를 벗어났습니다."),
    "이미지 파일을 읽을 수 없습니다.": ("The image file could not be read.", "이미지 파일을 읽을 수 없습니다."),
    "PNG, JPEG 또는 WEBP 이미지만 사용할 수 있습니다.": ("Only PNG, JPEG, or WEBP images are supported.", "PNG, JPEG 또는 WEBP 이미지만 사용할 수 있습니다."),
    "차트 글자를 읽기에는 이미지 해상도가 너무 낮습니다.": ("The image resolution is too low to read the chart labels.", "차트 글자를 읽기에는 이미지 해상도가 너무 낮습니다."),
    "금융 가격 차트 이미지인지 확인할 수 없습니다.": ("This does not appear to be a financial price chart.", "금융 가격 차트 이미지인지 확인할 수 없습니다."),
    "차트의 캔들과 글자를 선명하게 읽을 수 없습니다.": ("The chart candles and labels are not clear enough to read.", "차트의 캔들과 글자를 선명하게 읽을 수 없습니다."),
    "이미지에서 종목 심볼을 확인할 수 없습니다.": ("The market symbol could not be identified in the image.", "이미지에서 종목 심볼을 확인할 수 없습니다."),
    "이미지에서 차트 시간대를 확인할 수 없습니다.": ("The chart timeframe could not be identified in the image.", "이미지에서 차트 시간대를 확인할 수 없습니다."),
    "분석 에이전트 구성은 서로 다른 3~5명이어야 합니다.": ("Choose three to five different analysis agents.", "분석 에이전트 구성은 서로 다른 3~5명이어야 합니다."),
    "에이전트 커스터마이징 정보를 읽을 수 없습니다.": ("The agent customization settings could not be read.", "에이전트 커스터마이징 정보를 읽을 수 없습니다."),
    "분석 서비스를 잠시 사용할 수 없습니다.": ("The analysis service is temporarily unavailable.", "분석 서비스를 잠시 사용할 수 없습니다."),
}


def protect(text: str) -> tuple[str, list[str]]:
    values: list[str] = []

    def replace(match: re.Match[str]) -> str:
        values.append(match.group(0))
        return f"<x{len(values) - 1}/>"

    protected = FORMAT_PATTERN.sub(replace, text)
    if "\n" in protected:
        values.append("\n")
        protected = protected.replace("\n", f"<x{len(values) - 1}/>")
    return protected, values


def restore(text: str, values: list[str]) -> str:
    restored = text.strip()
    for index, value in enumerate(values):
        restored = restored.replace(f"<x{index}/>", value)
        restored = restored.replace(f"<x{index} />", value)
    return restored


def translate(payload: str, source: str, target: str) -> str:
    query = urllib.parse.urlencode(
        {"client": "gtx", "sl": source, "tl": target, "dt": "t", "q": payload}
    )
    request = urllib.request.Request(
        f"https://translate.googleapis.com/translate_a/single?{query}",
        headers={"User-Agent": "ChartAgent-Localization/1.0"},
    )
    last_error: Exception | None = None
    for attempt in range(4):
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                data = json.loads(response.read().decode("utf-8"))
            return "".join(part[0] for part in data[0] if part[0])
        except Exception as error:  # noqa: BLE001 - retry network/service errors
            last_error = error
            time.sleep(1.2 * (attempt + 1))
    raise RuntimeError(f"translation failed for {target}: {last_error}")


def batches(items: list[tuple[str, str]], limit: int = 2_600) -> list[list[tuple[str, str]]]:
    output: list[list[tuple[str, str]]] = []
    current: list[tuple[str, str]] = []
    size = 0
    for item in items:
        estimated = len(item[1]) + 18
        if current and size + estimated > limit:
            output.append(current)
            current = []
            size = 0
        current.append(item)
        size += estimated
    if current:
        output.append(current)
    return output


def translate_batch(items: list[tuple[str, str]], target: str) -> dict[str, str]:
    protected_values: dict[int, list[str]] = {}
    lines: list[str] = []
    for index, (_, source) in enumerate(items):
        protected, values = protect(source)
        protected_values[index] = values
        lines.extend((f"[[S{index:04d}]]", protected))

    translated = translate("\n".join(lines), "en", target)
    parts = MARKER_PATTERN.split(translated)
    parsed: dict[int, str] = {}
    for offset in range(1, len(parts), 2):
        parsed[int(parts[offset])] = parts[offset + 1].strip()

    if len(parsed) != len(items):
        raise RuntimeError(f"batch markers were not preserved for {target}")

    return {
        key: restore(parsed[index], protected_values[index])
        for index, (key, _) in enumerate(items)
    }


def source_value(key: str, item: dict) -> str:
    if key in SOURCE_OVERRIDES:
        return SOURCE_OVERRIDES[key]
    localizations = item.get("localizations", {})
    english = localizations.get("en", {}).get("stringUnit", {}).get("value")
    korean = localizations.get("ko", {}).get("stringUnit", {}).get("value")
    return english or korean or key


def translate_locale(locale: str, target: str, strings: dict[str, dict]) -> tuple[str, dict[str, str]]:
    items = [(key, source_value(key, item)) for key, item in strings.items()]
    result: dict[str, str] = {}
    for group in batches(items):
        result.update(translate_batch(group, target))
    return locale, result


def apply_contract_overrides(locale: str, translated: dict[str, str]) -> None:
    buy, sell, neutral, observe = STANCE[locale]
    translated.update(
        {
            "market.stance.bullish": buy,
            "market.stance.bearish": sell,
            "market.stance.neutral": neutral,
            "market.stance.observe": observe,
            "market.term.buy_side": buy,
            "market.term.sell_side": sell,
            "market.term.wait": observe,
        }
    )
    for key, values in COPY_OVERRIDES.items():
        translated[key] = values[locale]
    translated.update(DOMAIN_COPY_OVERRIDES.get(locale, {}))
    translated.update(BRAND_COPY_OVERRIDES)


def validate_placeholders(key: str, source: str, translated: str) -> None:
    expected = sorted(FORMAT_PATTERN.findall(source))
    actual = sorted(FORMAT_PATTERN.findall(translated))
    if expected != actual:
        raise ValueError(f"placeholder mismatch for {key!r}: {expected} != {actual}")


def main() -> int:
    catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    strings: dict[str, dict] = catalog["strings"]
    for key, (english, korean) in EXTRA_SOURCES.items():
        strings.setdefault(
            key,
            {
                "localizations": {
                    "en": {"stringUnit": {"state": "translated", "value": english}},
                    "ko": {"stringUnit": {"state": "translated", "value": korean}},
                }
            },
        )
    completed: dict[str, dict[str, str]] = {}

    with ThreadPoolExecutor(max_workers=4) as executor:
        futures = {
            executor.submit(translate_locale, locale, target, strings): locale
            for locale, target in TARGETS.items()
        }
        for future in as_completed(futures):
            locale, translated = future.result()
            apply_contract_overrides(locale, translated)
            completed[locale] = translated
            print(f"translated {locale}: {len(translated)} strings", flush=True)

    for key, item in strings.items():
        localizations = item.setdefault("localizations", {})
        source = source_value(key, item)
        localizations.setdefault(
            "en",
            {"stringUnit": {"state": "translated", "value": SOURCE_OVERRIDES.get(key, key)}},
        )
        localizations.setdefault(
            "ko",
            {"stringUnit": {"state": "translated", "value": KOREAN_FALLBACKS.get(key, key)}},
        )
        if key in SOURCE_OVERRIDES:
            localizations["en"] = {
                "stringUnit": {"state": "translated", "value": SOURCE_OVERRIDES[key]}
            }
        for locale in TARGETS:
            translated = completed[locale][key]
            validate_placeholders(key, source, translated)
            localizations[locale] = {
                "stringUnit": {"state": "translated", "value": translated}
            }

    CATALOG_PATH.write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"updated {CATALOG_PATH} with {len(TARGETS) + 2} locales")
    return 0


if __name__ == "__main__":
    sys.exit(main())
