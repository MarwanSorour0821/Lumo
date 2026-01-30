"""
Phase 2: Deterministic supplement scheduler.
Uses the supplements knowledge base (Phase 1) to assign each supplement to a time slot.
No OpenAI; rules and data only.
"""
import logging
from supplements.services import get_supplements_by_names

logger = logging.getLogger("suppsAI")

# Time slots: (slot_id, default clock time). Order defines preference when no best_times.
TIME_SLOTS = [
    ("morning", "08:00"),
    ("midday", "12:00"),
    ("afternoon", "15:00"),
    ("evening", "18:00"),
    ("before_bed", "21:00"),
]
SLOT_ORDER = [s[0] for s in TIME_SLOTS]
SLOT_TO_TIME = dict(TIME_SLOTS)


def _best_times_for(supp):
    """Return list of slot_ids this supplement prefers (from best_times). Unknown -> default morning."""
    if supp is None:
        return ["morning"]
    if not getattr(supp, "best_times", None):
        return ["morning"]
    # Map DB best_times (e.g. "morning", "evening") to our slot_ids
    out = []
    for bt in supp.best_times:
        if bt and isinstance(bt, str):
            b = bt.strip().lower()
            if b in SLOT_TO_TIME:
                out.append(b)
    return out if out else ["morning"]


def _dont_take_with_set(supp):
    """Return set of canonical names that conflict with this supplement."""
    if supp is None:
        return set()
    names = getattr(supp, "dont_take_with", None) or []
    return {str(n).strip() for n in names if n}


def _conflicts(supp_a, supp_b):
    """True if the two supplements should not be in the same slot."""
    if supp_a is None or supp_b is None:
        return False
    name_a = getattr(supp_a, "name", None) or ""
    name_b = getattr(supp_b, "name", None) or ""
    dont_a = _dont_take_with_set(supp_a)
    dont_b = _dont_take_with_set(supp_b)
    if name_b in dont_a or name_a in dont_b:
        return True
    return False


def build_schedule(supplement_names):
    """
    Build a daily schedule for the given supplement names using the knowledge base.

    Args:
        supplement_names: List of strings (as entered by user, e.g. "Magnesium", "Vitamin D3").

    Returns:
        (schedule, unknown):
          - schedule: dict mapping each input name -> time string (e.g. "08:00", "21:00").
          - unknown: list of names that were not found in the DB (assigned default morning).
    """
    if not supplement_names:
        return {}, []

    supplements_list, unknown = get_supplements_by_names(supplement_names)
    # (input_name, supp_or_none, best_times_slot_ids, dont_take_with_set)
    items = []
    for i, name in enumerate(supplement_names):
        supp = supplements_list[i] if i < len(supplements_list) else None
        best = _best_times_for(supp)
        dont = _dont_take_with_set(supp)
        items.append((name, supp, best, dont))

    # Sort by most constrained first (most dont_take_with) so they get first pick of slots
    items.sort(key=lambda x: -len(x[3]))

    # slot_id -> list of (input_name, supp)
    slot_assignments = {sid: [] for sid in SLOT_ORDER}

    for input_name, supp, best_times, _ in items:
        placed = False
        # Try preferred slots first, then any slot
        for slot_id in best_times + SLOT_ORDER:
            if slot_id not in slot_assignments:
                continue
            conflicts_any = False
            for _existing_name, existing_supp in slot_assignments[slot_id]:
                if _conflicts(supp, existing_supp):
                    conflicts_any = True
                    break
            if not conflicts_any:
                slot_assignments[slot_id].append((input_name, supp))
                placed = True
                break
        if not placed:
            # Fallback: put in first slot that has no conflict (should not happen if slots >= 5)
            for slot_id in SLOT_ORDER:
                conflicts_any = False
                for _existing_name, existing_supp in slot_assignments[slot_id]:
                    if _conflicts(supp, existing_supp):
                        conflicts_any = True
                        break
                if not conflicts_any:
                    slot_assignments[slot_id].append((input_name, supp))
                    placed = True
                    break
        if not placed:
            # Last resort: morning
            slot_assignments["morning"].append((input_name, supp))

    # Build schedule keyed by input name -> time
    schedule = {}
    for slot_id, time_str in TIME_SLOTS:
        for input_name, _ in slot_assignments[slot_id]:
            schedule[input_name] = time_str

    logger.info(f"build_schedule: {len(supplement_names)} names -> schedule keys {list(schedule.keys())}, unknown {unknown}")
    return schedule, unknown
