import glob
import os
import requests
import unittest
from multiprocessing.pool import ThreadPool


URL_TEMPLATE = "http://localhost:8{:0>3}/entries"


def get_url(node_num: int) -> str:
    return URL_TEMPLATE.format(node_num)


def send_entry(node_num: int, name: str, title: str) -> str:
    return requests.post(get_url(node_num), params={
        'list': name,
        'title': title,
    }).text


def get_entries(node_num: int, name: str) -> str:
    return requests.get(get_url(node_num), params={
        'list': name,
    }).text



class TestConsistensy(unittest.TestCase):
    NODES_COUNT = 4

    def test_replication(self) -> None:
        entries_count = [10, 100, 1_000, 10_000]
        for count in entries_count:
            with self.subTest(f'Test replication with {count} writes'):
                self.__test_replication(f'test_replication{count}', count) 

    def test_synchronizing(self) -> None:
        entries_count = [10, 100, 1_000, 10_000]
        for count in entries_count:
            with self.subTest(f'Test synchronizing with {count} writes'):
                self.__test_synchronizing(f'test_synchronizing{count}', count)

    def __test_replication(self, name: str, count: int) -> None:
        with ThreadPool() as pool:
            pool.map(lambda i: send_entry(0, name, f'note{i}'), range(count))

        for i in range(self.NODES_COUNT):
            entries = get_entries(i, name)
            entries_count = len(entries.splitlines())
            self.assertEqual(entries_count, count, f'Node {i} has {entries_count} tasks instead of {count}')

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

    @classmethod
    def clear_data(cls) -> None:
        for file in glob.glob("data/*/*"):
            os.remove(file)

    @classmethod
    def setUpClass(cls) -> None:
        cls.clear_data()

    @classmethod
    def tearDownClass(cls) -> None:
        cls.clear_data()


if __name__ == '__main__':
    unittest.main(verbosity=2)
