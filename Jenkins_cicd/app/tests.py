from django.test import TestCase
from django.urls import reverse

from .models import register


class CrudViewTests(TestCase):
    def setUp(self):
        self.user = register.objects.create(
            Firstname='Ada', Lastname='Lovelace', Email='ada@example.com', Contact=9876543210
        )

    def test_insert_page_renders(self):
        response = self.client.get(reverse('insertpage'))
        self.assertEqual(response.status_code, 200)

    def test_show_page_lists_records(self):
        response = self.client.get(reverse('show'))
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, 'ada@example.com')

    def test_insert_creates_record(self):
        response = self.client.post(reverse('insert'), {
            'fname': 'Alan', 'lname': 'Turing', 'mail': 'alan@example.com', 'phone': '1234567890',
        })
        self.assertRedirects(response, reverse('show'))
        self.assertTrue(register.objects.filter(Email='alan@example.com').exists())

    def test_insert_rejects_get(self):
        response = self.client.get(reverse('insert'))
        self.assertEqual(response.status_code, 405)

    def test_edit_page_shows_record(self):
        response = self.client.get(reverse('edit', args=[self.user.id]))
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, 'Lovelace')

    def test_edit_missing_record_returns_404(self):
        response = self.client.get(reverse('edit', args=[999]))
        self.assertEqual(response.status_code, 404)

    def test_update_changes_record(self):
        self.client.post(reverse('update', args=[self.user.id]), {
            'fname': 'Ada', 'lname': 'King', 'mail': 'ada@example.com', 'phone': '9876543210',
        })
        self.user.refresh_from_db()
        self.assertEqual(self.user.Lastname, 'King')

    def test_delete_removes_record(self):
        response = self.client.post(reverse('delete', args=[self.user.id]))
        self.assertRedirects(response, reverse('show'))
        self.assertFalse(register.objects.filter(id=self.user.id).exists())
