# roblox-game

Проект Roblox-игры. Код хранится в `src/` и синхронизируется с Roblox Studio через [Rojo](https://rojo.space).

## Первая настройка (один раз на компьютер)

1. Установи [Roblox Studio](https://create.roblox.com), [VS Code](https://code.visualstudio.com) и [Git](https://git-scm.com/downloads).
2. Установи **Rokit**. Это менеджер инструментов: он ставит Rojo, Selene и StyLua нужных версий.
   - Windows (PowerShell):
     ```powershell
     Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression
     ```
   - macOS:
     ```sh
     curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
     ```
   После установки перезапусти терминал.
3. Открой терминал в папке проекта и установи инструменты из `rokit.toml`:
   ```sh
   rokit install
   ```
   Rokit спросит, доверяешь ли ты авторам инструментов. Ответь «да».
4. Установи плагин Rojo в Studio:
   ```sh
   rojo plugin install
   ```
   Если Studio была открыта, перезапусти её.
5. Открой папку проекта в VS Code: **File → Open Folder**. VS Code предложит установить рекомендованные расширения (Rojo, Luau LSP, StyLua, Selene). Согласись.

## Как работать каждый день

1. Запусти сервер Rojo. Это можно сделать в терминале VS Code:
   ```sh
   rojo serve
   ```
   Или нажми на иконку Rojo в нижней панели VS Code.
2. В Studio открой своё место (для начала подойдёт шаблон **Baseplate**).
3. Во вкладке **Plugins** нажми **Rojo → Connect**.
4. Пиши код в VS Code. Каждое сохранение файла сразу появляется в Studio.
5. Тестируй игру в Studio кнопкой **Play**.
6. Закончил кусок работы — сохрани его в Git:
   ```sh
   git add .
   git commit -m "Что сделал"
   git push
   ```

## Что где хранится

| Папка в проекте | Куда попадает в Studio | Для чего |
|---|---|---|
| `src/server` | `ServerScriptService.Server` | Серверная логика: деньги, урон, сохранения |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` | Клиент: интерфейс, управление, эффекты |
| `src/shared` | `ReplicatedStorage.Shared` | Общие модули: настройки, утилиты |

Карта, модели и интерфейс, собранные мышкой в Studio, в файлы **не** попадают. Они хранятся в самом месте. Сохраняй его через **File → Publish to Roblox**.

### Тип скрипта задаётся расширением файла

| Имя файла | Что создаётся в Studio |
|---|---|
| `Name.server.luau` | `Script`: выполняется на сервере |
| `Name.client.luau` | `LocalScript`: выполняется у игрока |
| `Name.luau` | `ModuleScript`: подключается через `require` |
| папка с `init.luau` внутри | `ModuleScript`, а остальные файлы папки становятся его детьми |

## Полезные команды

```sh
rojo serve                 # синхронизация со Studio
rojo build -o game.rbxl    # собрать место в файл (открывается в Studio)
selene src                 # найти ошибки и подозрительный код
stylua src                 # отформатировать код
```
