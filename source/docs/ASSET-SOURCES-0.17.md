# Источники 0.17

Пользователь предоставил архив `Bakugan - Defenders of the Core (USA) (En,Fr).zip`
через [папку Google Drive](https://drive.google.com/drive/folders/17yf8bGyQSoL6nLuupuRWIhEz4VO1J2kn).
ZIP: 47 946 637 байт, SHA256
`82a9c2b4f3a700f01112195139d41e363dc4e50cfafbb77be1859572db2c1858`.
Образ DS: `BAKUGAN2 U`, код `B4BE`, 67 108 864 байта, SHA256
`4853f4231b1623a4dcac04cb14af0480e7781cfbd93f54aa4d1caf132c932907`.

NitroFS: 8716 записей. Для 0.17 использованы каталоги `3d/Bakugan_Real/L`,
`3d/Bakugan_Trap/L`, `3d/Bakugan_Sphere/L`, `3d/Bakugan_TrapSphere/L`,
связанные NSBTX и BCA0 в `*_data.bin`, отдельные figure-бандлы и две таблицы
имён из `font`. ROM, исходный ZIP, программный код игры и BIOS в пакет
не включаются. Низкие LOD и прочие служебные модели не считаются новыми видами.

Преобразование: `tools/import_doc_models17.py`, локальный apicula;
все изображения встроены в GLB. Хеши входов, выходов, родные расцветки,
сопоставления имён, клипы и ограничения находятся в
[манифесте](../assets/doc/models/model_manifest.json).
Итог: 61 уникальный GLB, 32 боевые формы и 29 анимируемых фигурок,
которые также дают 29 закрытых форм. Подмена палитры глобальной окраской
не применяется. Визуально проверены все формы и выбранные ability-позы.

Имена DoC отличаются от некоторых аниме-имён: Mechanical Helios →
Cyborg Helios, Dual Elfin → Minx Elfin, Midnight Percival → Knight Percival;
табличные Wilda/Nemus/Brontes соотнесены с видимыми формами.
Исходные подписи сохраняются в метаданных. Hyper/Cosmic-игрушки имеют
собственные идентичности и не объявляются фигурками Cross/Master.

`tools/measure_doc_models17.py` измеряет исходную скиннинг-деформацию
в Blender; `tools/measure_doc_actions17.py` вычисляет поправку пола для
ПК-сцены. Геометрия и исходные клипы в GLB не переписываются этой поправкой.
Численная физика, правила и G не извлекаются из внешнего вида.

Существующие ресурсы: [0.16](ASSET-SOURCES-0.16.md),
[0.7](ASSET-SOURCES-0.7.md), [0.8](ASSET-SOURCES-0.8.md).
