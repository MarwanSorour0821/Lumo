"""
Supplement lookup service: find supplements by name or alias.
"""
from .models import Supplement


def get_supplement_by_name(name):
    """
    Return a single Supplement by exact name or by alias (case-insensitive).
    Returns None if not found.
    """
    if not name or not str(name).strip():
        return None
    q = str(name).strip()
    # Exact name match first
    try:
        return Supplement.objects.get(name__iexact=q, is_active=True)
    except Supplement.DoesNotExist:
        pass
    # Match any alias (case-insensitive); PostgreSQL array contains is tricky, so filter in Python or use __icontains on name only
    # Using raw name match: check aliases by iterating (DB doesn't have case-insensitive array contains easily without raw SQL)
    for s in Supplement.objects.filter(is_active=True):
        if s.name.lower() == q.lower():
            return s
        if s.aliases:
            for a in s.aliases:
                if a and str(a).strip().lower() == q.lower():
                    return s
    return None


def get_supplements_by_names(names):
    """
    Given a list of supplement names (as entered by user), return a list of
    Supplement instances in the same order. For names not found, the list
    contains None at that index, and the response can indicate 'unknown' names.
    """
    if not names:
        return [], []
    results = []
    unknown = []
    for i, n in enumerate(names):
        s = get_supplement_by_name(n)
        results.append(s)
        if s is None:
            unknown.append(n)
    return results, unknown
