from __future__ import annotations

import asyncio
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any

IST = timezone(timedelta(hours=5, minutes=30))


def _now_iso() -> str:
    return datetime.now(IST).isoformat()


class ThreatStore:
    def __init__(self, max_items: int = 8000) -> None:
        self._by_id: dict[str, dict[str, Any]] = {}
        self._order: list[str] = []
        self._lock = asyncio.Lock()
        self._max = max_items

    async def add(self, row: dict[str, Any]) -> dict[str, Any]:
        async with self._lock:
            tid = str(uuid.uuid4())
            rec = {**row, "id": tid, "created_at": row.get("created_at") or _now_iso()}
            self._by_id[tid] = rec
            self._order.insert(0, tid)
            while len(self._order) > self._max:
                old = self._order.pop()
                self._by_id.pop(old, None)
            return rec

    async def get(self, threat_id: str) -> dict[str, Any] | None:
        async with self._lock:
            r = self._by_id.get(threat_id)
            return dict(r) if r else None

    async def list_items(self, limit: int = 50) -> tuple[int, list[dict[str, Any]]]:
        async with self._lock:
            total = len(self._order)
            ids = self._order[: max(0, min(limit, 500))]
            return total, [dict(self._by_id[i]) for i in ids if i in self._by_id]

    async def stats(self) -> dict[str, Any]:
        async with self._lock:
            now = datetime.now(IST)
            day_ago = now - timedelta(hours=24)
            by_type: dict[str, int] = {"apk": 0, "url": 0}
            by_verdict: dict[str, int] = {}
            by_state: dict[str, int] = {}
            total_24h = 0
            for tid in self._order:
                t = self._by_id.get(tid)
                if not t:
                    continue
                tt = t.get("threat_type") or "url"
                if tt in by_type:
                    by_type[tt] += 1
                v = t.get("verdict") or "unknown"
                by_verdict[v] = by_verdict.get(v, 0) + 1
                st = t.get("device_state")
                if st:
                    by_state[st] = by_state.get(st, 0) + 1
                try:
                    created = datetime.fromisoformat(
                        str(t.get("created_at", "")).replace("Z", "+00:00")
                    )
                    if created.tzinfo is None:
                        created = created.replace(tzinfo=IST)
                    if created >= day_ago:
                        total_24h += 1
                except Exception:
                    pass
            return {
                "total_threats_24h": total_24h,
                "total_threats_all": len(self._order),
                "by_type": by_type,
                "by_verdict": by_verdict,
                "by_state": by_state,
            }

    async def mark_reported(
        self, threat_id: str, body: dict[str, Any]
    ) -> dict[str, Any] | None:
        async with self._lock:
            t = self._by_id.get(threat_id)
            if not t:
                return None
            if body.get("certin"):
                t["reported_certin"] = True
            if body.get("google"):
                t["reported_google"] = True
            if body.get("cybercrime"):
                t["reported_cybercrime"] = True
            return dict(t)


store = ThreatStore()
