from django.core.management.base import BaseCommand
from chat.models import ChatMessage


class Command(BaseCommand):
    help = 'Clean up chat messages older than specified minutes (default: 30)'

    def add_arguments(self, parser):
        parser.add_argument(
            '--minutes',
            type=int,
            default=30,
            help='Delete messages older than this many minutes (default: 30)'
        )

    def handle(self, *args, **options):
        minutes = options['minutes']
        deleted_count = ChatMessage.cleanup_old_messages(minutes=minutes)
        
        self.stdout.write(
            self.style.SUCCESS(
                f'Successfully deleted {deleted_count} messages older than {minutes} minutes'
            )
        )

