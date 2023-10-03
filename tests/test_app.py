import unittest
import os
import sys
sys.path.append(os.path.join(os.path.dirname(__file__), ".."))
from app import app


class AppTestCase(unittest.TestCase):
    def setUp(self):
        self.app = app.test_client()

    def test_hello(self):
        response = self.app.get('/')
        self.assertEqual(response.status_code, 200)
        self.assertIn('Hello, World!', response.data.decode())

if __name__ == '__main__':
    unittest.main()
