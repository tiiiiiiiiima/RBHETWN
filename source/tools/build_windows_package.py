#!/usr/bin/env python3
"""Package an unchanged official Windows engine with an adjacent game PCK.

No launcher scripts, engine modifications, or security-policy changes are used.
Without --runtime-zip or --runtime-exe this produces a labeled game-data-only package.
The builder performs no network requests and does not run Windows programs.
"""
import argparse
import os
import hashlib
import json
from pathlib import Path
import re
import shutil
import struct
import zipfile

RELEASE_VERSION = '0.24'
ENGINE_VERSION = '4.6.3'
ENGINE_NAME = 'Godot_v4.6.3-stable_win64.exe'
OFFICIAL_ZIP_SHA256 = 'e39986a178d585ce7ac198fb8de6ea436366dc0cc00e594810c2e3e104c04b90'
OFFICIAL_ZIP_SIZE = 79_844_616
OFFICIAL_EXE_SHA256 = 'ef90e929ba1a6a4322860285d97f40f4aa349c90329a91b0e8b55b8df0f4cb00'
OFFICIAL_EXE_SIZE = 172_409_864
OFFICIAL_URL = (
    'https://github.com/godotengine/godot-builds/releases/download/'
    '4.6.3-stable/Godot_v4.6.3-stable_win64.exe.zip'
)


def file_sha256(path: Path) -> str:
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def pe_certificate_table(data: bytes) -> dict:
    """Report the PE security-directory entry; this does not verify its trust."""
    if len(data) < 64 or data[:2] != b'MZ':
        raise ValueError('Official archive engine is not a PE executable')
    pe_offset = struct.unpack_from('<I', data, 0x3C)[0]
    if pe_offset + 24 > len(data) or data[pe_offset:pe_offset + 4] != b'PE\0\0':
        raise ValueError('Official archive engine has an invalid PE header')
    optional = pe_offset + 24
    magic = struct.unpack_from('<H', data, optional)[0]
    if magic not in (0x10B, 0x20B):
        raise ValueError('Unsupported PE optional header')
    directory = optional + (112 if magic == 0x20B else 96)
    offset, size = struct.unpack_from('<II', data, directory + 4 * 8)
    if offset and (offset + size > len(data) or size < 8):
        raise ValueError('Invalid PE certificate table bounds')
    return {'offset': offset, 'size': size, 'present': bool(offset and size)}


def verified_engine(data: bytes) -> dict:
    """Pin executable bytes as well as preserving the official PE certificate table."""
    if len(data) != OFFICIAL_EXE_SIZE or hashlib.sha256(data).hexdigest() != OFFICIAL_EXE_SHA256:
        raise ValueError('Windows runtime EXE does not match the pinned official release size and SHA-256')
    certificate = pe_certificate_table(data)
    if not certificate['present']:
        raise ValueError('Pinned Windows runtime must retain its original PE certificate table')
    return certificate


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    runtime_options = parser.add_mutually_exclusive_group()
    runtime_options.add_argument('--runtime-zip', type=Path, help='Previously downloaded official Godot Windows x64 ZIP')
    runtime_options.add_argument('--runtime-exe', type=Path, help='Previously verified, unchanged Godot Windows x64 EXE, including an older package runtime')
    parser.add_argument('--pck', type=Path, help='Already exported game PCK; avoids building an unnecessary Linux package')
    parser.add_argument('--prepare-only', action='store_true', help='Prepare runtime and documents without creating a local ZIP')
    parser.add_argument('--link-pack', action='store_true', help='Hard-link the supplied PCK into the local package folder to avoid duplicate storage')
    parser.add_argument('--version', default=RELEASE_VERSION, help='Release label; verify the supplied PCK version using the packaged runtime probe')
    parser.add_argument('--output-root', type=Path, help='Package folder root; defaults to project builds')
    parser.add_argument('--archive', type=Path, help='ZIP output path; defaults to project builds')
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    release_version = args.version
    source_pack = args.pck.resolve() if args.pck is not None else project / 'builds' / f'Bakugan-{release_version}-Linux' / 'arena.pck'
    if not source_pack.is_file():
        raise SystemExit('Export the game pack first: tools/build_game_pack.py, then pass --pck')
    for notice in ['GODOT-LICENSE.txt', 'THIRD-PARTY-LICENSES.txt', 'FONT-LICENSE.txt']:
        if not (source_pack.parent / notice).is_file():
            raise SystemExit(f'Runtime notice missing beside the exported PCK: {notice}')

    engine_bytes = None
    certificate_table = None
    if args.runtime_zip is not None:
        archive_sha = file_sha256(args.runtime_zip)
        if args.runtime_zip.stat().st_size != OFFICIAL_ZIP_SIZE or archive_sha != OFFICIAL_ZIP_SHA256:
            raise SystemExit('Windows runtime ZIP does not match the pinned official release size and SHA-256')
        with zipfile.ZipFile(args.runtime_zip) as runtime:
            candidates = [info for info in runtime.infolist() if Path(info.filename).name == ENGINE_NAME]
            if len(candidates) != 1:
                raise SystemExit('Official ZIP must contain exactly one expected Windows x64 engine')
            engine_bytes = runtime.read(candidates[0])
        certificate_table = verified_engine(engine_bytes)
    elif args.runtime_exe is not None:
        if args.runtime_exe.stat().st_size != OFFICIAL_EXE_SIZE or file_sha256(args.runtime_exe) != OFFICIAL_EXE_SHA256:
            raise SystemExit('Windows runtime EXE does not match the pinned official release size and SHA-256')
        engine_bytes = args.runtime_exe.read_bytes()
        certificate_table = verified_engine(engine_bytes)

    suffix = 'Windows' if engine_bytes is not None else 'Windows-GameData'
    package_name = f'Bakugan-{release_version}-{suffix}'
    destination = (args.output_root or project / 'builds') / package_name
    destination.mkdir(parents=True, exist_ok=True)
    pack_name = 'BakuganPrototype-Windows.pck'
    if args.link_pack:
        target_pack = destination / pack_name
        if target_pack.exists():
            target_pack.unlink()
        os.link(source_pack, target_pack)
    else:
        shutil.copy2(source_pack, destination / pack_name)

    if engine_bytes is not None:
        executable = destination / 'BakuganPrototype-Windows.exe'
        executable.write_bytes(engine_bytes)
        if file_sha256(executable) != hashlib.sha256(engine_bytes).hexdigest():
            raise SystemExit('Packaged runtime differs from the official executable')
        launch_instructions = f'''Это автономный пакет: официальный движок Godot включён без изменения байтов.
Распакуйте всю папку Bakugan-{release_version}-Windows в новое место и откройте
BakuganPrototype-Windows.exe. Файл BakuganPrototype-Windows.pck должен
лежать рядом; не меняйте имена этих двух файлов и не переносите старый
исполняемый файл из прежней версии. Интернет и установка редактора
не требуются. Исходная таблица цифровой подписи движка сохранена вместе с его байтами.
Файлы CMD и PowerShell для запуска не используются.
'''
    else:
        launch_instructions = f'''Это только игровой PCK и документы. Windows .exe в этом архиве отсутствует.
Чтобы запустить игру без сценариев CMD или PowerShell:

1. Скачайте официальный Godot 4.6.3 для Windows x64 через браузер:
   {OFFICIAL_URL}
2. Распакуйте официальный архив. Переименуйте {ENGINE_NAME}
   в BakuganPrototype-Windows.exe. Содержимое исполняемого файла не меняйте.
3. Положите рядом с ним BakuganPrototype-Windows.pck из этого архива.
4. Откройте BakuganPrototype-Windows.exe. Движок сам найдёт одноимённый PCK.
   После получения движка интернет для игры не нужен.

SHA-256 официального ZIP:
{OFFICIAL_ZIP_SHA256}
'''

    readme = f'''Bakugan Arena — прототип {release_version}, Windows x64

{launch_instructions}
Нужен видеодрайвер с OpenGL 3.3. Реальный запуск под Windows здесь
не проверен. Сохранение исходных байтов движка и таблицы сертификата
не гарантирует решение Smart App Control на конкретном ПК.

В 0.18 боевые модели выбираются по наличию анимации: сначала родные DS,
затем анимированные DoC, затем статичные модели. Восстановлены 39 боевых
форм DS. У 29 фигурок DoC сфера и раскрытие имеют единый масштаб;
исправлены смещение при раскрытии и проваливание атак/реакций под пол.
Сферы согласованы с физическим диаметром. Движения исходных суставов
сохранены; перемещение корневой кости адаптировано к карточной сцене.

Бросок DS точнее обрабатывает первый контакт и остаток движения,
качение по наклону, затухание скорости, отскоки и опору на движущиеся
поверхности. Повторные прыжки слабее, камера плавно следует с упреждением.
На Pyrus добавлены исходная модель извержения и лавовые зоны из SetData.
Лава снимает 30 G, кроме Pyrus; потери входят в силу последующего боя.
Оранжевые зоны видны на мини-карте. Высокий бросок и прыжки обходят лаву.
Это первая тактически проработанная арена, а не полный перенос всех
опасностей DS. Разрушения, остальные стихии и полный набор Special Shots
остаются в плане. Численные коэффициенты физики — адаптация для ПК.
Подробности: RELEASE-0.18.md, DS-PHYSICS-0.18.md, ASSET-SOURCES-0.18.md.

Обновление 0.12 добавляет отдельный профиль правил Nintendo DS
с исходными параметрами 26 ворот и 40 способностей.
DS-колоды сохраняются отдельно от прежних Wii-колод; старые сохранения
мигрируют без подмены индексов каталогов. Дополнительно проверяются
очередь, владелец карты, наличие в руке и допустимая постановка.
В 0.13 режим DS использует свободную сферу в 3D, силу быстрого жеста
мышью, раздельные жесты коррекции, высокий и прямой бросок, отскоки,
наклоны и падение за край. Щёлкните по цели, затем зажмите видимую
сферу, быстро проведите вверх и отпустите. Стрелки/WASD меняют прицел
и корректируют движение; Пробел сохраняется как вариант зарядки для ПК.
Движущиеся исходные позы DS обновляют видимую модель и столкновения
одним игровым временем. Восстановлены SRT-каналы движения текстур.
В аниме-дуэли выберите бакугана и выставленную карту в списке или щелчком;
кнопка «Поставить бакугана»/Пробел размещает его сразу. Броска и промаха нет.

В 0.14 после броска Пробел, A на геймпаде или кнопка «Прыжок» позволяют
прыгнуть с поверхности. Повторное нажатие в воздухе не поднимает сферу.
До броска Q/E или плечевые L/R переключают четыре ракурса поля.
Управление учитывает выбранную камеру. Восстановлены исходные MAT0-
дорожки цвета и прозрачности арен, включая дальние вспышки Darkus.
Отскок и трение учитывают скорость движущейся поверхности.
Повторный матч сбрасывает время арены и камеру; смена окна отменяет ввод.

В 0.15 на DS-полях работают ускорители, трамплины и исходные монеты G/S.
Расстановку исходных объектов можно выбрать в «Арена и настройки».
G даёт бонус текущему броску, S заполняет отдельную шкалу каждой стороны.
При 100 S клавиша P включает усиление; запуск расходует всю шкалу.
Предметы возвращаются только при новом матче. Справка правил прокручивается.
Исправлен 128-кратный масштаб коротких SRT-значений движения текстур.

В 0.17.2 добавлено отдельное «SFM · поле Бакуган» из Workshop 3256465343.
Сохранены исходная геометрия и девять текстур. Поле доступно при броске
и в отдельной сцене боя; правила и физика используют прежний профиль ПК.
Из Monster batch 3696633172 перенесены 140 сеток и 322 текстуры:
45 сфер, 44 фигурки и 43 боевые формы вошли в каталог. В 0.18 боевые
OBJ уступают приоритет анимированным моделям DS/DoC. OBJ статичны.
Другие виды и анимированные формы DoC сохраняются. Текстура раскрытого
Darkus Mantris движется отдельно. Номера команд и характеристики не менялись.
Коллекция Monster batch: 65 ворот, 399 способностей и 261 карточка
характеристик/счётчик. Эти изображения пока не добавляют игровые эффекты.
Карты подготовлены до 1400 x 1900, текстуры до 2048 x 2048 с сохранением
пропорций. Подробные преобразования и ограничения указаны в документах.

В 0.17 перенесены 20 боевых форм бакуганов и 12 боевых форм ловушек
из Defenders of the Core DS. 29 закрытых форм раскрываются исходными
движениями. В коллекции доступны Maxus Dragonoid, Maxus Helios и
Cosmic Ingram; они не добавлены в команду с выдуманными параметрами.
Способности, попадания, призыв ловушек и победа получили эффекты.
Пауза и уменьшенное движение учитываются при раскрытии и эффектах.
Движения способностей подогнаны к полу сцены карточного боя.
Аниме-дуэль сохраняет прямую постановку на выбранную карту ворот.

Из 0.16 сохранены восемь увеличенных DS-полей. Расширены область
прицеливания и столкновения, стартовые позиции и сетка ворот.
Дальность броска согласована с полем. Мини-карта справа выбирает цель
щелчком; камера следует за сферой. Q/E — ракурс до броска,
колесо мыши — масштаб камеры. Исходная геометрия полей сохранена.
Оригинальный звук DS: 29 тем, 254 эффекта, 326 английских реплик.
Меню, поле, бой и аниме-дуэль используют исходные звуки.
В настройках: музыка, эффекты, озвучка и «ЗВУКИ DS» для прослушивания.
Привязка музыки к экранам и реплик к событиям пока адаптирована для ПК.

Полное описание: README.md, RELEASE-0.18.md, ASSET-SOURCES-0.18.md,
DS-RULES-AUDIT-0.12.md и THIRD-PARTY-LICENSES.txt.
Ресурсы включены в PCK и не загружаются из Интернета при запуске.
ROM, BIOS и исполняемый код DS не входят в пакет.

Исходные коэффициенты физики DS и полный набор событий стихийных арен
ещё не восстановлены: численная интеграция и управление адаптированы
для ПК. BVA и переключение текстур PAT не перенесены. MAT0 не означает
полное воспроизведение исходного освещения DS. Это ещё
не полный перенос DS: шесть мини-игр, кампания и все эффекты карт
остаются отдельной работой. Wii сохраняет прежний профиль движения.

Профиль прежних версий загружается автоматически из пользовательской
папки Godot «Bakugan — Arena Prototype». Распаковывайте обновление
целиком в новую папку; EXE и PCK должны принадлежать одной сборке.

Выполненные проверки и их пределы: VALIDATION.md.
Лицензии движка и шрифта: GODOT-LICENSE.txt и FONT-LICENSE.txt.
'''
    if release_version == '0.19':
        readme = f'''Bakugan Arena 0.19 — карты и мини-игры DS

{launch_instructions}

112 карт для DS-боя: 27 ворот и 85 способностей. Комбинации стихий,
Redo, Time Breaker, Double Input, запреты типов карт, отмена бонусов
и пропуск боя по G. В коллекции — метки и фильтр боевой доступности.

Перед боем 1–3 добавляют карты в цепь в порядке нажатия. В мини-игре
активируйте следующую выбранную карту; Backspace пропускает без расхода.
Показ карты останавливает таймер и ввод. Условия проверяются при активации.
Scratch, Spin, Timing, Pop, Trace, Bound доступны в тренировке и настройках;
подсказка каждого вида показана в бою. Подсчёт и тайминги настроены для ПК.

Аниме: выберите карту, участника и цель, затем нажмите «Активировать».
Для ловушки — отдельная подготовка; она используется только в аниме-дуэли
и входит в цепь ответов. Постановка бакуганов остаётся непосредственной.

DS-бросок: зажмите сферу и быстро проведите вверх. Мини-карта — цель;
короткие жесты или WASD — коррекция; Shift — тормоз; Пробел — прыжок;
T — прямой/высокий бросок; ESC — пауза. Поле 8×6, автоматические
первые/следующие ворота; ручной вариант есть в настройках.
Стартовая команда: Serpenoid Pyrus 190 G, Falconeer Ventus 210 G,
Juggernoid Aquos 200 G. Команды и карты DS/Wii сохраняются отдельно.

Оригинальный Scratch и бросок пройдены для сверки; пять остальных видов
реализованы по исходным подсказкам. Точные численные формулы и выбор
мини-игры по воротам ещё не восстановлены. Человеческие аватары,
полная кампания и сохранение незавершённого матча остаются в плане.

Проверено на Linux/OpenGL; реальный Windows-запуск здесь не выполнен.
Подробности: RELEASE-0.19.md и VALIDATION.md.
'''
    if release_version == '0.20':
        readme = f'''Bakugan Arena 0.20 — кампания и продолжение матча

{launch_instructions}

Кампания: семь глав, диалоги, разные команды/тактики. Победы открывают
бакуганов, арены и шесть новых карт; очки — на уровни и эволюции.
Команда и колода меняются в подготовке кампании. Это новый баланс ПК.

«Продолжить матч» восстанавливает бросок, мини-игру или аниме-цепь,
а не начинает этап заново. Автосохранение каждые три секунды и при
смене фазы; ESC — пауза/сохранение. Один слот; новый матч заменяет его.
Тренировка не заменяет контрольную точку основного матча.

Ворота увеличены. G/S, EXP, ускорители, трамплины, лава, препятствия,
струи Aquos, разряды Haos и потоки Ventus влияют на бросок.
Геометрия/текстуры/расстановки DS; новые роли и численная реакция
выведены из ресурсов и настроены для ПК, а не полностью восстановлены.

DS: зажмите сферу и быстро проведите вверх; мини-карта — цель;
WASD/короткий жест — коррекция, Shift — тормоз, Пробел — прыжок,
T — прямой/высокий бросок, P — усиление при 100 S. В бою 1–3
выбирают очередь способностей. Аниме сохраняет прямую постановку.

Старый профиль загружается автоматически. Распакуйте обновление целиком
в новую папку; EXE и PCK должны принадлежать одной версии.
Интернет при запуске не нужен. ROM/BIOS и код DS в пакет не входят.
Проверено на Linux/OpenGL; реальный Windows-запуск здесь не выполнен.
Подробности: RELEASE-0.20.md, ASSET-SOURCES-0.20.md, VALIDATION.md.
'''
    if release_version == '0.21':
        readme = f'''Bakugan Arena 0.21 — обучение, интерфейс и звук

{launch_instructions}

Тренировка → Первый бой: десять шагов с настоящим броском и боем.
Под сценой — формула G-Power обоих участников; шкала мини-игры DS отдельно.
В настройках: пять вкладок, 18 исходных анимированных аватаров DS,
графика, клавиши, чувствительность, мёртвая зона и отдельные звуковые каналы.

Геймпад: A — действие; B — тормоз/назад; X — высокий/прямой бросок;
Y — особый; LB/RB — камера; D-pad — команда/карты; Start — пауза.
Мини-игры DS: стик + A/RT. Аниме сохраняет постановку на выбранную карту.

SEQ_BGM_TUTORIAL и SEQ_BTL_BGM сверены с оригинальным SDAT.
Остальные музыкальные события адаптированы. Неустановленные голоса
не назначены персонажам; все реплики доступны в звуковой библиотеке.
Есть субтитры для подборки понятных реплик.

Старый профиль загружается автоматически. Сохраняйте EXE и PCK рядом.
Интернет при запуске не нужен. Контрольная точка основного матча
не заменяется тренировкой. В пакет не включены ROM/BIOS.
Linux/OpenGL проверен; Windows и физический геймпад здесь не проверялись.
Подробности: RELEASE-0.21.md, ASSET-SOURCES-0.21.md, VALIDATION.md.
'''
    if release_version == '0.22':
        readme = rf'''Bakugan Arena 0.22 — стабильность и диагностика

{launch_instructions}

Исправлены обработка скрытых анимаций, обход частоты прогноза прицела,
неограниченное удержание исходных компонентов арен. При ошибке сохранения
игра предлагает вернуться или выйти без сохранения. Аниме-колода получает
атомарную запись и резервную копию. Профиль прошлой версии сохраняется.

Встроенная проверка: два настоящих полных DS-матча и сохранение/продолжение
кампании через новый процесс. Она использует отдельный диагностический
профиль и пишет загрузку, кадры, память движка и результат в JSON.
В PowerShell из распакованной папки:
.\BakuganPrototype-Windows.exe --script res://scripts/release_verifier.gd -- --verify-release

Путь отчётов: пользовательская папка Godot для этой игры,
подпапка diagnostics/0.22/reports. Итог — summary.json.
Проверка не требует Python, ROM, редактора или интернет-соединения.
Она последовательно открывает три процесса; дождитесь итогового отчёта.

Полные прогоны и проверки выполнены на Linux/OpenGL. Настоящий Windows
и физический геймпад здесь недоступны: проверка Windows ещё не завершена.
Значения FPS программного llvmpipe нельзя переносить на видеокарту ПК.
Подробности: RELEASE-0.22.md, WINDOWS-QA-0.22.md, PERFORMANCE-0.22.md,
VALIDATION.md. EXE и одноимённый PCK сохраняйте рядом.
'''
    if release_version == '0.23':
        readme = f'''Bakugan Arena 0.23 — первый матч DS и отдельные сохранения

{launch_instructions}

Сохранения / продолжить: три кампании, три свободных матча/турнира,
три аниме-дуэли. Старое сохранение переносится автоматически.
Замена незаконченного боя требует подтверждения в самой игре.

Исправлены зависимость Scratch от FPS, прогноз усиления без S-Power,
продолжение камерного слежения и индикатор преимущества. Номинальные
веса и лимит Scratch не уменьшались; влияние карт измерено отдельно.
Есть десять русских субтитров к ранее расшифрованным репликам.

DS: выбери цель мини-картой, зажми сферу, быстро проведи вверх и отпусти.
WASD / короткие жесты — коррекция; Shift — тормоз; Пробел — прыжок.
T — высокий/прямой бросок. P — усиление при 100 S.
Перед боем 1–3 готовят цепь; в мини-игре активируется следующая карта.
Backspace пропускает выбранную карту. Аниме — прямая постановка на ворота.

Встроенная проверка использует отдельный профиль diagnostics/0.23.
Полные результаты фактически собранного Windows ZIP публикуются
в GitHub Release. Физический геймпад, звуковой вывод и FPS конкретного
ПК требуют проверки на устройстве. Нужен видеодрайвер OpenGL 3.3.

Это прототип с адаптированными численными формулами; полное совпадение
DS/Wii не заявляется. Подробности: RELEASE-0.23.md,
MINIGAME-BALANCE-0.23.md, WINDOWS-QA-0.23.md и VALIDATION.md.
'''
    if release_version == '0.24':
        readme = '''Bakugan Arena 0.24 — стихийные броски и карты поля DS

Распакуйте папку целиком и откройте BakuganPrototype-Windows.exe.
Одноимённый .pck должен оставаться рядом; интернет не нужен.

P выбирает Special Shot текущей стихии: цена 100 S.
В кампании нужен уровень 3; в свободном бою броски открыты.
T выбирает прямую или высокую траекторию. WASD/стик — коррекция,
Shift/B — тормоз, Пробел/A — прыжок.
12 фиолетовых карт-предметов на поле активируются при сборе.
В коллекции у них отдельно указаны эффект и доступность на поле.
На Pyrus жёлтое кольцо предупреждает об активной лаве, красное опасно.
Разрушенные препятствия и собранные предметы восстанавливаются из сохранения.
Слоты кампании, свободного боя и аниме-дуэли сохраняются отдельно.
В аниме-дуэли остаётся прямая постановка бакугана.

Имена и описания бросков/карт взяты из исходных текстов DS;
численная физика, уровень открытия и распределение предметов — адаптация ПК.
Подробнее: RELEASE-0.24.md, DS-FIELD-0.24.md, WINDOWS-QA-0.24.md.
'''
    (destination / 'README-RU.txt').write_text(readme, encoding='utf-8-sig')
    package_files = [pack_name, 'README-RU.txt']
    packaged_readme = (project / 'README.md').read_text(encoding='utf-8').replace('(docs/', '(')
    (destination / 'README.md').write_text(packaged_readme, encoding='utf-8')
    package_files.append('README.md')
    for reference in ['RULES-COMPARISON.md', 'WII-SOURCES.md', 'TABLETOP-SOURCES.md',
                      'FIDELITY.md', 'VALIDATION.md', 'DRAGONOID-REFERENCE.md', 'CHANGELOG.md',
                      'ASSET-SOURCES-0.7.md', 'ASSET-SOURCES-0.8.md', 'RELEASE-0.8.md', 'RELEASE-0.9.md',
                      'BLOXUGAN-COMPARISON-0.8.md', 'ANIME-DUEL-API-0.8.md',
                      'ANIME-DUEL-API-0.9.md', 'CARD-LIBRARY-0.8.md',
                      'CANONICAL-PROFILES-0.9.md', 'TRAPS-0.9.md',
                      'RELEASE-0.10.md', 'ASSET-SOURCES-0.10.md', 'DS-IMPORT-NOTES.md',
                      'DS-HUD-ASSETS.md', 'DS-MODEL-CONVERSION.md', 'DS-ARENAS.md',
                      'RELEASE-0.11.md', 'ASSET-SOURCES-0.11.md', 'DS-CARD-CATALOG.md',
                      'RELEASE-0.12.md', 'ASSET-SOURCES-0.12.md', 'DS-RULES-AUDIT-0.12.md',
                      'RELEASE-0.13.md', 'ASSET-SOURCES-0.13.md',
                      'RELEASE-0.14.md', 'ASSET-SOURCES-0.14.md',
                      'RELEASE-0.15.md', 'ASSET-SOURCES-0.15.md',
                      'RELEASE-0.16.md', 'ASSET-SOURCES-0.16.md',
                      'RELEASE-0.17.md', 'ASSET-SOURCES-0.17.md',
                      'RELEASE-0.17.2.md', 'ASSET-SOURCES-0.17.2.md',
                      'RELEASE-0.18.md', 'ASSET-SOURCES-0.18.md', 'DS-PHYSICS-0.18.md',
                      'RELEASE-0.19.md', 'ASSET-SOURCES-0.19.md',
                      'RELEASE-0.20.md', 'ASSET-SOURCES-0.20.md',
                      'RELEASE-0.22.md', 'WINDOWS-QA-0.22.md', 'PERFORMANCE-0.22.md', 'RELEASE-0.21.md', 'ASSET-SOURCES-0.21.md',
                      'DS-GAMEPLAY-COMPARISON.md', 'DS-REFERENCE-VERIFICATION.md', 'ROADMAP.md',
                      'RELEASE-0.24.md', 'DS-FIELD-0.24.md', 'WINDOWS-QA-0.24.md', 'RELEASE-0.23.md', 'WINDOWS-QA-0.23.md', 'MINIGAME-BALANCE-0.23.md', 'PROJECT-AUDIT-0.22.md']:
        text = (project / 'docs' / reference).read_text(encoding='utf-8')
        # Source catalogs live inside the PCK, not beside the EXE. A source
        # checkout's clickable ../assets link must not become a broken ZIP link.
        text = re.sub(r'\[([^\]]+)\]\(\.\./((?:assets|scripts)/[^)]+)\)',
                      lambda match: f'{match[1]} (`res://{match[2]}` внутри PCK)', text)
        for notice in ['GODOT-LICENSE.txt', 'THIRD-PARTY-LICENSES.txt', 'FONT-LICENSE.txt']:
            text = text.replace(f'](../{notice})', f']({notice})')
        (destination / reference).write_text(text, encoding='utf-8')
        package_files.append(reference)
    for notice in ['GODOT-LICENSE.txt', 'THIRD-PARTY-LICENSES.txt', 'FONT-LICENSE.txt']:
        shutil.copy2(source_pack.parent / notice, destination / notice)
        package_files.append(notice)
    asset_notice = (project / 'THIRD-PARTY-LICENSES.txt').read_bytes()
    runtime_notice = destination / 'THIRD-PARTY-LICENSES.txt'
    if asset_notice not in runtime_notice.read_bytes():
        with runtime_notice.open('ab') as notice:
            notice.write(b'\n')
            notice.write(asset_notice)
    if engine_bytes is not None:
        package_files.append('BakuganPrototype-Windows.exe')
        engine_sha = hashlib.sha256(engine_bytes).hexdigest()
        (destination / 'RUNTIME-SHA256.txt').write_text(
            f'Official release ZIP SHA-256: {OFFICIAL_ZIP_SHA256}\n'
            f'Unchanged packaged engine SHA-256: {engine_sha}\n'
            f'Official release: {OFFICIAL_URL}\n'
            'The file name is changed; executable bytes and certificate table are unchanged.\n'
            'Certificate presence is not a verification of signature validity or Windows trust.\n',
            encoding='utf-8')
        package_files.append('RUNTIME-SHA256.txt')
    for name in package_files:
        (destination / name).chmod(0o644)
    if args.prepare_only:
        print(json.dumps({'version': release_version, 'package': str(destination),
                          'files': package_files, 'runtime_included': engine_bytes is not None,
                          'pck_sha256': file_sha256(source_pack),
                          'engine_sha256': hashlib.sha256(engine_bytes).hexdigest() if engine_bytes is not None else None,
                          'archive_built': False}, indent=2))
        return
    archive_path = args.archive or project / 'builds' / f'{package_name}.zip'
    archive_path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive_path, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        # Ship the explicit manifest, never stale executables or launcher scripts.
        for name in package_files:
            archive.write(destination / name, Path(package_name) / name)
    archive_path.chmod(0o644)
    print(json.dumps({
        'archive': str(archive_path), 'bytes': archive_path.stat().st_size,
        'files': package_files, 'runtime_included': engine_bytes is not None,
        'pck_sha256': file_sha256(source_pack),
        'engine_sha256': hashlib.sha256(engine_bytes).hexdigest() if engine_bytes is not None else None,
        'pe_certificate_table': certificate_table, 'windows_execution_tested': False,
    }, indent=2))


if __name__ == '__main__':
    main()
