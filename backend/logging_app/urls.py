from django.urls import path
from . import views

urlpatterns = [
    # Items endpoints
    path('items/', views.items_list, name='items_list'),
    path('items/<uuid:item_id>/', views.item_detail, name='item_detail'),
    path('items/<uuid:item_id>/log/', views.log_item, name='log_item'),
    path('items/<uuid:item_id>/impacts/', views.biomarker_impacts, name='biomarker_impacts'),
    path('items/<uuid:item_id>/reminder/', views.update_reminder, name='update_reminder'),
    path('items/<uuid:item_id>/archive/', views.archive_item, name='archive_item'),
    path('items/<uuid:item_id>/toggle-taken/', views.toggle_taken, name='toggle_taken'),
    path('items/<uuid:item_id>/toggle-dose/<int:time_index>/', views.toggle_dose, name='toggle_dose'),

    # Logs endpoints
    path('logs/', views.logs_list, name='logs_list'),
    path('logs/<uuid:log_id>/', views.delete_log, name='delete_log'),
    
    # Quick log (voice/text)
    path('quick-log/', views.quick_log, name='quick_log'),
]
