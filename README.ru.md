# Hats

_[English](README.md) | **Русский**_

![Hats](images/hats.png)

AMX Mod X плагин для Counter-Strike.

Плагин позволяет игроку носить шапки на голове. Основной особенностью этой модификации является возможность игрока выбирать скин или сабмодель головного убора самостоятельно и установить какие их них будут доступны исключительно VIP-игрокам.

## Команды
* `amx_givehat <ник игрока> <индекс шапки> <индекс скина/сабмодели>` — надеть/снять шапку игроку по указанному нику (доступна для пользователей с флагом "l" и в консоли сервера);
* `amx_removehats` — снять шапки с каждого игрока (доступна для пользователей с флагом "l" и в консоли сервера);
* `hats` — консольная команда для вызова меню выбора шапки;
* `say /hats` или `say_team /hats` — команда чата для вызова меню выбора шапки.

## Настройки
Плагин предоставляет два способа редактирования списка шапок: с помощью файлов `amxmodx/configs/hats.json` и `amxmodx/configs/hats.ini`. Способ через JSON более структурированный и позволяет задавать имена сабмоделями и скинам шапки (в противном случае названия будут извлекаться из файла модели), но менее компактный. По умолчанию используется первый метод. Для переключения на формат .ini необходимо удалить или закомментировать строку `#define USE_JSON`. Плагин автоматически определяет кол-во скинов и сабмоделей, поэтому нет необходимсти задавать их вручную.

### Конфигурация через hats.json
Помимо названия шапки в разметке содержатся следующие поля:
* model: *строка* файл модели;
* tag: *символ* тэг (можно не указывать если нет хотите использовать скины/сабмодели);
* vip: *true|false* доступ только для VIP-игроков (необязательное поле);
* items: *массив строк* названия скинов/сабмоделей в меню (необязательное поле).

Пример:
```json
{
    "Santa": {
        "model": "santa_hat_v2.mdl",
        "tag": "s",
        "items": [
            "Red Santa",
            "Blue Santa",
            "Magenta Santa",
            "Cyan Santa"
        ]
    },
    "Dragon Nest Pack": {
        "model": "hats_dn.mdl",
        "vip": true,
        "tag": "b"
    },
    "Minecraft": {
        "model": "pony_antagonist.mdl",
        "tag": "s"
    },
    "Captain BaseBallBat-Boy": {
        "model": "CaptainBaseBallBat-Boy.mdl"
    }
}
```

### Конфигурация через hats.ini
Формат регистрации шляпы следующий:
"__mdl__" "__v__`tag`__name__"

где:
* __mdl__ — файл модели;
* __v__ — доступ только для VIP-игроков (для обычных игроков можно не указывать);
* `tag` — тэг (можно не указывать если не хотите использовать скины/сабмодели);
* __name__ — название шапки в меню.

Пример:
* _"Headcrab.mdl" "Хедкраб"_ — шапка Хедкраба без дополнений;
* _"santa_hat_v2.mdl" "sСанта"_ — шапка Санты со всеми скинами;
* _"pony_v2.mdl" "cПони"_ — шапка пони со скинами и сабмоделями;
* _"pony_antagonist.mdl" "vcПони антигерои"_ — VIP-шапка пони со скинами и сабмоделями.

### Тэги:
* _s_ — будут считываться только скины;
* _b_ — будут считываться только сабмодели;
* _c_ — универсальный тип, который не исключает возможность наличия скинов и сабмоделей одновременно в шапке (используйте его, если вы сомневаетесь в выборе тэга или хотите комбинировать скины и сабмодели);
* _t_ — скин или сабмодель будет устанавливаться в соответствии с командой игрока.

## Требования
- [Reapi](https://github.com/s1lentq/reapi)

## Авторы
- [Psycrow](https://github.com/Psycrow101)
