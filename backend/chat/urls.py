from django.urls import path
from .views import SendMessageView, SendFileMessageView, ChatHistoryView, ClearHistoryView

urlpatterns = [
    path('send/', SendMessageView.as_view(), name='chat-send'),
    path('send-file/', SendFileMessageView.as_view(), name='chat-send-file'),
    path('history/', ChatHistoryView.as_view(), name='chat-history'),
    path('clear/', ClearHistoryView.as_view(), name='chat-clear'),
]
