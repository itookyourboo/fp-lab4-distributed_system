# Лабораторная работа №4

## Цель работы

Получить навыки работы со специфичными для выбранной технологии/языка программирования приёмами.

## Личная цель

Моей целью не является разработка очень крутого приложения с большим смыслом и практическим применением. Здесь я хотел познакомиться с основными принципами и инструментами для разработки распределенных систем на Elixir. 

## Описание

### Веб-сервер

Поддерживает два endpoint'а:

- `GET /entries?list=<name>` - получить заметки из списка `<name>`
- `POST /entries?list=<name>&title=<title>` - добавить заметку `<title>` в список `<name>`

Каждый список обрабатывается отдельным процессом.

### База данных

- Создается на каждом узле.
- Списки хранятся в виде отдельного бинарного файла `data/nodeXXX/list_name`. Это сделано для удобной сериализации и десериализации.
- Использует пул `Worker`'ов для работы с данными.
- Поддерживается репликация: данные записываются сразу во все узлы.

## Запуск

Запуск первого узла на порту 8181:

```shell
$ TASKER_PORT=8181 iex --sname node1@localhost -S mix
```

Запуск второго узла на порту 8282:

```shell
$ TASKER_PORT=8282 iex  --sname node2@localhost -S mix
```

Соединение узлов:

```shell
iex(node2@localhost)1> Node.connect(:node1@localhost)
true
```

Чтобы подключить больше узлов, достаточно подключить каждого из них к любому из предыдущих. Тогда они все будут соединены:

```shell
$ TASKER_PORT=8383 iex  --sname node3@localhost -S mix
```

```shell
iex(node3@localhost)1> Node.connect(:node2@localhost)
true
iex(node3@localhost)2> Node.list()
[:node2@localhost, :node1@localhost]
```

## Пример работы

Три узла работают на портах 8181, 8282 и 8383 соответственно.

```shell
NODE_1=localhost:8181
NODE_2=localhost:8282
NODE_3=localhost:8383
```

Создаем заметку, обратившись к первому узлу:

```shell
$ curl -X POST -G \
"$NODE_1/entries" \
-d 'list=Alex' \
-d 'title=Finish%20FP'
OK
```

Проверим, действительно ли она сохранилась на первом узле:

```shell
$ curl -X GET -G \
"$NODE_1/entries" \
-d 'list=Alex'
1. Finish FP
```

Проверим, есть ли она на втором узле:

```shell
$ curl -X GET -G \
"$NODE_2/entries" \
-d 'list=Alex'
1. Finish FP
```

Создадим заметку, обратившись к третьему узлу:

```shell
$ curl -X POST -G \
"$NODE_3/entries" \
-d 'list=Bob' \
-d 'title=Prepare%20to%20Modeling'
OK
```

Проверим, есть ли она на втором узле:

```shell
$ curl -X GET -G \
"$NODE_2/entries" \
-d 'list=Bob'
1. Prepare to Modelin
```

## Архитектура

### Кластер

![Кластер](./docs/cluster.jpg)

### Приложение

![Приложение](./docs/system.jpg)

### Диаграмма активностей 

![Диаграмма активностей](./docs/activity.jpg)

## CAP

### [V] Согласованность

Достигается благодаря репликации данных. Каждый узел записывает изменения не только у себя, но и у других узлов.

#### Доказательство

Достаточно тяжело обосновать данное свойство теоретически, поэтому в подтверждение были написаны Property based тесты:

1. **Репликация**. Проверяет, что N записей, сделанных в узел 0, будут доступны во всех других узлах. Также показывает, что большое количество параллельных запросов к единому ресурсу не приводит к блокировкам или потере данных.
    
    ```python
    def __test_replication(self, name: str, count: int) -> None:
        with ThreadPool() as pool:
            pool.map(lambda i: send_entry(0, name, f'note{i}'), range(count))

        for i in range(self.NODES_COUNT):
            entries = get_entries(i, name)
            entries_count = len(entries.splitlines())
            self.assertEqual(entries_count, count, f'Node {i} has {entries_count} tasks instead of {count}')
    ```

2. **Синхронизация**. Проверяет, что при параллельных записях в разные узлы не возникает взаимных блокировок, а сохраненные данные будут равны с точностью до их порядка.

    ```python
    def __test_synchronizing(self, name: str, count: int) -> None:
        with ThreadPool() as pool:
            pool.map(lambda i: send_entry(i % self.NODES_COUNT, name, f'note{i}'), range(count))

        results = []
        for i in range(self.NODES_COUNT):
            entries = get_entries(i, name)
            entries_count = len(entries.splitlines())
            self.assertEqual(entries_count, count, f'Node {i} has {entries_count} instead of {count}')
            results.append(entries)
        
        with self.subTest('Test all results are equal (including order)'):
            self.assertEqual(len(set(results)), 1)
    ```

Перед запуском тестов нужно поднять и соединить N узлов. Elixir не предоставляет возможностей для автоматического разворачивания кластера, поэтому приходится это делать руками.

```shell
$ TASKER_PORT=8000 iex --sname node0@localhost -S mix
$ TASKER_PORT=8001 iex --sname node1@localhost -S mix
$ TASKER_PORT=8002 iex --sname node2@localhost -S mix
$ TASKER_PORT=8003 iex --sname node3@localhost -S mix
```

```shell
iex(node0@localhost)1> Node.connect(:node1@localhost)
true
iex(node0@localhost)2> Node.connect(:node2@localhost)
true
iex(node0@localhost)3> Node.connect(:node3@localhost)
```

Запуск тестов:

```shell
$ python test/test_consistency.py
test_replication (__main__.TestConsistensy) ... ok
test_synchronizing (__main__.TestConsistensy) ... ok

----------------------------------------------------------------------
Ran 2 tests in 79.357s

OK
```

[Исходный код тестов](test/test_consistency.py)

### [X] Доступность

В системе нет балансировщика. Обращение к данным происходит по адресу конкретного узла. Если он выйдет из строя, то ему придется обращаться к другим узлам.

### [V] Устойчивость к разделению

Если отвалился какой-то из узлов, то система в целом продолжит работать. 

## Выводы

Эта лабораторная была самой интересной, так как она позволила понять, чем же Elixir так хорош.

Из коробки предоставляется большое количество инструментов, которые позволяют легко создавать процессы и управлять ими. Это позволяет быстро разрабатывать отказоустойчивые кластеры.

Самое тяжелое - это поиск информации. У Elixir не такое большое сообщество, поэтому пришлось по крупицам собирать ее из форумов, чатов и книг. Многие ответы были нерелевантными из-за несовместимости с новыми версиями языка или библиотек.

В остальном все понравилось - лабораторная позволила с другой стороны посмотреть на разработку приложений. После фреймворков Python'а это очень необычно.
