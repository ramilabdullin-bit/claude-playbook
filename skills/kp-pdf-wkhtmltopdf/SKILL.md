---
name: kp-pdf-wkhtmltopdf
description: Use when making a branded PDF (КП, прайс, письмо клиенту) из HTML на этом сервере — здесь нет Chrome/WeasyPrint, только wkhtmltopdf 0.12.6 с НЕпатченным Qt, и он молча ломает три вещи: woff2-шрифты (текст выходит Montserrat-Thin), CSS grid/flex (колонки схлопываются) и высоту страницы в mm (297mm занимает ¾ листа, контент рвётся на 3–4 страницы). Also use for "сделай КП как прошлое", "собери PDF из HTML", "почему в PDF тонкий шрифт", "почему 4 страницы вместо 2".
---

# КП в PDF через wkhtmltopdf (непатченный Qt)

Эталон вёрстки и рабочий шаблон: `/root/прочее/kp/KP_KPB_FBS_2026-09-22.html`
(брендбук e-comportal: Montserrat, #ff6600/#e35f00, разделы «Как мы поняли
задачу → Что входит → Тариф за заказ (базовый vs Ваш) → Возвраты → Хранение →
Ориентир по месяцу → О складе → Запуск → Следующий шаг»). Цифры брать только из
`/root/leads-agent/tools/pricing.py`, не из калькулятора сайта.

## Команда

```bash
wkhtmltopdf -q --page-size A4 -T 0 -B 0 -L 0 -R 0 --enable-local-file-access in.html out.pdf
pdfinfo out.pdf | grep Pages            # должно быть ровно столько, сколько .page
pdftoppm -r 70 -png out.pdf /tmp/x/kp   # и ПОСМОТРЕТЬ картинки, не верить на слово
pdffonts out.pdf                         # не должно быть Montserrat-Thin
```

`--zoom`, `--dpi`, `--disable-smart-shrinking`, `--print-media-type` на этом
билде игнорируются («not support using unpatched qt») — не тратить время.

## Три ловушки и обход

1. **woff2 не поддерживается.** Инлайновый variable-Montserrat в старых КП
   (`KP_Liberty_Drive…`, `KP_Zhenskaya_odezhda…`) дал фолбэк Montserrat-Thin —
   весь текст волосяной. Использовать статические TTF из
   `/root/прочее/kp/fonts/Montserrat-{Regular,Medium,SemiBold,Bold,ExtraBold}.ttf`
   (сконвертированы fontTools из `projects/e-comportal/presentation/fonts/…woff`):
   `@font-face{font-family:Montserrat;font-weight:700;src:url(file:///root/прочее/kp/fonts/Montserrat-Bold.ttf)}` — по одному на вес.
2. **Нет CSS grid, flex через `display:-webkit-box`.** Двухколоночные блоки и
   KPI-плашки делать `<table>` (в шаблоне уже так: `.grid`, `.kpi`), шапку —
   `-webkit-box` + `-webkit-box-flex`, футер — `float:right` для правой части.
3. **mm масштабируются ~×1.27.** `.page{height:297mm}` занимает ¾ листа, при
   переполнении div рвётся на лишние страницы. Рабочее значение —
   `height:376mm` (396 уже переливается). Подбирать по картинке: футер должен
   лечь у нижнего края.

## Готовые числа для КП по FBS (тир 3000–4999 шт/мес, до 10 л)
подбор+стикер+доставка 51,5 ₽; ЧЗ-скан 3 ₽; приёмка до 3 кг 3 ₽; разгрузка
паллеты 200 ₽; хранение 70 ₽/паллето-сутки; возвраты 20/10 ₽, переупаковка
до 10 л 44,6 ₽, перемаркировка/вывод КМ 5 ₽. Проект договора-шаблона —
`/root/wms_review/Договор_фулфилмент_шаблон_FBO_FBS_2_с_доп_пунктами.docx`
(реквизиты и Приложение 1 «Прайс-лист» пустые, заполнять из КП).
