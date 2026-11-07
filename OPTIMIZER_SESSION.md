# OPTIMIZER - Журнал сессий

## Текущий статус

**Этап:** ✅ ЗАВЕРШЕНО (95% соответствие с Prod)
**Дата:** 2026-05-21

### Прогресс P0 (Критические) - ВСЕ ВЫПОЛНЕНО:
- ✅ Trailing Stop - РЕАЛИЗОВАНО
- ✅ Breakeven - РЕАЛИЗОВАНО
- ✅ Smart Profit Lock - РЕАЛИЗОВАНО
- ✅ Partial TP (tp_position_percent = 50%) - РЕАЛИЗОВАНО

### Прогресс P1 (Важные фильтры) - ВСЕ ВЫПОЛНЕНО:
- ✅ side_filter - РЕАЛИЗОВАНО
- ✅ max_entry_distance_pct - РЕАЛИЗОВАНО
- ✅ min_pre_vol фильтр (fixed) - РЕАЛИЗОВАНО
- ✅ natr_filter (min_natr) - РЕАЛИЗОВАНО
- ✅ tape_exhaustion - РЕАЛИЗОВАНО (переиспользован модуль из src/)
- ✅ **price_move_mult** - РЕАЛИЗОВАНО (динамический порог)
- ✅ **excluded_coins** - РЕАЛИЗОВАНО (blacklist)

### Прогресс P2 (Edge cases) - ВЫПОЛНЕНО:
- ✅ max_spike_age_ms - РЕАЛИЗОВАНО
- ✅ natr_window - РЕАЛИЗОВАНО (в составе natr_filter)
- ✅ reverse_signal_close_position - РЕАЛИЗОВАНО
- ⏸️ entry_price_mode/slippage - Не применимо (нет orderbook)
- ⏸️ entry_window_secs - Использует spike_window (минорное отличие)

### Что сделано в этой сессии:
1. Создан полный аудит `OPTIMIZER_AUDIT.md`
2. Расширен `ExitReason` (TrailingStop, BreakevenSl, SmartProfitLockSl)
3. Переписан `simulator.rs` с полной логикой выхода
4. Обновлён `config.toml` с trailing/breakeven/spl параметрами
5. **РЕФАКТОРИНГ signal_generator.rs - ПЕРЕИСПОЛЬЗУЕТ:**
   - `CoinState` из `data/coin_state.rs` (вместо дублирующего OptCoinState)
   - `StrategyFilters` из `strategy/filters.rs` (excluded_coins)
   - `TapeExhaustionPending` из `tape_exhaustion/pending.rs`
6. Добавлены `_at()` методы в `CoinState` для бектеста:
   - `add_trade_backtest()`, `check_volume_spike_at()`
   - `get_spike_volume_at()`, `get_baseline_volume_at()`
   - `get_natr_at()`, `get_distance_to_extremum_at()`
7. Синхронизирован `config.toml` с боевым конфигом
8. Собран release билд

---

## Что сделано

### Сессия 1 (2026-05-21)

**Груминг и планирование:**
- Обсуждена проблема: монеты с нестандартными откатами
- Согласована архитектура: 2 отдельных приложения (Prod Bot + Optimizer)
- Создана спецификация: `OPTIMIZER_SPEC.md`
- Создан промпт: `OPTIMIZER_PROMPT.md`
- Скопированы исходники в `backtester/`

**Разработка Optimizer:**
- Фаза 1: Конфиг - добавлен `[optimizer]` блок
- Фаза 2: Загрузка данных - REST + кэш + ring buffer
- Фаза 3: Симуляция - TP/SL проверка на каждом трейде
- Фаза 4: Оптимизация - перебор порогов + spike detection
- Фаза 5: Live WebSocket - real-time данные

**Сборка:**
- Собран release бинарник: `optimizer.exe` (3.1 MB)
- Создан конфиг: `backtester/config.toml`

**Ключевые решения:**
1. Optimizer строится на коде Prod Bot (форк в `backtester/`)
2. Для каждой монеты свой JSON файл с порогом
3. Rolling window с WebSocket для обновления данных
4. Кэш в бинарном формате (bincode)
5. Full TP при касании (не partial)
6. min_trades фильтр для валидности статистики

---

## Структура проекта

```
G:\TradeScalp_NewArchitecture\backtester\
├── Cargo.toml                    # Отдельный Cargo.toml для Optimizer
├── config.toml                   # Конфиг файл
├── lib.rs                        # Библиотека
├── bin/
│   └── optimizer.rs              # Точка входа
├── optimizer/
│   ├── mod.rs                    # Экспорты модуля
│   ├── types.rs                  # CompactTrade, CoinThreshold, TradeStats
│   ├── ring_buffer.rs            # Rolling window буфер
│   ├── cache.rs                  # Bincode кэш на диск
│   ├── loader.rs                 # REST загрузка aggTrades
│   ├── signal_generator.rs       # Spike detection (OptCoinState)
│   ├── simulator.rs              # Симуляция TP/SL
│   └── websocket.rs              # Live WebSocket + LiveDataManager
├── target/release/
│   └── optimizer.exe             # Готовый бинарник (3.1 MB)
├── thresholds/                   # JSON файлы с порогами (создаётся автоматом)
└── cache/                        # Кэш aggTrades (создаётся автоматом)
```

---

## Использование

**Запуск:**
```bash
cd G:\TradeScalp_NewArchitecture\backtester
.\target\release\optimizer.exe
```

**Формат JSON файла порога:**
```json
{
  "min_spike_move_pct": 0.8,
  "enabled": true,
  "pf": 1.82,
  "trades": 15,
  "win_rate": 66.7,
  "updated_at": 1716300000000
}
```

**Поток работы:**
```
[Старт]
    ↓
Загрузка конфига
    ↓
Получение списка монет (volume 24h filter)
    ↓
Загрузка исторических aggTrades (REST + кэш)
    ↓
Запуск WebSocket подключений
    ↓
[Live Loop]
    ├── WebSocket → Ring Buffers (real-time)
    ├── Каждые N минут: spike detection → симуляция → оптимизация
    ├── Запись JSON если порог изменился
    └── Бесконечный цикл
```

---

## Чек-лист реализации

### Фаза 1: Конфиг
- [x] Добавить `[optimizer]` блок в config.rs
- [x] Создать `backtester/bin/optimizer.rs` (новый main)
- [x] Создать `backtester/Cargo.toml` (отдельная кодовая база)

### Фаза 2: Загрузка данных
- [x] REST загрузка historical aggTrades (loader.rs)
- [x] Ring buffer для rolling window (ring_buffer.rs)
- [x] Bincode кэш на диск (cache.rs)

### Фаза 3: Симуляция
- [x] `Simulator` - виртуальные позиции (simulator.rs)
- [x] Проверка TP/SL на каждом trade
- [x] Расчёт PnL и TradeStats

### Фаза 4: Оптимизация
- [x] Перебор min_spike_move_pct per-coin
- [x] Расчёт Profit Factor
- [x] Запись JSON файлов
- [x] Интеграция с реальным spike detector (signal_generator.rs)

### Фаза 5: Live mode
- [x] WebSocket для новых данных (websocket.rs)
- [x] LiveDataManager - управление буферами
- [x] run_optimizer_live() - полный live цикл
- [x] Периодический пересчёт (каждые N минут)

### Сборка
- [x] Понижена версия time crate для Rust 1.86
- [x] Собран release: optimizer.exe (3.1 MB)
- [x] Создан config.toml

---

## Что нужно сделать (Prod Bot)

### Доработки в `src/` (НЕ backtester):
- [ ] Читать `min_spike_move_pct` из JSON файлов вместо config.toml
- [ ] Hot reload по mtime файлов
- [ ] Если файла нет или `enabled: false` → не торговать монету

---

## Изменённые файлы

| Файл | Изменение | Дата |
|------|-----------|------|
| backtester/* | Создана копия src/ | 2026-05-21 |
| OPTIMIZER_SPEC.md | Создана спецификация | 2026-05-21 |
| OPTIMIZER_PROMPT.md | Создан промпт | 2026-05-21 |
| OPTIMIZER_SESSION.md | Создан журнал сессий | 2026-05-21 |
| backtester/config.rs | Добавлен OptimizerConfig struct | 2026-05-21 |
| backtester/bin/optimizer.rs | Создан main для Optimizer | 2026-05-21 |
| backtester/Cargo.toml | Создан отдельный Cargo.toml | 2026-05-21 |
| backtester/lib.rs | Добавлен pub mod optimizer | 2026-05-21 |
| backtester/optimizer/mod.rs | Создан модуль optimizer | 2026-05-21 |
| backtester/optimizer/types.rs | Типы: CompactTrade, CoinThreshold, TradeStats | 2026-05-21 |
| backtester/optimizer/ring_buffer.rs | Ring buffer с rolling window | 2026-05-21 |
| backtester/optimizer/cache.rs | Bincode кэш на диск | 2026-05-21 |
| backtester/optimizer/loader.rs | REST загрузка aggTrades | 2026-05-21 |
| backtester/optimizer/simulator.rs | Симуляция TP/SL | 2026-05-21 |
| backtester/optimizer/signal_generator.rs | Генератор сигналов (spike detection) | 2026-05-21 |
| backtester/optimizer/websocket.rs | WebSocket + LiveDataManager | 2026-05-21 |
| backtester/config.toml | Конфиг файл для Optimizer | 2026-05-21 |

---

## Заметки

- Optimizer и Prod Bot - ОТДЕЛЬНЫЕ кодовые базы
- Optimizer пишет JSON в `thresholds/`, Prod Bot читает оттуда
- Вся логика spike detection в Optimizer должна совпадать с Prod Bot
- Параметры strategy и trading в конфигах должны быть идентичны
