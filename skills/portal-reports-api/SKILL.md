---
name: portal-reports-api
description: Use when you need data from a report on customer.e-comportal.com (PIM/WMS портал) — «выгрузи отчёт с портала», «reports?reportId=N», «нажми Экспорт в XL», или когда нужны ОСТАТКИ НА ПРОШЛУЮ ДАТУ. Все отчёты портала доступны по API без браузера; у части отчётов нет параметра даты, а история остатков есть в отдельном API аналитики.
---

# Отчёты портала customer.e-comportal.com через API

Кнопка «Экспорт в XL» на странице `/reports?reportId=N` — это асинхронная
задача API. Браузер не нужен.

## Шаги

1. **Логин**: `POST /api/auth/login` `{"login","password","remember_me":false,"fingerprint":"<проект>"}`
   → `access_token` → заголовок `Authorization: Bearer …`. Учётка PIM_LOGIN/PIM_PASSWORD
   лежит в `/root/logistics-agent-secrets/.env` (копировать в `<проект>-secrets/`, chmod 600).
2. **Каталог отчётов с параметрами**: `GET /api/customer/reports/list` — дерево групп,
   у каждого отчёта `id`, `name`, `parameters[{id,name,data_type,required}]`.
   (`POST /api/reports/report/{id}/parameters/values` с пустым телом отдаёт `[]` —
   ему нужно передать список `[{"id":<param>,"value":null}, …]`, тогда вернёт допустимые значения:
   кабинеты, периоды, столбцы.)
3. **Запуск**: `POST /api/reports/report/{id}` телом `[{"id":<param>,"value":…}, …]` → `task_id`.
   Даты — `"YYYY-MM-DD"`, кабинеты/продавцы — список id.
4. **Поллинг**: `GET /api/reports/report/{task_id}` до `status == "SUCCESS"`
   (бывает PENDING минутами в очереди). Файл: `data.data.media.url` (`/api/cdn/media/<uuid>`), качать с тем же Bearer.

Готовый клиент: `/root/upravlenka/pim.py` (`session()`, `report_params()`, `run_report()`).

## Грабли

- **Кабинеты искать по юрлицу, не по названию.** Одноимённых кабинетов много
  (портал общий на всех клиентов; у Ozon «E-COM TRADE» 27 и «ООО Е-КОМ Трейд (E-COM PORTAL)» 35
  — разные, суммы расходятся). Карта юрлицо→кабинеты: `GET /api/customer/companies`
  (+ИНН) и `GET /api/customer/companymarketplace` (`company_id`, `marketplace_id`: 1 WB, 2 Ozon).
- **Буквы столбцов в API-выгрузке ≠ как видит владелец в UI** (в UI добавлены
  столбцы впереди; «столбец H» у владельца был E у нас). Брать столбец по ЗАГОЛОВКУ
  и переспросить заголовок, если сумма выглядит странно.
- **У части отчётов нет параметра даты** (например 15 «Заказы с детализацией
  до продукта» — всегда «на сейчас»). Нужна цифра на 1-е число → снимать кроном
  в тот день; задним числом не восстановить.
- **История остатков есть** в API аналитики: `POST /api/analytics/stocks?date_from=D&date_to=D&units=price|items|incoming_price`,
  тело `{"companymarketplace_id":[…]}`; строка на каждый склад — суммировать
  `available+reserved`. `incoming_price` = по себестоимости. Совпадает со
  столбцом «остатки» отчёта 15, но «в поставке/заказано» в истории НЕТ.
  Там же `/api/analytics/sales` и `/orders` по дням (`quantity` в выбранных units) —
  удобно для sanity-check сумм из отчётов.
- В отчёте Ozon 66 строка 2 без «ID продукта» — итоговая, брать итоги из неё.
