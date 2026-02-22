"""
In-memory cache service using cachetools.

Provides a singleton TTLCache with configurable:
  - maxsize: maximum number of entries before LRU eviction
  - ttl:     seconds until each entry expires automatically

Usage:
    from app.services.cache import cache_service

    cache_service.set("my_key", value, ttl=300)   # 5-minute TTL (overrides default)
    value = cache_service.get("my_key")            # None if missing or expired
    cache_service.delete("my_key")
    cache_service.clear()
"""

import threading
from typing import Any, Optional
from cachetools import TTLCache


# ─── Configuration ────────────────────────────────────────────────────────────
DEFAULT_TTL_SECONDS = 3600       # 1 hour
MAX_ENTRIES = 1000               # max items before LRU eviction kicks in
# ─────────────────────────────────────────────────────────────────────────────


class InMemoryCache:
    """Thread-safe TTL+LRU in-memory cache backed by cachetools.TTLCache."""

    def __init__(self, maxsize: int = MAX_ENTRIES, ttl: int = DEFAULT_TTL_SECONDS):
        self._default_ttl = ttl
        self._maxsize = maxsize
        self._lock = threading.Lock()
        # Primary cache with default TTL
        self._cache: TTLCache = TTLCache(maxsize=maxsize, ttl=ttl)
        # Per-key custom-TTL caches (keyed by ttl value)
        self._ttl_caches: dict[int, TTLCache] = {}

    def _get_cache_for_ttl(self, ttl: int) -> TTLCache:
        """Return (or create) a TTLCache bucket for a specific TTL."""
        if ttl == self._default_ttl:
            return self._cache
        if ttl not in self._ttl_caches:
            self._ttl_caches[ttl] = TTLCache(maxsize=self._maxsize, ttl=ttl)
        return self._ttl_caches[ttl]

    def get(self, key: str) -> Optional[Any]:
        """Return cached value or None if missing/expired."""
        with self._lock:
            # Check primary cache first
            value = self._cache.get(key)
            if value is not None:
                return value
            # Check custom-TTL buckets
            for ttl_cache in self._ttl_caches.values():
                value = ttl_cache.get(key)
                if value is not None:
                    return value
            return None

    def set(self, key: str, value: Any, ttl: Optional[int] = None) -> None:
        """Store a value with an optional per-entry TTL (defaults to class TTL)."""
        effective_ttl = ttl if ttl is not None else self._default_ttl
        with self._lock:
            cache = self._get_cache_for_ttl(effective_ttl)
            cache[key] = value

    def delete(self, key: str) -> None:
        """Remove a key from all cache buckets."""
        with self._lock:
            self._cache.pop(key, None)
            for ttl_cache in self._ttl_caches.values():
                ttl_cache.pop(key, None)

    def clear(self) -> None:
        """Evict all entries from all buckets."""
        with self._lock:
            self._cache.clear()
            for ttl_cache in self._ttl_caches.values():
                ttl_cache.clear()

    @property
    def info(self) -> dict:
        """Return current cache statistics."""
        with self._lock:
            total = len(self._cache)
            for c in self._ttl_caches.values():
                total += len(c)
            return {
                "entries": total,
                "maxsize": self._maxsize,
                "default_ttl_seconds": self._default_ttl,
            }


# ─── Singleton ────────────────────────────────────────────────────────────────
cache_service = InMemoryCache(maxsize=MAX_ENTRIES, ttl=DEFAULT_TTL_SECONDS)
